#lang racket/base

;;;
;;; WAT Preview
;;;
;;
;; WAT-specific terminal preview rendering built on `lexers/wat`.

;; render-wat-preview      : string? -> string?
;;   Render WAT for terminal preview.
;; render-wat-preview-port : input-port? output-port? -> void?
;;   Render WAT from an input port to an output port.

(provide
 ;; render-wat-preview : string? -> string?
 ;;   Render WAT for terminal preview.
 render-wat-preview
 ;; render-wat-preview-port : input-port? output-port? -> void?
 ;;   Render WAT for terminal preview from a port.
 render-wat-preview-port)

(require lexers/wat
         lexers/token
         parser-tools/lex
         "common-style.rkt")

;; token-style/category : symbol? (listof symbol?) -> string?
;;   Choose the ANSI style for one WAT token category/tag pair.
(define (token-style/category category tags)
  (wat-like-style category tags))

;; render-wat-preview-port : input-port? output-port? -> void?
;;   Render WAT from an input port directly to an output port.
(define (render-wat-preview-port in
                                 [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-wat-lexer #:profile 'coloring))
  (let loop ()
    (define token
      (lexer in))
    (unless (lexer-token-eof? token)
      (display (colorize-text (token-style/category (lexer-token-name token) '())
                              (lexer-token-value token))
               out)
      (loop))))

;; render-wat-preview : string? -> string?
;;   Render WAT for terminal preview.
(define (render-wat-preview source)
  (define out
    (open-output-string))
  (render-wat-preview-port (open-input-string source)
                           out)
  (get-output-string out))
