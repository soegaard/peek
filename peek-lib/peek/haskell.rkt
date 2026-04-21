#lang racket/base

;;;
;;; Haskell Preview
;;;
;;
;; Haskell-specific terminal preview rendering built on `lexers/haskell`.

;; render-haskell-preview      : string? -> string?
;;   Render Haskell source for terminal preview.
;; render-haskell-preview-port : input-port? output-port? -> void?
;;   Render Haskell source from a port for terminal preview.

(provide
 ;; render-haskell-preview : string? -> string?
 ;;   Render Haskell source for terminal preview.
 render-haskell-preview
 ;; render-haskell-preview-port : input-port? output-port? -> void?
 ;;   Render Haskell source from a port for terminal preview.
 render-haskell-preview-port)

(require lexers/haskell
         racket/port
         racket/string
         "common-style.rkt")

;; haskell-derived-token-category : haskell-derived-token? -> symbol?
;;   Extract the coarse category from one derived Haskell token.
(define (haskell-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; haskell-token-style : haskell-derived-token? -> string?
;;   Choose the ANSI style for one derived Haskell token.
(define (haskell-token-style token)
  (haskell-like-style (haskell-derived-token-category token)
                      (haskell-derived-token-tags token)))

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

;; render-haskell-preview : string? -> string?
;;   Render Haskell source for terminal preview.
(define (render-haskell-preview source)
  (apply string-append
         (for/list ([token (haskell-string->derived-tokens source)])
           (colorize-text (haskell-token-style token)
                          (haskell-derived-token-text token)))))

;; render-haskell-preview-port : input-port? output-port? -> void?
;;   Render Haskell source from a port for terminal preview.
(define (render-haskell-preview-port in
                                     [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-haskell-derived-lexer))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (haskell-token-style token)
                              (haskell-derived-token-text token))
               out)
      (loop))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define sample
    (string-append "{-# LANGUAGE OverloadedStrings #-}\n"
                   "-- Demo module.\n"
                   "module Demo where\n"
                   "main = putStrLn \"hello\"\n"))

  (check-equal?
   (strip-ansi (render-haskell-preview sample))
   sample)

  (check-equal?
   (let ([out (open-output-string)])
     (render-haskell-preview-port (open-input-string sample)
                                  out)
     (strip-ansi (get-output-string out)))
   sample))
