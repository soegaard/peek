#lang racket/base

;;;
;;; Go Preview
;;;
;;
;; Go-specific terminal preview rendering built on `lexers/go`.

;; render-go-preview      : string? -> string?
;;   Render Go source for terminal preview.
;; render-go-preview-port : input-port? output-port? -> void?
;;   Render Go source from a port for terminal preview.

(provide
 ;; render-go-preview : string? -> string?
 ;;   Render Go source for terminal preview.
 render-go-preview
 ;; render-go-preview-port : input-port? output-port? -> void?
 ;;   Render Go source from a port for terminal preview.
 render-go-preview-port)

(require lexers/go
         racket/port
         racket/string
         "common-style.rkt")

;; go-derived-token-category : go-derived-token? -> symbol?
;;   Extract the coarse category from one derived Go token.
(define (go-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; go-token-style : go-derived-token? -> string?
;;   Choose the ANSI style for one derived Go token.
(define (go-token-style token)
  (go-like-style (go-derived-token-category token)
                 (go-derived-token-tags token)))

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

;; render-go-preview : string? -> string?
;;   Render Go source for terminal preview.
(define (render-go-preview source)
  (apply string-append
         (for/list ([token (go-string->derived-tokens source)])
           (colorize-text (go-token-style token)
                          (go-derived-token-text token)))))

;; render-go-preview-port : input-port? output-port? -> void?
;;   Render Go source from a port for terminal preview.
(define (render-go-preview-port in
                                [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-go-derived-lexer))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (go-token-style token)
                              (go-derived-token-text token))
               out)
      (loop))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define sample
    "package main\n// Demo\nfunc main() {\n    println(\"hello\")\n}\n")

  (check-equal?
   (strip-ansi (render-go-preview sample))
   sample)

  (check-equal?
   (let ([out (open-output-string)])
     (render-go-preview-port (open-input-string sample)
                             out)
     (strip-ansi (get-output-string out)))
   sample))
