#lang racket/base

;;;
;;; Makefile Preview
;;;
;;
;; Makefile-specific terminal preview rendering built on `lexers/makefile`.

;; render-makefile-preview      : string? -> string?
;;   Render Makefile source for terminal preview.
;; render-makefile-preview-port : input-port? output-port? -> void?
;;   Render Makefile source from a port for terminal preview.

(provide
 ;; render-makefile-preview : string? -> string?
 ;;   Render Makefile source for terminal preview.
 render-makefile-preview
 ;; render-makefile-preview-port : input-port? output-port? -> void?
 ;;   Render Makefile source from a port for terminal preview.
 render-makefile-preview-port)

(require lexers/makefile
         racket/port
         racket/string
         "common-style.rkt")

;; makefile-derived-token-category : makefile-derived-token? -> symbol?
;;   Extract the coarse category from one derived Makefile token.
(define (makefile-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; makefile-recipe-shell-style : makefile-derived-token? boolean? -> string?
;;   Choose the ANSI style for one shell token embedded in a Makefile recipe.
(define (makefile-recipe-shell-style token
                                     recipe-command-head?)
  (define category
    (makefile-derived-token-category token))
  (define tags
    (makefile-derived-token-tags token))
  (cond
    [(or (memq 'makefile-paren-variable-reference tags)
         (memq 'makefile-brace-variable-reference tags)
         (memq 'makefile-variable-reference tags))
     (makefile-like-style category tags)]
    [(memq 'shell-option tags)
     ansi-delimiter]
    [else
     (shell-like-style category tags)]))

;; makefile-token-style : makefile-derived-token? -> string?
;;   Choose the ANSI style for one derived Makefile token.
(define (makefile-token-style token
                              [assignment-value? #f]
                              [recipe-command-head? #f])
  (define category
    (makefile-derived-token-category token))
  (define tags
    (makefile-derived-token-tags token))
  (cond
    [assignment-value?
     (cond
       [(or (eq? category 'whitespace)
            (memq 'whitespace tags))
        ""]
       [(or (memq 'comment tags)
            (memq 'makefile-comment tags)
            (eq? category 'comment))
        ansi-comment]
       [(or (memq 'makefile-variable tags)
            (memq 'makefile-paren-variable-reference tags)
            (memq 'makefile-brace-variable-reference tags)
            (memq 'makefile-variable-reference tags)
            (memq 'makefile-assignment-operator tags))
        (makefile-like-style category tags)]
       [else
        ansi-literal])]
    [(and recipe-command-head?
          (memq 'embedded-shell tags)
          (memq 'shell-word tags))
     (makefile-recipe-shell-style token recipe-command-head?)]
    [(or (memq 'embedded-shell tags)
         (and (memq 'makefile-recipe tags)
              (not (memq 'makefile-recipe-prefix tags))))
     (makefile-recipe-shell-style token recipe-command-head?)]
    [else
     (makefile-like-style category tags)]))

;; next-assignment-value? : makefile-derived-token? boolean? -> boolean?
;;   Track whether subsequent tokens are on the right-hand side of an assignment.
(define (next-assignment-value? token
                                assignment-value?)
  (define category
    (makefile-derived-token-category token))
  (define tags
    (makefile-derived-token-tags token))
  (cond
    [(or (regexp-match? #px"\n" (makefile-derived-token-text token))
         (eq? category 'comment)
         (memq 'comment tags)
         (memq 'makefile-comment tags))
     #f]
    [(memq 'makefile-assignment-operator tags)
     #t]
    [else
     assignment-value?]))

;; next-recipe-command-head? : makefile-derived-token? boolean? -> boolean?
;;   Track whether the next recipe token is still in command-head position.
(define (next-recipe-command-head? token
                                   recipe-command-head?)
  (define tags
    (makefile-derived-token-tags token))
  (cond
    [(regexp-match? #px"\n" (makefile-derived-token-text token))
     #f]
    [(memq 'makefile-recipe-prefix tags)
     #t]
    [(and recipe-command-head?
          (memq 'whitespace tags))
     #t]
    [(and recipe-command-head?
          (memq 'makefile-recipe tags))
     #f]
    [else
     recipe-command-head?]))

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

;; render-makefile-preview : string? -> string?
;;   Render Makefile source for terminal preview.
(define (render-makefile-preview source)
  (define out
    (open-output-string))
  (for/fold ([assignment-value? #f]
             [recipe-command-head? #f])
            ([token (in-list (makefile-string->derived-tokens source))])
    (display (colorize-text (makefile-token-style token
                                                  assignment-value?
                                                  recipe-command-head?)
                            (makefile-derived-token-text token))
             out)
    (values (next-assignment-value? token assignment-value?)
            (next-recipe-command-head? token recipe-command-head?)))
  (get-output-string out))

;; render-makefile-preview-port : input-port? output-port? -> void?
;;   Render Makefile source from a port for terminal preview.
(define (render-makefile-preview-port in
                                      [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-makefile-derived-lexer))
  (let loop ([assignment-value? #f]
             [recipe-command-head? #f])
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (makefile-token-style token
                                                    assignment-value?
                                                    recipe-command-head?)
                              (makefile-derived-token-text token))
               out)
      (loop (next-assignment-value? token assignment-value?)
            (next-recipe-command-head? token recipe-command-head?)))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define sample
    "CC := gcc\nall: main.o util.o\n\t$(CC) -o app main.o util.o\ninclude local.mk\n")

  (define assignment-sample
    "WEBRACKET_PATH = d:/NotMyProject/webracket/webracket.rkt\n")

  (define assignment-reference-sample
    "RACKET = racket $(WEBRACKET_PATH)\n")

  (define recipe-command-sample
    "show-pages: $(NEW_TERM_PAGE_DELIVERABLES) $(MINISCHEME_PAGE_DELIVERABLES)\n\traco static-web -p 8090 -l\n")

  (define crlf-sample
    (string-append
     "WEBRACKET_PATH = d:/NotMyProject/webracket/webracket.rkt\r\n"
     "RACKET = racket $(WEBRACKET_PATH)\r\n"
     "\r\n"
     "show-pages: $(NEW_TERM_PAGE_DELIVERABLES) $(MINISCHEME_PAGE_DELIVERABLES)\r\n"
     "\traco static-web -p 8090 -l\r\n"))

  (check-equal?
   (strip-ansi (render-makefile-preview sample))
   sample)

  (check-equal?
   (let ([out (open-output-string)])
     (render-makefile-preview-port (open-input-string sample)
                                   out)
     (strip-ansi (get-output-string out)))
   sample)

  (check-true
   (string-contains? (render-makefile-preview assignment-sample)
                     (string-append ansi-identifier "WEBRACKET_PATH" ansi-reset)))

  (check-true
   (string-contains? (render-makefile-preview assignment-sample)
                     (string-append ansi-literal "d" ansi-reset)))

  (check-true
   (string-contains? (render-makefile-preview assignment-sample)
                     (string-append ansi-literal "/NotMyProject/webracket/webracket.rkt" ansi-reset)))

  (check-true
   (string-contains? (render-makefile-preview assignment-reference-sample)
                     (string-append ansi-literal "racket" ansi-reset)))

  (check-true
   (string-contains? (render-makefile-preview assignment-reference-sample)
                     (string-append ansi-keyword "$(WEBRACKET_PATH)" ansi-reset)))

  (check-true
   (string-contains? (render-makefile-preview recipe-command-sample)
                     (string-append ansi-identifier "raco" ansi-reset)))

  (check-true
   (string-contains? (render-makefile-preview recipe-command-sample)
                     (string-append ansi-identifier "static-web" ansi-reset)))

  (check-true
   (string-contains? (render-makefile-preview recipe-command-sample)
                     (string-append ansi-delimiter "-p" ansi-reset)))

  (check-true
   (string-contains? (render-makefile-preview recipe-command-sample)
                     (string-append ansi-delimiter "-l" ansi-reset)))

  (check-true
   (string-contains? (render-makefile-preview crlf-sample)
                     (string-append ansi-builtin "show-pages" ansi-reset)))

  (check-true
   (string-contains? (render-makefile-preview crlf-sample)
                     (string-append ansi-identifier "raco" ansi-reset))))
