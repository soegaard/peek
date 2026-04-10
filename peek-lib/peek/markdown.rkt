#lang racket/base

;;;
;;; Markdown Preview
;;;
;;
;; Markdown-specific terminal preview rendering built on `lexers/markdown`.

;; render-markdown-preview : string? -> string?
;;   Render Markdown for terminal preview.

(provide
 ;; render-markdown-preview : string? -> string?
 ;;   Render Markdown for terminal preview.
 render-markdown-preview)

(require lexers/markdown
         lexers/token
         parser-tools/lex
         racket/file
         racket/list
         "common-style.rkt")

(struct markdown-token (category text tags start end) #:transparent)

;; markdown-token-key : markdown-token -> list?
;;   Build a stable key for joining projected and derived tokens.
(define (markdown-token-key token)
  (list (position-offset (markdown-token-start token))
        (position-offset (markdown-token-end token))
        (markdown-token-text token)))

;; derived-token-key : markdown-derived-token? -> list?
;;   Build a stable key for one derived Markdown token.
(define (derived-token-key token)
  (list (position-offset (markdown-derived-token-start token))
        (position-offset (markdown-derived-token-end token))
        (markdown-derived-token-text token)))

;; annotate-markdown-tokens : string? -> (listof markdown-token?)
;;   Combine projected Markdown categories with derived tags.
(define (annotate-markdown-tokens source)
  (define projected
    (markdown-string->tokens source
                             #:profile 'coloring))
  (define derived
    (markdown-string->derived-tokens source))
  (define derived-tags-by-key
    (for/hash ([token derived])
      (values (derived-token-key token)
              (markdown-derived-token-tags token))))
  (for/list ([token projected]
             #:unless (lexer-token-eof? token))
    (define start
      (lexer-token-start token))
    (define end
      (lexer-token-end token))
    (define text
      (lexer-token-value token))
    (define base
      (markdown-token (lexer-token-name token)
                      text
                      '()
                      start
                      end))
    (define tags
      (hash-ref derived-tags-by-key
                (markdown-token-key base)
                '()))
    (struct-copy markdown-token base [tags tags])))

;; token-style : markdown-token -> string?
;;   Choose the ANSI style for one normalized Markdown token.
(define (token-style token)
  (define category
    (markdown-token-category token))
  (define tags
    (markdown-token-tags token))
  (cond
    [(memq 'embedded-css tags)
     (css-like-style category tags)]
    [(memq 'embedded-javascript tags)
     (javascript-like-style category tags)]
    [(memq 'embedded-racket tags)
     (racket-like-style category tags)]
    [(memq 'embedded-scribble tags)
     (scribble-like-style category tags)]
    [(memq 'embedded-html tags)
     (html-like-style category tags)]
    [(or (memq 'malformed-token tags)
         (eq? category 'unknown))
     ansi-malformed]
    [(memq 'markdown-text tags)
     ""]
    [(or (memq 'markdown-heading-marker tags)
         (memq 'markdown-heading-text tags))
     ansi-keyword]
    [(or (memq 'markdown-blockquote-marker tags)
         (memq 'markdown-list-marker tags)
         (memq 'markdown-task-marker tags)
         (memq 'markdown-thematic-break tags)
         (memq 'markdown-code-fence tags)
         (memq 'markdown-emphasis-delimiter tags)
         (memq 'markdown-strong-delimiter tags)
         (memq 'markdown-strikethrough-delimiter tags)
         (memq 'markdown-image-marker tags)
         (memq 'markdown-table-pipe tags)
         (memq 'markdown-escape tags)
         (memq 'markdown-hard-line-break tags)
         (eq? category 'delimiter))
     ansi-delimiter]
    [(memq 'markdown-code-info-string tags)
     ansi-identifier]
    [(or (memq 'markdown-code-span tags)
         (memq 'markdown-code-block tags)
         (memq 'markdown-link-text tags)
         (memq 'markdown-link-destination tags)
         (memq 'markdown-link-title tags)
         (memq 'markdown-autolink tags)
         (memq 'markdown-table-cell tags)
         (memq 'markdown-table-alignment tags)
         (eq? category 'literal))
     ansi-literal]
    [(eq? category 'identifier)
     ansi-identifier]
    [else
     ""]))

;; render-markdown-preview : string? -> string?
;;   Render Markdown for terminal preview.
(define (render-markdown-preview source)
  (apply string-append
         (for/list ([token (annotate-markdown-tokens source)])
           (colorize-text (token-style token)
                          (markdown-token-text token)))))

(module+ test
  (require rackunit
           racket/runtime-path)

  (define-runtime-path demo-markdown-path
    "../../test/fixtures/demo.md")

  (define markdown-rendered
    (render-markdown-preview
     "# Title\n\n> quote\n- [x] done\n\n`code` and [link](https://example.com) and <https://racket-lang.org>\n\n| A | B |\n| :- | -: |\n| 1 | 2 |\n\n```rkt\n(define x 1)\n```\n\n```js\nconst y = 2;\n```\n\n<div class=\"x\"><style>.x { color: #fff; }</style><script>const z = 3;</script></div>\n"))
  (define unknown-fence-rendered
    (render-markdown-preview
     "```unknown\nx\n```\n"))
  (define malformed-rendered
    (render-markdown-preview
     "[broken](\n"))

  (check-true (regexp-match? #px"\u001b\\[" markdown-rendered))
  (check-true (regexp-match? #px"Title" markdown-rendered))
  (check-true (regexp-match? #px"quote" markdown-rendered))
  (check-true (regexp-match? #px"done" markdown-rendered))
  (check-true (regexp-match? #px"`code`" markdown-rendered))
  (check-true (regexp-match? #px"https://example.com" markdown-rendered))
  (check-true (regexp-match? #px"<https://racket-lang.org>" markdown-rendered))
  (check-true (regexp-match? #px"\\|" markdown-rendered))
  (check-true (regexp-match? #px"\u001b\\[38;2;86;156;214mdefine\u001b\\[0m"
                             markdown-rendered))
  (check-true (regexp-match? #px"\u001b\\[38;2;86;156;214mconst\u001b\\[0m"
                             markdown-rendered))
  (check-true (regexp-match? #px"\u001b\\[38;2;86;156;214mdiv\u001b\\[0m"
                             markdown-rendered))
  (check-true (regexp-match? #px"#fff" markdown-rendered))
  (check-true (regexp-match? #px"x" unknown-fence-rendered))
  (check-equal? (length (regexp-match* #px"\n" markdown-rendered))
                18)
  (check-true (regexp-match? #px"broken" malformed-rendered))
  (check-true (regexp-match? #px"Demo Document"
                             (render-markdown-preview
                              (file->string demo-markdown-path)))))
