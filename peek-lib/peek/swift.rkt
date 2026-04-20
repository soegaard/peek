#lang racket/base

;;;
;;; Swift Preview
;;;
;;
;; Swift-specific terminal preview rendering built on `lexers/swift`.

;; render-swift-preview      : string? -> string?
;;   Render Swift source for terminal preview.
;; render-swift-preview-port : input-port? output-port? -> void?
;;   Render Swift source from a port for terminal preview.

(provide
 ;; render-swift-preview : string? -> string?
 ;;   Render Swift source for terminal preview.
 render-swift-preview
 ;; render-swift-preview-port : input-port? output-port? -> void?
 ;;   Render Swift source from a port for terminal preview.
 render-swift-preview-port)

(require lexers/swift
         racket/port
         racket/string
         "common-style.rkt")

;; swift-derived-token-category : swift-derived-token? -> symbol?
;;   Extract the coarse category from one derived Swift token.
(define (swift-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; swift-token-style : swift-derived-token? -> string?
;;   Choose the ANSI style for one derived Swift token.
(define (swift-token-style token)
  (swift-like-style (swift-derived-token-category token)
                    (swift-derived-token-tags token)))

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

;; render-swift-preview : string? -> string?
;;   Render Swift source for terminal preview.
(define (render-swift-preview source)
  (apply string-append
         (for/list ([token (swift-string->derived-tokens source)])
           (colorize-text (swift-token-style token)
                          (swift-derived-token-text token)))))

;; render-swift-preview-port : input-port? output-port? -> void?
;;   Render Swift source from a port for terminal preview.
(define (render-swift-preview-port in
                                   [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-swift-derived-lexer))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (swift-token-style token)
                              (swift-derived-token-text token))
               out)
      (loop))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define sample
    "// greet\n@available(iOS 13.0, *)\nfunc greet(name: String) -> String {\n  let count = 2\n  let message = \"hello, \\(name)\"\n  return message\n}\n")

  (check-equal?
   (strip-ansi (render-swift-preview sample))
   sample)

  (check-equal?
   (let ([out (open-output-string)])
     (render-swift-preview-port (open-input-string sample)
                                out)
     (strip-ansi (get-output-string out)))
   sample))
