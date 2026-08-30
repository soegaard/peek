#lang racket/base

;;;
;;; Scheme Preview
;;;
;;
;; Scheme-specific terminal preview rendering built on `lexers/scheme`.

;; render-scheme-preview      : string? keyword-arguments -> string?
;;   Render Scheme source for terminal preview.
;; render-scheme-preview-port : input-port? output-port? keyword-arguments -> void?
;;   Render Scheme source from a port for terminal preview.

(provide
 ;; render-scheme-preview : string? keyword-arguments -> string?
 ;;   Render Scheme source for terminal preview.
 render-scheme-preview
 ;; render-scheme-preview-port : input-port? output-port? keyword-arguments -> void?
 ;;   Render Scheme source from a port for terminal preview.
 render-scheme-preview-port)

(require lexers/scheme
         racket/port
         "common-style.rkt")

;; scheme-derived-token-category : scheme-derived-token? -> symbol?
;;   Extract the coarse category from one derived Scheme token.
(define (scheme-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; scheme-token-style : scheme-derived-token? -> string?
;;   Choose the ANSI style for one derived Scheme token.
(define (scheme-token-style token)
  (scheme-like-style (scheme-derived-token-category token)
                     (scheme-derived-token-tags token)))

;; render-scheme-preview : string? [#:dialect symbol?] -> string?
;;   Render Scheme source for terminal preview.
(define (render-scheme-preview source
                               #:dialect [dialect 'r5rs])
  (apply string-append
         (for/list ([token (scheme-string->derived-tokens source
                                                           #:dialect dialect)])
           (colorize-text (scheme-token-style token)
                          (scheme-derived-token-text token)))))

;; render-scheme-preview-port : input-port? output-port? [#:dialect symbol?] -> void?
;;   Render Scheme source from a port for terminal preview.
(define (render-scheme-preview-port in
                                    [out (current-output-port)]
                                    #:dialect [dialect 'r5rs])
  (port-count-lines! in)
  (define lexer
    (make-scheme-derived-lexer #:dialect dialect))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (scheme-token-style token)
                              (scheme-derived-token-text token))
               out)
      (loop))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define sample
    ";; Greets a named user.\n(define (greet name)\n  (display \"hello \")\n  (display name)\n  (newline))\n")

  (check-equal?
   (strip-ansi (render-scheme-preview sample))
   sample)

  (check-equal?
   (let ([out (open-output-string)])
     (render-scheme-preview-port (open-input-string sample)
                                 out)
     (strip-ansi (get-output-string out)))
   sample))
