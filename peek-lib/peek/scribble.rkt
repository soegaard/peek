#lang racket/base

;;;
;;; Scribble Preview
;;;
;;
;; Scribble-specific terminal preview rendering built on `lexers/scribble`.

;; render-scribble-preview : string? -> string?
;;   Render Scribble for terminal preview.

(provide
 ;; render-scribble-preview : string? -> string?
 ;;   Render Scribble for terminal preview.
 render-scribble-preview)

(require lexers/scribble
         lexers/token
         parser-tools/lex
         racket/list
         racket/string)

(struct scribble-token (category text tags start end) #:transparent)

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

;; scribble-token-key : scribble-token -> list?
;;   Build a stable key for joining projected and derived tokens.
(define (scribble-token-key token)
  (list (position-offset (scribble-token-start token))
        (position-offset (scribble-token-end token))
        (scribble-token-text token)))

;; derived-token-key : scribble-derived-token? -> list?
;;   Build a stable key for one derived Scribble token.
(define (derived-token-key token)
  (list (position-offset (scribble-derived-token-start token))
        (position-offset (scribble-derived-token-end token))
        (scribble-derived-token-text token)))

;; annotate-scribble-tokens : string? -> (listof scribble-token?)
;;   Combine projected Scribble categories with derived tags.
(define (annotate-scribble-tokens source)
  (define projected
    (scribble-string->tokens source
                             #:profile 'coloring))
  (define derived
    (scribble-string->derived-tokens source))
  (define derived-tags-by-key
    (for/hash ([token derived])
      (values (derived-token-key token)
              (scribble-derived-token-tags token))))
  (for/list ([token projected]
             #:unless (lexer-token-eof? token))
    (define start
      (lexer-token-start token))
    (define end
      (lexer-token-end token))
    (define text
      (lexer-token-value token))
    (define base
      (scribble-token (lexer-token-name token)
                      text
                      '()
                      start
                      end))
    (define tags
      (hash-ref derived-tags-by-key
                (scribble-token-key base)
                '()))
    (struct-copy scribble-token base [tags tags])))

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

;; racket-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for Racket-like roles inside Scribble escapes.
(define (racket-like-style category tags)
  (cond
    [(or (memq 'scribble-error tags)
         (eq? category 'unknown))
     ansi-malformed]
    [(or (memq 'scribble-comment tags)
         (eq? category 'comment))
     ansi-comment]
    [(or (memq 'scribble-string tags)
         (memq 'scribble-constant tags)
         (eq? category 'literal))
     ansi-literal]
    [(or (memq 'scribble-parenthesis tags)
         (eq? category 'delimiter))
     ansi-delimiter]
    [(or (memq 'scribble-symbol tags)
         (memq 'scribble-other tags)
         (eq? category 'identifier))
     ansi-identifier]
    [else
     ""]))

;; token-style : scribble-token -> string?
;;   Choose the ANSI style for one normalized Scribble token.
(define (token-style token)
  (define category
    (scribble-token-category token))
  (define tags
    (scribble-token-tags token))
  (cond
    [(or (memq 'scribble-error tags)
         (eq? category 'unknown))
     ansi-malformed]
    [(or (memq 'scribble-comment tags)
         (eq? category 'comment))
     ansi-comment]
    [(memq 'scribble-racket-escape tags)
     (racket-like-style category tags)]
    [(memq 'scribble-text tags)
     ""]
    [(memq 'scribble-command tags)
     ansi-keyword]
    [(or (memq 'scribble-command-char tags)
         (memq 'scribble-body-delimiter tags)
         (memq 'scribble-optional-delimiter tags)
         (memq 'scribble-parenthesis tags)
         (eq? category 'delimiter))
     ansi-delimiter]
    [(or (memq 'scribble-string tags)
         (memq 'scribble-constant tags)
         (eq? category 'literal))
     ansi-literal]
    [(or (memq 'scribble-symbol tags)
         (memq 'scribble-other tags)
         (eq? category 'identifier))
     ansi-identifier]
    [else
     ""]))

;; render-scribble-preview : string? -> string?
;;   Render Scribble for terminal preview.
(define (render-scribble-preview source)
  (apply string-append
         (for/list ([token (annotate-scribble-tokens source)])
           (colorize-text (token-style token)
                          (scribble-token-text token)))))

(module+ test
  (require rackunit)

  (define scribble-rendered
    (render-scribble-preview
     "#lang scribble/manual\n@title{Hi}\nText\n@itemlist[@item{One} @item{Two}]\n@racket[(define x 1)]\n"))
  (define malformed-rendered
    (render-scribble-preview "@title{Hi"))

  (check-true (regexp-match? #px"\u001b\\[" scribble-rendered))
  (check-true (regexp-match? #px"#lang" scribble-rendered))
  (check-true (regexp-match? #px"title" scribble-rendered))
  (check-true (regexp-match? #px"itemlist" scribble-rendered))
  (check-true (regexp-match? #px"@" scribble-rendered))
  (check-true (regexp-match? #px"define" scribble-rendered))
  (check-true (regexp-match? #px"Text" scribble-rendered))
  (check-true (regexp-match? #px"Hi" malformed-rendered)))
