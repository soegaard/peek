#lang racket/base

;;;
;;; Rust Preview
;;;
;;
;; Rust-specific terminal preview rendering built on `lexers/rust`.

;; render-rust-preview      : string? -> string?
;;   Render Rust source for terminal preview.
;; render-rust-preview-port : input-port? output-port? -> void?
;;   Render Rust source from a port for terminal preview.

(provide
 ;; render-rust-preview : string? -> string?
 ;;   Render Rust source for terminal preview.
 render-rust-preview
 ;; render-rust-preview-port : input-port? output-port? -> void?
 ;;   Render Rust source from a port for terminal preview.
 render-rust-preview-port)

(require lexers/rust
         racket/port
         racket/string
         "common-style.rkt")

;; rust-derived-token-category : rust-derived-token? -> symbol?
;;   Extract the coarse category from one derived Rust token.
(define (rust-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; rust-token-style : rust-derived-token? -> string?
;;   Choose the ANSI style for one derived Rust token.
(define (rust-token-style token)
  (rust-like-style (rust-derived-token-category token)
                   (rust-derived-token-tags token)))

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

;; render-rust-preview : string? -> string?
;;   Render Rust source for terminal preview.
(define (render-rust-preview source)
  (apply string-append
         (for/list ([token (rust-string->derived-tokens source)])
           (colorize-text (rust-token-style token)
                          (rust-derived-token-text token)))))

;; render-rust-preview-port : input-port? output-port? -> void?
;;   Render Rust source from a port for terminal preview.
(define (render-rust-preview-port in
                                  [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-rust-derived-lexer))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (rust-token-style token)
                              (rust-derived-token-text token))
               out)
      (loop))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define sample
    "/// Demo\nfn greet(name: &str) -> String {\n    let message = format!(\"hello, {name}\");\n    message\n}\n")

  (check-equal?
   (strip-ansi (render-rust-preview sample))
   sample)

  (check-equal?
   (let ([out (open-output-string)])
     (render-rust-preview-port (open-input-string sample)
                               out)
     (strip-ansi (get-output-string out)))
   sample))
