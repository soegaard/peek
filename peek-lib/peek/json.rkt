#lang racket/base

;;;
;;; JSON Preview
;;;
;;
;; JSON-specific terminal preview rendering built on `lexers/json`.

;; render-json-preview      : string? -> string?
;;   Render JSON source for terminal preview.
;; render-json-preview-port : input-port? output-port? -> void?
;;   Render JSON source from a port for terminal preview.

(provide
 ;; render-json-preview : string? -> string?
 ;;   Render JSON source for terminal preview.
 render-json-preview
 ;; render-json-preview-port : input-port? output-port? -> void?
 ;;   Render JSON source from a port for terminal preview.
 render-json-preview-port)

(require lexers/json
         racket/port
         racket/string
         "common-style.rkt")

;; json-derived-token-category : json-derived-token? -> symbol?
;;   Extract the coarse category from one derived JSON token.
(define (json-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; json-token-style : json-derived-token? -> string?
;;   Choose the ANSI style for one derived JSON token.
(define (json-token-style token)
  (json-like-style (json-derived-token-category token)
                   (json-derived-token-tags token)))

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

;; render-json-preview : string? -> string?
;;   Render JSON source for terminal preview.
(define (render-json-preview source)
  (apply string-append
         (for/list ([token (json-string->derived-tokens source)])
           (colorize-text (json-token-style token)
                          (json-derived-token-text token)))))

;; render-json-preview-port : input-port? output-port? -> void?
;;   Render JSON source from a port for terminal preview.
(define (render-json-preview-port in
                                  [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-json-derived-lexer))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (json-token-style token)
                              (json-derived-token-text token))
               out)
      (loop))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define sample
    "{\"name\": \"peek\", \"ok\": true, \"n\": 2}\n")

  (check-equal?
   (strip-ansi (render-json-preview sample))
   sample)

  (check-equal?
   (let ([out (open-output-string)])
     (render-json-preview-port (open-input-string sample)
                               out)
     (strip-ansi (get-output-string out)))
   sample))
