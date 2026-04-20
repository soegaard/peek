#lang racket/base

;;;
;;; Makefile Preview
;;;
;;
;; Makefile-specific terminal preview rendering built on `lexers/makefile`.

;; render-makefile-preview      : string? -> string?
;;   Render Makefile source for terminal preview.
;; render-makefile-preview-port : input-port? output-port? -> void?
;;   Render Makefile source from a port for terminal preview.

(provide
 ;; render-makefile-preview : string? -> string?
 ;;   Render Makefile source for terminal preview.
 render-makefile-preview
 ;; render-makefile-preview-port : input-port? output-port? -> void?
 ;;   Render Makefile source from a port for terminal preview.
 render-makefile-preview-port)

(require lexers/makefile
         racket/port
         racket/string
         "common-style.rkt")

;; makefile-derived-token-category : makefile-derived-token? -> symbol?
;;   Extract the coarse category from one derived Makefile token.
(define (makefile-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; makefile-token-style : makefile-derived-token? -> string?
;;   Choose the ANSI style for one derived Makefile token.
(define (makefile-token-style token)
  (makefile-like-style (makefile-derived-token-category token)
                       (makefile-derived-token-tags token)))

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

;; render-makefile-preview : string? -> string?
;;   Render Makefile source for terminal preview.
(define (render-makefile-preview source)
  (apply string-append
         (for/list ([token (makefile-string->derived-tokens source)])
           (colorize-text (makefile-token-style token)
                          (makefile-derived-token-text token)))))

;; render-makefile-preview-port : input-port? output-port? -> void?
;;   Render Makefile source from a port for terminal preview.
(define (render-makefile-preview-port in
                                      [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-makefile-derived-lexer))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (makefile-token-style token)
                              (makefile-derived-token-text token))
               out)
      (loop))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define sample
    "CC := gcc\nall: main.o util.o\n\t$(CC) -o app main.o util.o\ninclude local.mk\n")

  (check-equal?
   (strip-ansi (render-makefile-preview sample))
   sample)

  (check-equal?
   (let ([out (open-output-string)])
     (render-makefile-preview-port (open-input-string sample)
                                   out)
     (strip-ansi (get-output-string out)))
   sample))
