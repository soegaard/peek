#lang racket/base

;;;
;;; Markdown Preview
;;;
;;
;; Markdown-specific terminal preview rendering built on `lexers/markdown`.

;; render-markdown-preview : string? -> string?
;;   Render Markdown for terminal preview.
;; render-markdown-preview-port : input-port? output-port? -> void?
;;   Render Markdown from a port for terminal preview.

(provide
 ;; render-markdown-preview : string? -> string?
 ;;   Render Markdown for terminal preview.
 render-markdown-preview
 ;; render-markdown-preview-port : input-port? output-port? -> void?
 ;;   Render Markdown from a port for terminal preview.
 render-markdown-preview-port)

(require lexers/markdown
         lexers/token
         parser-tools/lex
         racket/file
         racket/list
         racket/port
         racket/string
         "common-style.rkt"
         "private/racket-standard-map.rkt"
         "c.rkt"
         "cpp.rkt"
         "delimited.rkt"
         "json.rkt"
         "java.rkt"
         "pascal.rkt"
         "plist.rkt"
         "python.rkt"
         "tex.rkt"
         "latex.rkt"
         "go.rkt"
         "haskell.rkt"
         "rust.rkt"
         "shell.rkt"
         "swift.rkt")

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

;; derived-token-category : markdown-derived-token? -> symbol?
;;   Extract the coarse category from one derived Markdown token.
(define (derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; markdown-racket-extra-tags : (listof symbol?) string? -> (listof symbol?)
;;   Attach consumer-side Racket vocabulary tags to embedded Racket code.
(define (markdown-racket-extra-tags tags text)
  (cond
    [(memq 'embedded-racket tags)
     (racket-standard-token-tags text)]
    [else
     '()]))

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
    (struct-copy markdown-token base
                 [tags (append tags
                               (markdown-racket-extra-tags tags
                                                           text))])))

;; markdown-like-style : symbol? (listof symbol?) -> string?
;;   Choose the ANSI style for one Markdown token/category pair.
(define (markdown-like-style category tags)
  (cond
    [(memq 'embedded-css tags)
     (css-like-style category tags)]
    [(memq 'embedded-c tags)
     (c-like-style category tags)]
    [(memq 'embedded-cpp tags)
     (cpp-like-style category tags)]
    [(memq 'embedded-java tags)
     (java-like-style category tags)]
    [(memq 'embedded-go tags)
     (go-like-style category tags)]
    [(memq 'embedded-json tags)
     (json-like-style category tags)]
    [(memq 'embedded-pascal tags)
     (pascal-like-style category tags)]
    [(memq 'embedded-plist tags)
     (plist-like-style category tags)]
    [(memq 'embedded-python tags)
     (python-like-style category tags)]
    [(memq 'embedded-rust tags)
     (rust-like-style category tags)]
    [(memq 'embedded-shell tags)
     (shell-like-style category tags)]
    [(memq 'embedded-tex tags)
     (tex-like-style tags)]
    [(memq 'embedded-latex tags)
     (tex-like-style tags)]
    [(memq 'embedded-makefile tags)
     (makefile-like-style category tags)]
    [(memq 'embedded-objc tags)
     (objc-like-style category tags)]
    [(memq 'embedded-javascript tags)
     (javascript-like-style category tags)]
    [(memq 'embedded-wat tags)
     (wat-like-style category tags)]
    [(memq 'embedded-racket tags)
     (racket-like-style category tags)]
    [(memq 'embedded-scribble tags)
     (scribble-like-style category tags)]
    [(memq 'embedded-html tags)
     (html-like-style category tags)]
    [(memq 'embedded-swift tags)
     (swift-like-style category tags)]
    [(memq 'embedded-haskell tags)
     (haskell-like-style category tags)]
    [(memq 'embedded-yaml tags)
     (yaml-like-style category tags)]
    [(memq 'embedded-csv tags)
     (delimited-like-style category tags)]
    [(memq 'embedded-tsv tags)
     (delimited-like-style category tags)]
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
     ansi-keyword]
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

;; token-style : markdown-token -> string?
;;   Choose the ANSI style for one normalized Markdown token.
(define (token-style token)
  (markdown-like-style (markdown-token-category token)
                       (markdown-token-tags token)))

;; render-markdown-preview : string? -> string?
;;   Render Markdown for terminal preview.
(define (render-markdown-preview source)
  (apply string-append
         (for/list ([token (annotate-markdown-tokens source)])
           (colorize-text (token-style token)
                          (markdown-token-text token)))))

;; render-markdown-preview-port : input-port? output-port? -> void?
;;   Render Markdown from a port for terminal preview.
(define (render-markdown-preview-port in
                                     [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-markdown-derived-lexer))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (define tags
        (append (markdown-derived-token-tags token)
                (markdown-racket-extra-tags (markdown-derived-token-tags token)
                                            (markdown-derived-token-text token))))
      (display (colorize-text (markdown-like-style
                               (derived-token-category token)
                               tags)
                              (markdown-derived-token-text token))
               out)
      (loop))))
