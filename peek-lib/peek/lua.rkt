#lang racket/base

;;;
;;; Lua Preview
;;;
;;
;; Lua-specific terminal preview rendering built on `lexers/lua`.

;; render-lua-preview      : string? -> string?
;;   Render Lua source for terminal preview.
;; render-lua-preview-port : input-port? output-port? -> void?
;;   Render Lua source from a port for terminal preview.

(provide
 ;; render-lua-preview : string? -> string?
 ;;   Render Lua source for terminal preview.
 render-lua-preview
 ;; render-lua-preview-port : input-port? output-port? -> void?
 ;;   Render Lua source from a port for terminal preview.
 render-lua-preview-port)

(require lexers/lua
         racket/port
         "common-style.rkt")

;; lua-derived-token-category : lua-derived-token? -> symbol?
;;   Extract the coarse category from one derived Lua token.
(define (lua-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; lua-token-style : lua-derived-token? -> string?
;;   Choose the ANSI style for one derived Lua token.
(define (lua-token-style token)
  (lua-like-style (lua-derived-token-category token)
                  (lua-derived-token-tags token)))

;; render-lua-preview : string? -> string?
;;   Render Lua source for terminal preview.
(define (render-lua-preview source)
  (apply string-append
         (for/list ([token (lua-string->derived-tokens source)])
           (colorize-text (lua-token-style token)
                          (lua-derived-token-text token)))))

;; render-lua-preview-port : input-port? output-port? -> void?
;;   Render Lua source from a port for terminal preview.
(define (render-lua-preview-port in
                                 [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-lua-derived-lexer))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (lua-token-style token)
                              (lua-derived-token-text token))
               out)
      (loop))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define sample
    "-- Greets a named user.\nlocal function greet(name)\n  local message = [[hello ]] .. name\n  return message, true\nend\n")

  (check-equal?
   (strip-ansi (render-lua-preview sample))
   sample)

  (check-equal?
   (let ([out (open-output-string)])
     (render-lua-preview-port (open-input-string sample)
                              out)
     (strip-ansi (get-output-string out)))
   sample))
