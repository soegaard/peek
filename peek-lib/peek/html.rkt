#lang racket/base

;;;
;;; HTML Preview
;;;
;;
;; HTML-specific terminal preview rendering built on `lexers/html`.

;; render-html-preview : string? -> string?
;;   Render HTML for terminal preview.

(provide
 ;; render-html-preview : string? -> string?
 ;;   Render HTML for terminal preview.
 render-html-preview)

(require lexers/html
         lexers/token
         parser-tools/lex
         racket/list
         "common-style.rkt")

(struct html-token (category text tags start end) #:transparent)

;; html-token-key : html-token -> list?
;;   Build a stable key for joining projected and derived tokens.
(define (html-token-key token)
  (list (position-offset (html-token-start token))
        (position-offset (html-token-end token))
        (html-token-text token)))

;; derived-token-key : html-derived-token? -> list?
;;   Build a stable key for one derived HTML token.
(define (derived-token-key token)
  (list (position-offset (html-derived-token-start token))
        (position-offset (html-derived-token-end token))
        (html-derived-token-text token)))

;; annotate-html-tokens : string? -> (listof html-token?)
;;   Combine projected HTML categories with derived tags.
(define (annotate-html-tokens source)
  (define projected
    (html-string->tokens source
                         #:profile 'coloring))
  (define derived
    (html-string->derived-tokens source))
  (define derived-tags-by-key
    (for/hash ([token derived])
      (values (derived-token-key token)
              (html-derived-token-tags token))))
  (for/list ([token projected]
             #:unless (lexer-token-eof? token))
    (define start (lexer-token-start token))
    (define end   (lexer-token-end token))
    (define text  (lexer-token-value token))
    (define base
      (html-token (lexer-token-name token)
                  text
                  '()
                  start
                  end))
    (define tags
      (hash-ref derived-tags-by-key
                (html-token-key base)
                '()))
    (struct-copy html-token base [tags tags])))

;; token-style : html-token -> string?
;;   Choose the ANSI style for one normalized HTML token.
(define (token-style token)
  (html-like-style (html-token-category token)
                   (html-token-tags token)))

;; render-html-preview : string? -> string?
;;   Render HTML for terminal preview.
(define (render-html-preview source)
  (apply string-append
         (for/list ([token (annotate-html-tokens source)])
           (colorize-text (token-style token)
                          (html-token-text token)))))

(module+ test
  (require rackunit)

  (define html-rendered
    (render-html-preview
     "<!doctype html><main id=\"app\">Hi &amp; bye<style>.x { color: #fff; }</style><script>const answer = 42;</script><!-- note --></main>"))
  (define malformed-rendered
    (render-html-preview "<div class=\"unterminated\ntext"))

  (check-true  (regexp-match? #px"\u001b\\[" html-rendered))
  (check-true  (regexp-match? #px"doctype" html-rendered))
  (check-true  (regexp-match? #px"main" html-rendered))
  (check-true  (regexp-match? #px"app" html-rendered))
  (check-true  (regexp-match? #px"&amp;" html-rendered))
  (check-true  (regexp-match? #px"color" html-rendered))
  (check-true  (regexp-match? #px"#fff" html-rendered))
  (check-true  (regexp-match? #px"const" html-rendered))
  (check-true  (regexp-match? #px"answer" html-rendered))
  (check-true  (regexp-match? #px"note" html-rendered))
  (check-true  (regexp-match? #px"unterminated" malformed-rendered)))
