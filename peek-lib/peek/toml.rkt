#lang racket/base

;;;
;;; TOML Preview
;;;
;;
;; TOML-specific terminal preview rendering built on `lexers/toml`.

;; render-toml-preview      : string? -> string?
;;   Render TOML source for terminal preview.
;; render-toml-preview-port : input-port? output-port? -> void?
;;   Render TOML source from a port for terminal preview.

(provide
 ;; render-toml-preview : string? -> string?
 ;;   Render TOML source for terminal preview.
 render-toml-preview
 ;; render-toml-preview-port : input-port? output-port? -> void?
 ;;   Render TOML source from a port for terminal preview.
 render-toml-preview-port)

(require lexers/toml
         racket/port
         "common-style.rkt")

;; toml-derived-token-category : toml-derived-token? -> symbol?
;;   Extract the coarse category from one derived TOML token.
(define (toml-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; toml-token-style : toml-derived-token? -> string?
;;   Choose the ANSI style for one derived TOML token.
(define (toml-token-style token)
  (toml-like-style (toml-derived-token-category token)
                   (toml-derived-token-tags token)))

;; render-toml-preview : string? -> string?
;;   Render TOML source for terminal preview.
(define (render-toml-preview source)
  (apply string-append
         (for/list ([token (toml-string->derived-tokens source)])
           (colorize-text (toml-token-style token)
                          (toml-derived-token-text token)))))

;; render-toml-preview-port : input-port? output-port? -> void?
;;   Render TOML source from a port for terminal preview.
(define (render-toml-preview-port in
                                  [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-toml-derived-lexer))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (toml-token-style token)
                              (toml-derived-token-text token))
               out)
      (loop))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define sample
    "# Application settings\n[server]\nhost = \"127.0.0.1\"\nport = 8080\nstarted = 2026-08-29T12:00:00Z\nenabled = true\n")

  (check-equal?
   (strip-ansi (render-toml-preview sample))
   sample)

  (check-equal?
   (let ([out (open-output-string)])
     (render-toml-preview-port (open-input-string sample)
                               out)
     (strip-ansi (get-output-string out)))
   sample))
