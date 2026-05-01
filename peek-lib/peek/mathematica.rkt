#lang racket/base

;;;
;;; Mathematica Preview
;;;
;;
;; Mathematica / Wolfram Language terminal preview rendering built on
;; `lexers/mathematica`.

;; render-mathematica-preview      : string? -> string?
;;   Render Mathematica source for terminal preview.
;; render-mathematica-preview-port : input-port? output-port? -> void?
;;   Render Mathematica source from a port for terminal preview.

(provide
 ;; render-mathematica-preview : string? -> string?
 ;;   Render Mathematica source for terminal preview.
 render-mathematica-preview
 ;; render-mathematica-preview-port : input-port? output-port? -> void?
 ;;   Render Mathematica source from a port for terminal preview.
 render-mathematica-preview-port)

(require lexers/mathematica
         "common-style.rkt")

;; mathematica-derived-token-category : mathematica-derived-token? -> symbol?
;;   Extract the coarse category from one derived Mathematica token.
(define (mathematica-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; mathematica-token-style : mathematica-derived-token? -> string?
;;   Choose the ANSI style for one derived Mathematica token.
(define (mathematica-token-style token)
  (mathematica-like-style (mathematica-derived-token-category token)
                          (mathematica-derived-token-tags token)))

;; render-mathematica-preview : string? -> string?
;;   Render Mathematica source for terminal preview.
(define (render-mathematica-preview source)
  (apply string-append
         (for/list ([token (mathematica-string->derived-tokens source)])
           (colorize-text (mathematica-token-style token)
                          (mathematica-derived-token-text token)))))

;; render-mathematica-preview-port : input-port? output-port? -> void?
;;   Render Mathematica source from a port for terminal preview.
(define (render-mathematica-preview-port in
                                         [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-mathematica-derived-lexer))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (mathematica-token-style token)
                              (mathematica-derived-token-text token))
               out)
      (loop))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define sample
    (string-append
     "BeginPackage[\"Demo`\"]\n"
     "f[x_] := Module[{a = 16^^FF}, x /. y_ :> #name &]\n"
     "assoc = <|\"a\" -> 1|>;\n"
     "(* note *)\n"))

  (check-equal?
   (strip-ansi (render-mathematica-preview sample))
   sample)

  (check-true
   (regexp-match? #px"\u001b\\[" (render-mathematica-preview sample)))

  (check-equal?
   (let ([out (open-output-string)])
     (render-mathematica-preview-port (open-input-string sample)
                                      out)
     (strip-ansi (get-output-string out)))
   sample))
