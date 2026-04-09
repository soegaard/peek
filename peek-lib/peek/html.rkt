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
         racket/string)

(struct html-token (category text tags start end) #:transparent)

;; ANSI color constants.
(define (ansi . codes)
  (string-append "\033[" (string-join (map number->string codes) ";") "m"))

(define ansi-reset      (ansi 0))
(define ansi-comment    (ansi 38 2 106 153 85))
(define ansi-keyword    (ansi 38 2 86 156 214))
(define ansi-identifier (ansi 38 2 156 220 254))
(define ansi-literal    (ansi 38 2 206 145 120))
(define ansi-delimiter  (ansi 38 2 212 212 212))
(define ansi-malformed  (ansi 38 2 244 71 71))

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

;; css-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for CSS roles embedded in HTML.
(define (css-like-style category tags)
  (cond
    [(or (member 'selector-token tags)
         (member 'at-rule-name tags))
     ansi-keyword]
    [(or (member 'property-name tags)
         (member 'custom-property-name tags))
     ansi-identifier]
    [(or (member 'declaration-value-token tags)
         (member 'color-literal tags)
         (member 'color-function tags)
         (member 'gradient-function tags)
         (member 'string-literal tags)
         (member 'numeric-literal tags)
         (member 'length-dimension tags))
     ansi-literal]
    [(eq? category 'delimiter)
     ansi-delimiter]
    [(eq? category 'unknown)
     ansi-malformed]
    [(eq? category 'literal)
     ansi-literal]
    [(eq? category 'identifier)
     ansi-identifier]
    [else
     ""]))

;; javascript-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for JavaScript roles embedded in HTML.
(define (javascript-like-style category tags)
  (cond
    [(or (memq 'keyword tags)
         (memq 'static-keyword-usage tags))
     ansi-keyword]
    [(or (memq 'declaration-name tags)
         (memq 'parameter-name tags)
         (memq 'property-name tags)
         (memq 'method-name tags)
         (memq 'private-name tags)
         (memq 'object-key tags))
     ansi-identifier]
    [(or (memq 'string-literal tags)
         (memq 'numeric-literal tags)
         (memq 'regex-literal tags)
         (memq 'template-literal tags)
         (memq 'template-chunk tags))
     ansi-literal]
    [(or (eq? category 'operator)
         (eq? category 'delimiter))
     ansi-delimiter]
    [(eq? category 'literal)
     ansi-literal]
    [(eq? category 'identifier)
     ansi-identifier]
    [else
     ""]))

;; token-style : html-token -> string?
;;   Choose the ANSI style for one normalized HTML token.
(define (token-style token)
  (define category
    (html-token-category token))
  (define tags
    (html-token-tags token))
  (cond
    [(or (memq 'malformed-token tags)
         (eq? category 'unknown))
     ansi-malformed]
    [(or (eq? category 'comment)
         (memq 'comment tags))
     ansi-comment]
    [(memq 'embedded-css tags)
     (css-like-style category tags)]
    [(memq 'embedded-javascript tags)
     (javascript-like-style category tags)]
    [(or (memq 'html-tag-name tags)
         (memq 'html-closing-tag-name tags)
         (memq 'html-doctype tags)
         (eq? category 'keyword))
     ansi-keyword]
    [(memq 'html-attribute-name tags)
     ansi-identifier]
    [(or (memq 'html-attribute-value tags)
         (memq 'html-entity tags))
     ansi-literal]
    [(memq 'html-text tags)
     ""]
    [(or (eq? category 'operator)
         (eq? category 'delimiter))
     ansi-delimiter]
    [(eq? category 'literal)
     ansi-literal]
    [(eq? category 'identifier)
     ansi-identifier]
    [else
     ""]))

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
