#lang racket/base

;;;
;;; JavaScript Preview
;;;
;;
;; JavaScript- and JSX-specific terminal preview rendering built on
;; `lexers/javascript`.

;; render-javascript-preview : string? #:jsx? boolean? -> string?
;;   Render JavaScript or JSX with ANSI coloring.

(provide
 ;; render-javascript-preview : string? #:jsx? boolean? -> string?
 ;;   Render JavaScript or JSX for terminal preview.
 render-javascript-preview)

(require lexers/javascript
         lexers/token
         parser-tools/lex
         racket/list
         racket/string)

(struct javascript-token (category text tags start end) #:transparent)

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

;; javascript-token-key : javascript-token -> list?
;;   Build a stable key for joining projected and derived tokens.
(define (javascript-token-key token)
  (list (position-offset (javascript-token-start token))
        (position-offset (javascript-token-end token))
        (javascript-token-text token)))

;; derived-token-key : javascript-derived-token? -> list?
;;   Build a stable key for one derived JavaScript token.
(define (derived-token-key token)
  (list (position-offset (javascript-derived-token-start token))
        (position-offset (javascript-derived-token-end token))
        (javascript-derived-token-text token)))

;; annotate-javascript-tokens : string? boolean? -> (listof javascript-token?)
;;   Combine projected JavaScript categories with derived tags.
(define (annotate-javascript-tokens source jsx?)
  (define projected
    (javascript-string->tokens source
                               #:profile 'coloring
                               #:jsx?    jsx?))
  (define derived
    (javascript-string->derived-tokens source
                                       #:jsx? jsx?))
  (define derived-tags-by-key
    (for/hash ([token derived])
      (values (derived-token-key token)
              (javascript-derived-token-tags token))))
  (for/list ([token projected]
             #:unless (lexer-token-eof? token))
    (define start (lexer-token-start token))
    (define end   (lexer-token-end token))
    (define text  (lexer-token-value token))
    (define base
      (javascript-token (lexer-token-name token)
                        text
                        '()
                        start
                        end))
    (define tags
      (hash-ref derived-tags-by-key
                (javascript-token-key base)
                '()))
    (struct-copy javascript-token base [tags tags])))

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

;; token-style : javascript-token -> string?
;;   Choose the ANSI style for one normalized JavaScript token.
(define (token-style token)
  (define category
    (javascript-token-category token))
  (define tags
    (javascript-token-tags token))
  (cond
    [(or (memq 'malformed-token tags)
         (eq? category 'unknown))
     ansi-malformed]
    [(or (eq? category 'comment)
         (memq 'comment tags))
     ansi-comment]
    [(or (memq 'keyword tags)
         (memq 'static-keyword-usage tags)
         (memq 'jsx-tag-name tags)
         (memq 'jsx-closing-tag-name tags))
     ansi-keyword]
    [(or (memq 'declaration-name tags)
         (memq 'parameter-name tags)
         (memq 'property-name tags)
         (memq 'method-name tags)
         (memq 'private-name tags)
         (memq 'object-key tags)
         (memq 'jsx-attribute-name tags))
     ansi-identifier]
    [(or (memq 'string-literal tags)
         (memq 'numeric-literal tags)
         (memq 'regex-literal tags)
         (memq 'template-literal tags)
         (memq 'template-chunk tags))
     ansi-literal]
    [(or (memq 'jsx-interpolation-boundary tags)
         (memq 'jsx-fragment-boundary tags)
         (eq? category 'operator)
         (eq? category 'delimiter))
     ansi-delimiter]
    [(eq? category 'literal)    ansi-literal]
    [(eq? category 'identifier) ansi-identifier]
    [else                       ""]))

;; render-javascript-preview : string? #:jsx? boolean? -> string?
;;   Render JavaScript or JSX for terminal preview.
(define (render-javascript-preview source
                                   #:jsx? [jsx? #f])
  (apply string-append
         (for/list ([token (annotate-javascript-tokens source jsx?)])
           (colorize-text (token-style token)
                          (javascript-token-text token)))))

(module+ test
  (require rackunit)

  (define js-rendered
    (render-javascript-preview "const answer = 42;\nobj.run(answer);\n"))
  (define jsx-rendered
    (render-javascript-preview "const el = <Button kind=\"primary\">Hello {name}</Button>;\n"
                               #:jsx? #t))

  (check-true (regexp-match? #px"\u001b\\[" js-rendered))
  (check-true (regexp-match? #px"answer" js-rendered))
  (check-true (regexp-match? #px"run" js-rendered))
  (check-true (regexp-match? #px"Button" jsx-rendered))
  (check-true (regexp-match? #px"kind" jsx-rendered))
  (check-true (regexp-match? #px"Hello" jsx-rendered)))
