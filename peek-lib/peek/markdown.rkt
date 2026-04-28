#lang racket/base

;;;
;;; Markdown Preview
;;;
;;
;; Markdown-specific terminal preview rendering built on `lexers/markdown`.

;; render-markdown-preview : string? #:pretty? boolean? -> string?
;;   Render Markdown for terminal preview.
;; render-markdown-preview-port : input-port? output-port? #:pretty? boolean? -> void?
;;   Render Markdown from a port for terminal preview.

(provide
 ;; render-markdown-preview : string? #:pretty? boolean? -> string?
 ;;   Render Markdown for terminal preview.
 render-markdown-preview
 ;; render-markdown-preview-port : input-port? output-port? #:pretty? boolean? -> void?
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

;; markdown-heading-level : markdown-token? -> (or/c exact-positive-integer? #f)
;;   Infer the heading level from one Markdown heading marker token.
(define (markdown-heading-level token)
  (define text
    (markdown-token-text token))
  (cond
    [(positive? (string-length text))
     (string-length text)]
    [else
     #f]))

;; annotate-markdown-context : (listof markdown-token?) -> (listof markdown-token?)
;;   Attach consumer-side inline and structural context tags.
(define (annotate-markdown-context tokens)
  (let loop ([remaining tokens]
             [strong-open? #f]
             [pending-heading-level #f]
             [hide-code-info-newline? #f]
             [acc '()])
    (cond
      [(null? remaining)
       (reverse acc)]
      [else
       (define token
         (car remaining))
       (define tags
         (markdown-token-tags token))
       (define strong-delimiter?
         (memq 'markdown-strong-delimiter tags))
       (define heading-marker?
         (memq 'markdown-heading-marker tags))
       (define heading-text?
         (memq 'markdown-heading-text tags))
       (define code-info-text?
         (and (memq 'markdown-code-info-string tags)
              (string-ci=? (markdown-token-text token) "text")))
       (define current-heading-level
         (cond
           [heading-marker?
            (markdown-heading-level token)]
           [else
            pending-heading-level]))
       (define strong-text?
         (and strong-open?
              (memq 'markdown-text tags)))
       (define next-token
         (struct-copy markdown-token token
                      [tags (append tags
                                    (cond
                                      [strong-text?
                                       '(markdown-strong-text)]
                                      [else
                                       '()])
                                    (cond
                                      [(and pending-heading-level
                                            (eq? (markdown-token-category token)
                                                 'whitespace)
                                            (string=? (markdown-token-text token)
                                                      " "))
                                       '(markdown-heading-gap)]
                                      [else
                                       '()])
                                    (cond
                                      [(and hide-code-info-newline?
                                            (eq? (markdown-token-category token)
                                                 'whitespace)
                                            (string=? (markdown-token-text token)
                                                      "\n"))
                                       '(markdown-hidden-code-info-newline)]
                                      [else
                                       '()])
                                    (cond
                                      [current-heading-level
                                       (list (string->symbol
                                              (format "markdown-heading-level-~a"
                                                      current-heading-level)))]
                                      [else
                                       '()]))]))
       (loop (cdr remaining)
             (if strong-delimiter?
                 (not strong-open?)
                 strong-open?)
             (cond
               [(and heading-text?
                     pending-heading-level)
                #f]
               [heading-marker?
                current-heading-level]
               [(eq? (markdown-token-category token) 'whitespace)
                pending-heading-level]
               [else
                #f])
             (cond
               [code-info-text?
                #t]
               [(and hide-code-info-newline?
                     (eq? (markdown-token-category token) 'whitespace)
                     (string=? (markdown-token-text token) "\n"))
                #f]
               [else
                hide-code-info-newline?])
             (cons next-token acc))])))

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
  (annotate-markdown-context
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
                                                            text))]))))

;; markdown-heading-style : (listof symbol?) -> string?
;;   Choose a graded style for one Markdown heading token.
(define (markdown-heading-style tags)
  (cond
    [(memq 'markdown-heading-level-1 tags)
     "\033[1;38;2;140;210;255m"]
    [(memq 'markdown-heading-level-2 tags)
     "\033[1;38;2;110;190;245m"]
    [(memq 'markdown-heading-level-3 tags)
     "\033[38;2;86;156;214m"]
    [(memq 'markdown-heading-level-4 tags)
     "\033[38;2;118;169;214m"]
    [(memq 'markdown-heading-level-5 tags)
     "\033[38;2;150;182;206m"]
    [(memq 'markdown-heading-level-6 tags)
     "\033[38;2;180;194;204m"]
    [else
     ansi-keyword]))

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
    [(memq 'markdown-strong-text tags)
     ansi-keyword]
    [(memq 'markdown-text tags)
     ""]
    [(or (memq 'markdown-heading-marker tags)
         (memq 'markdown-heading-text tags))
     (markdown-heading-style tags)]
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

;; markdown-token-display-text : markdown-token? boolean? -> string?
;;   Choose the visible token text, optionally omitting source punctuation.
(define (markdown-token-display-text token pretty?)
  (define text
    (markdown-token-text token))
  (define tags
    (markdown-token-tags token))
  (define embedded-token?
    (for/or ([tag (in-list tags)])
      (and (symbol? tag)
           (regexp-match? #px"^embedded-" (symbol->string tag)))))
  (cond
    [(and pretty?
          (memq 'markdown-code-fence tags))
     ""]
    [(and pretty?
          (memq 'markdown-code-info-string tags)
          (string-ci=? text "text"))
     ""]
    [(and pretty?
          (memq 'markdown-hidden-code-info-newline tags))
     ""]
    [(and pretty?
          (memq 'markdown-blockquote-marker tags))
     "│ "]
    [(and pretty?
          (memq 'markdown-thematic-break tags))
     "───\n"]
    [(and pretty?
          (memq 'markdown-heading-gap tags))
     ""]
    [(and pretty?
          (memq 'markdown-heading-marker tags))
     ""]
    [(and pretty?
          (not embedded-token?)
          (or (memq 'markdown-emphasis-delimiter tags)
              (memq 'markdown-strong-delimiter tags)
              (memq 'markdown-strikethrough-delimiter tags)))
     ""]
    [(and pretty?
          (memq 'markdown-task-marker tags))
     (cond
       [(string-ci=? text "[x]") "☒"]
       [else "☐"])]
    [(and pretty?
          (memq 'markdown-image-marker tags))
     ""]
    [(and pretty?
          (eq? (markdown-token-category token) 'delimiter)
          (not embedded-token?)
          (member text '("[" "]" "(" ")")))
     ""]
    [(and pretty?
          (memq 'markdown-code-span tags))
     (define leading-backticks
       (for/fold ([count 0])
                 ([ch (in-string text)]
                  #:break (not (char=? ch #\`)))
         (add1 count)))
     (cond
       [(and (positive? leading-backticks)
             (>= (string-length text)
                 (* 2 leading-backticks))
             (string=? (substring text 0 leading-backticks)
                       (make-string leading-backticks #\`))
             (string=? (substring text
                                  (- (string-length text) leading-backticks))
                       (make-string leading-backticks #\`)))
       (substring text
                   leading-backticks
                   (- (string-length text) leading-backticks))]
       [else
        text])]
    [(and pretty?
          (memq 'markdown-link-destination tags))
     (string-append " " text)]
    [(and pretty?
          (memq 'markdown-link-title tags))
     (define bare-title
       (cond
         [(and (>= (string-length text) 2)
               (or (and (string-prefix? text "\"")
                        (string-suffix? text "\""))
                   (and (string-prefix? text "'")
                        (string-suffix? text "'"))))
          (substring text 1 (sub1 (string-length text)))]
         [else
          text]))
     (string-append " — " bare-title)]
    [(and pretty?
          (memq 'markdown-autolink tags)
          (>= (string-length text) 2)
          (string-prefix? text "<")
          (string-suffix? text ">"))
     (substring text 1 (sub1 (string-length text)))]
    [else
     text]))

;; render-markdown-preview : string? #:pretty? boolean? -> string?
;;   Render Markdown for terminal preview.
(define (render-markdown-preview source
                                 #:pretty? [pretty? #f])
  (apply string-append
         (for/list ([token (annotate-markdown-tokens source)])
           (colorize-text (token-style token)
                          (markdown-token-display-text token pretty?)))))

;; render-markdown-preview-port : input-port? output-port? #:pretty? boolean? -> void?
;;   Render Markdown from a port for terminal preview.
(define (render-markdown-preview-port in
                                     [out (current-output-port)]
                                     #:pretty? [pretty? #f])
  (display (render-markdown-preview (port->string in)
                                    #:pretty? pretty?)
           out))
