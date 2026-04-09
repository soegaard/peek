#lang racket/base

;;;
;;; Racket Preview
;;;
;;
;; Racket-specific terminal preview rendering built on `lexers/racket`.

;; render-racket-preview : string? -> string?
;;   Render Racket for terminal preview.

(provide
 ;; render-racket-preview : string? -> string?
 ;;   Render Racket for terminal preview.
 render-racket-preview)

(require lexers/racket
         lexers/token
         parser-tools/lex
         racket/list
         racket/string)

(struct racket-token (category text tags start end) #:transparent)

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

;; racket-token-key : racket-token -> list?
;;   Build a stable key for joining projected and derived tokens.
(define (racket-token-key token)
  (list (position-offset (racket-token-start token))
        (position-offset (racket-token-end token))
        (racket-token-text token)))

;; derived-token-key : racket-derived-token? -> list?
;;   Build a stable key for one derived Racket token.
(define (derived-token-key token)
  (list (position-offset (racket-derived-token-start token))
        (position-offset (racket-derived-token-end token))
        (racket-derived-token-text token)))

;; annotate-racket-tokens : string? -> (listof racket-token?)
;;   Combine projected Racket categories with derived tags.
(define (annotate-racket-tokens source)
  (define projected
    (racket-string->tokens source
                           #:profile 'coloring))
  (define derived
    (racket-string->derived-tokens source))
  (define derived-tags-by-key
    (for/hash ([token derived])
      (values (derived-token-key token)
              (racket-derived-token-tags token))))
  (for/list ([token projected]
             #:unless (lexer-token-eof? token))
    (define start
      (lexer-token-start token))
    (define end
      (lexer-token-end token))
    (define text
      (lexer-token-value token))
    (define base
      (racket-token (lexer-token-name token)
                    text
                    '()
                    start
                    end))
    (define tags
      (hash-ref derived-tags-by-key
                (racket-token-key base)
                '()))
    (struct-copy racket-token base [tags tags])))

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

;; token-style : racket-token -> string?
;;   Choose the ANSI style for one normalized Racket token.
(define (token-style token)
  (define category
    (racket-token-category token))
  (define tags
    (racket-token-tags token))
  (cond
    [(or (memq 'racket-error tags)
         (eq? category 'unknown))
     ansi-malformed]
    [(or (eq? category 'comment)
         (memq 'racket-comment tags)
         (memq 'racket-sexp-comment tags)
         (memq 'racket-commented-out tags))
     ansi-comment]
    [(or (memq 'racket-usual-special-form tags)
         (memq 'racket-definition-form tags)
         (memq 'racket-binding-form tags)
         (memq 'racket-conditional-form tags))
     ansi-keyword]
    [(or (memq 'racket-string tags)
         (memq 'racket-constant tags)
         (memq 'racket-hash-colon-keyword tags)
         (eq? category 'literal))
     ansi-literal]
    [(or (memq 'racket-parenthesis tags)
         (memq 'racket-open tags)
         (memq 'racket-close tags)
         (memq 'racket-continue tags)
         (eq? category 'delimiter))
     ansi-delimiter]
    [(or (memq 'racket-symbol tags)
         (memq 'racket-datum tags)
         (eq? category 'identifier))
     ansi-identifier]
    [else
     ""]))

;; render-racket-preview : string? -> string?
;;   Render Racket for terminal preview.
(define (render-racket-preview source)
  (apply string-append
         (for/list ([token (annotate-racket-tokens source)])
           (colorize-text (token-style token)
                          (racket-token-text token)))))

(module+ test
  (require rackunit)

  (define racket-rendered
    (render-racket-preview
     "#lang racket/base\n; hi\n#;(+ 1 2)\n(define (greet #:name [name \"you\"])\n  (string-append \"hi \" name))\n"))
  (define malformed-rendered
    (render-racket-preview "\""))
  (define forms-rendered
    (render-racket-preview
     "(define x 1)\n(if x x 0)\n(let ([x 1]) x)\n"))

  (check-true (regexp-match? #px"\u001b\\[" racket-rendered))
  (check-true (regexp-match? #px"#lang" racket-rendered))
  (check-true (regexp-match? #px"racket/base" racket-rendered))
  (check-true (regexp-match? #px"hi" racket-rendered))
  (check-true (regexp-match? #px"#:name" racket-rendered))
  (check-true (regexp-match? #px"greet" racket-rendered))
  (check-true (regexp-match? #px"string-append" racket-rendered))
  (check-true (regexp-match? #px"hi" racket-rendered))
  (check-true (regexp-match? #px"\"" malformed-rendered))
  (check-true (regexp-match? #px"\u001b\\[38;2;86;156;214mdefine\u001b\\[0m" forms-rendered))
  (check-true (regexp-match? #px"\u001b\\[38;2;86;156;214mif\u001b\\[0m" forms-rendered))
  (check-true (regexp-match? #px"\u001b\\[38;2;86;156;214mlet\u001b\\[0m" forms-rendered)))
