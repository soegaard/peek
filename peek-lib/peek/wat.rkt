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

(module+ test
  (require rackunit
           racket/file
           racket/runtime-path)

  (define-runtime-path demo-wat-path
    "test/fixtures/demo.wat")

  (define wat-rendered
    (render-wat-preview
     ";; note\n(module\n  (func $answer (result i32)\n    i32.const 42)\n  (export \"answer\" (func $answer)))\n"))
  (define malformed-rendered
    (render-wat-preview
     "(module (func (result i32) i32.const 42"))

  (check-true (regexp-match? #px"\u001b\\[" wat-rendered))
  (check-true (regexp-match? #px"note" wat-rendered))
  (check-true (regexp-match? #px"\u001b\\[38;2;86;156;214mmodule\u001b\\[0m"
                             wat-rendered))
  (check-true (regexp-match? #px"\u001b\\[38;2;86;156;214mi32\u001b\\[0m"
                             wat-rendered))
  (check-true (regexp-match? #px"\u001b\\[38;2;86;156;214mi32\\.const\u001b\\[0m"
                             wat-rendered))
  (check-true (regexp-match? #px"\u001b\\[38;2;156;220;254m\\$answer\u001b\\[0m"
                             wat-rendered))
  (check-true (regexp-match? #px"\u001b\\[38;2;206;145;120m\"answer\"\u001b\\[0m"
                             wat-rendered))
  (check-true (regexp-match? #px"\u001b\\[38;2;206;145;120m42\u001b\\[0m"
                             wat-rendered))
  (check-equal? (length (regexp-match* #px"\n" wat-rendered))
                5)
  (check-equal? wat-rendered
                (let ([out (open-output-string)])
                  (render-wat-preview-port
                   (open-input-string
                    ";; note\n(module\n  (func $answer (result i32)\n    i32.const 42)\n  (export \"answer\" (func $answer)))\n")
                   out)
                  (get-output-string out)))
  (check-true (regexp-match? #px"42" malformed-rendered))
  (check-true (regexp-match? #px"module"
                             (render-wat-preview
                              (file->string demo-wat-path)))))
