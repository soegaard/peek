#lang racket/base

;;;
;;; Pascal Preview
;;;
;;
;; Pascal-specific terminal preview rendering built on `lexers/pascal`.

;; render-pascal-preview      : string? -> string?
;;   Render Pascal source for terminal preview.
;; render-pascal-preview-port : input-port? output-port? -> void?
;;   Render Pascal source from a port for terminal preview.

(provide
 ;; render-pascal-preview : string? -> string?
 ;;   Render Pascal source for terminal preview.
 render-pascal-preview
 ;; render-pascal-preview-port : input-port? output-port? -> void?
 ;;   Render Pascal source from a port for terminal preview.
 render-pascal-preview-port)

(require lexers/pascal
         racket/port
         racket/string
         "common-style.rkt")

;; pascal-derived-token-category : pascal-derived-token? -> symbol?
;;   Extract the coarse category from one derived Pascal token.
(define (pascal-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; pascal-token-style : pascal-derived-token? -> string?
;;   Choose the ANSI style for one derived Pascal token.
(define (pascal-token-style token)
  (pascal-like-style (pascal-derived-token-category token)
                     (pascal-derived-token-tags token)))

;; colorize-text : string? string? -> string?
;;   Apply ANSI styling while preserving coloring across newlines.
(define (colorize-text code text)
  (cond
    [(or (string=? code "") (string=? text "")) text]
    [else
     (string-append code
                    (string-join (string-split text "\n" #:trim? #f)
                                 (string-append ansi-reset "\n" code))
                    ansi-reset)]))

;; render-pascal-preview : string? -> string?
;;   Render Pascal source for terminal preview.
(define (render-pascal-preview source)
  (apply string-append
         (for/list ([token (pascal-string->derived-tokens source)])
           (colorize-text (pascal-token-style token)
                          (pascal-derived-token-text token)))))

;; render-pascal-preview-port : input-port? output-port? -> void?
;;   Render Pascal source from a port for terminal preview.
(define (render-pascal-preview-port in
                                    [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-pascal-derived-lexer))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (pascal-token-style token)
                              (pascal-derived-token-text token))
               out)
      (loop))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define sample
    "program Demo;\nvar &do: Integer;\nbegin\n  writeln('hi');\nend.\n")

  (check-equal?
   (strip-ansi (render-pascal-preview sample))
   sample)

  (check-equal?
   (let ([out (open-output-string)])
     (render-pascal-preview-port (open-input-string sample)
                                 out)
     (strip-ansi (get-output-string out)))
   sample))
