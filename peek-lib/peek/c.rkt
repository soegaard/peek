#lang racket/base

;;;
;;; C Preview
;;;
;;
;; C-specific terminal preview rendering built on `lexers/c`.

;; render-c-preview      : string? -> string?
;;   Render C source for terminal preview.
;; render-c-preview-port : input-port? output-port? -> void?
;;   Render C source from a port for terminal preview.

(provide
 ;; render-c-preview : string? -> string?
 ;;   Render C source for terminal preview.
 render-c-preview
 ;; render-c-preview-port : input-port? output-port? -> void?
 ;;   Render C source from a port for terminal preview.
 render-c-preview-port)

(require lexers/c
         racket/port
         racket/string
         "common-style.rkt")

;; c-derived-token-category : c-derived-token? -> symbol?
;;   Extract the coarse category from one derived C token.
(define (c-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; c-token-style : c-derived-token? -> string?
;;   Choose the ANSI style for one derived C token.
(define (c-token-style token)
  (c-like-style (c-derived-token-category token)
                (c-derived-token-tags token)))

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

;; render-c-preview : string? -> string?
;;   Render C source for terminal preview.
(define (render-c-preview source)
  (apply string-append
         (for/list ([token (c-string->derived-tokens source)])
           (colorize-text (c-token-style token)
                          (c-derived-token-text token)))))

;; render-c-preview-port : input-port? output-port? -> void?
;;   Render C source from a port for terminal preview.
(define (render-c-preview-port in
                               [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-c-derived-lexer))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (c-token-style token)
                              (c-derived-token-text token))
               out)
      (loop))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define sample
    "#define SUM(a, b) ((a) + \\\n+ (b))\n#include <stdio.h>\nint main(void) { return SUM(1, 2); }\n")

  (check-equal?
   (strip-ansi (render-c-preview sample))
   sample)

  (check-true
   (regexp-match? #px"\u001b\\[" (render-c-preview sample)))

  (check-equal?
   (let ([out (open-output-string)])
     (render-c-preview-port (open-input-string sample)
                            out)
     (strip-ansi (get-output-string out)))
   sample))
