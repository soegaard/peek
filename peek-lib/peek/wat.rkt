#lang racket/base

;;;
;;; WAT Preview
;;;
;;
;; WAT-specific terminal preview rendering built on `lexers/wat`.

;; render-wat-preview : string? -> string?
;;   Render WAT for terminal preview.

(provide
 ;; render-wat-preview : string? -> string?
 ;;   Render WAT for terminal preview.
 render-wat-preview)

(require lexers/wat
         lexers/token
         parser-tools/lex
         racket/list
         "common-style.rkt")

(struct wat-token (category text tags start end) #:transparent)

;; wat-token-key : wat-token -> list?
;;   Build a stable key for joining projected and derived tokens.
(define (wat-token-key token)
  (list (position-offset (wat-token-start token))
        (position-offset (wat-token-end token))
        (wat-token-text token)))

;; derived-token-key : wat-derived-token? -> list?
;;   Build a stable key for one derived WAT token.
(define (derived-token-key token)
  (list (position-offset (wat-derived-token-start token))
        (position-offset (wat-derived-token-end token))
        (wat-derived-token-text token)))

;; annotate-wat-tokens : string? -> (listof wat-token?)
;;   Combine projected WAT categories with derived tags.
(define (annotate-wat-tokens source)
  (define projected
    (wat-string->tokens source
                        #:profile 'coloring))
  (define derived
    (wat-string->derived-tokens source))
  (define derived-tags-by-key
    (for/hash ([token derived])
      (values (derived-token-key token)
              (wat-derived-token-tags token))))
  (for/list ([token projected]
             #:unless (lexer-token-eof? token))
    (define start
      (lexer-token-start token))
    (define end
      (lexer-token-end token))
    (define text
      (lexer-token-value token))
    (define base
      (wat-token (lexer-token-name token)
                 text
                 '()
                 start
                 end))
    (define tags
      (hash-ref derived-tags-by-key
                (wat-token-key base)
                '()))
    (struct-copy wat-token base [tags tags])))

;; token-style : wat-token -> string?
;;   Choose the ANSI style for one normalized WAT token.
(define (token-style token)
  (wat-like-style (wat-token-category token)
                  (wat-token-tags token)))

;; render-wat-preview : string? -> string?
;;   Render WAT for terminal preview.
(define (render-wat-preview source)
  (apply string-append
         (for/list ([token (annotate-wat-tokens source)])
           (colorize-text (token-style token)
                          (wat-token-text token)))))

(module+ test
  (require rackunit
           racket/file
           racket/runtime-path)

  (define-runtime-path demo-wat-path
    "../../test/fixtures/demo.wat")

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
  (check-true (regexp-match? #px"42" malformed-rendered))
  (check-true (regexp-match? #px"module"
                             (render-wat-preview
                              (file->string demo-wat-path)))))
