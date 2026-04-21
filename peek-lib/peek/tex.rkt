#lang racket/base

;;;
;;; TeX Preview
;;;
;;
;; TeX and LaTeX terminal preview rendering built on `lexers/tex` and
;; `lexers/latex`.

;; render-tex-preview      : string? -> string?
;;   Render TeX for terminal preview.
;; render-tex-preview-port : input-port? output-port? -> void?
;;   Render TeX from a port for terminal preview.
;; render-latex-preview      : string? -> string?
;;   Render LaTeX for terminal preview.
;; render-latex-preview-port : input-port? output-port? -> void?
;;   Render LaTeX from a port for terminal preview.

(provide
 ;; render-tex-preview      : string? -> string?
 ;;   Render TeX for terminal preview.
 render-tex-preview
 ;; render-tex-preview-port : input-port? output-port? -> void?
 ;;   Render TeX from a port for terminal preview.
 render-tex-preview-port
 ;; render-latex-preview      : string? -> string?
 ;;   Render LaTeX for terminal preview.
 render-latex-preview
 ;; render-latex-preview-port : input-port? output-port? -> void?
 ;;   Render LaTeX from a port for terminal preview.
 render-latex-preview-port)

(require lexers/tex
         lexers/latex
         racket/port
         racket/string
         "common-style.rkt")

;; colorize-text : string? string? -> string?
;;   Apply ANSI styling while preserving newlines.
(define (colorize-text code text)
  (cond
    [(or (string=? code "") (string=? text "")) text]
    [else
     (string-append code
                    (string-join (string-split text "\n" #:trim? #f)
                                 (string-append ansi-reset "\n" code))
                    ansi-reset)]))

;; style-from-tags : (listof symbol?) -> string?
;;   Choose an ANSI style for TeX or LaTeX derived tags.
(define (style-from-tags tags)
  (tex-like-style tags))

;; render-derived-preview : (listof any/c) (-> string?) -> string?
;;   Render a derived-token list with TeX/LaTeX coloring.
(define (render-derived-preview tokens token-text)
  (apply string-append
         (for/list ([token tokens])
           (colorize-text (style-from-tags (tex-derived-token-tags token))
                          (token-text token)))))

;; render-derived-preview-port : input-port? output-port? (input-port? -> (or/c tex-derived-token? 'eof)) (-> string?) -> void?
;;   Render a derived-token stream directly to a port.
(define (render-derived-preview-port in
                                    out
                                    lexer
                                    token-text)
  (port-count-lines! in)
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (style-from-tags (tex-derived-token-tags token))
                              (token-text token))
               out)
      (loop))))

;; render-tex-preview : string? -> string?
;;   Render TeX for terminal preview.
(define (render-tex-preview source)
  (render-derived-preview (tex-string->derived-tokens source)
                          tex-derived-token-text))

;; render-tex-preview-port : input-port? output-port? -> void?
;;   Render TeX from a port for terminal preview.
(define (render-tex-preview-port in
                                 [out (current-output-port)])
  (render-derived-preview-port in
                               out
                               (make-tex-derived-lexer)
                               tex-derived-token-text))

;; render-latex-preview : string? -> string?
;;   Render LaTeX for terminal preview.
(define (render-latex-preview source)
  (render-derived-preview (latex-string->derived-tokens source)
                          latex-derived-token-text))

;; render-latex-preview-port : input-port? output-port? -> void?
;;   Render LaTeX from a port for terminal preview.
(define (render-latex-preview-port in
                                   [out (current-output-port)])
  (render-derived-preview-port in
                               out
                               (make-latex-derived-lexer)
                               latex-derived-token-text))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define tex-sample
    "\\section{Hi}\nText with \\% and $x+y$.\n% comment\n")
  (define latex-sample
    "\\begin{itemize}\n\\item One\n\\end{itemize}\n")

  (check-equal? (strip-ansi (render-tex-preview tex-sample))
                tex-sample)
  (check-equal? (strip-ansi (render-latex-preview latex-sample))
                latex-sample)
  (check-true (regexp-match? #px"section"
                             (render-tex-preview tex-sample)))
  (check-true (regexp-match? #px"begin"
                             (render-latex-preview latex-sample)))
  (check-equal?
   (strip-ansi
    (let ([out (open-output-string)])
      (render-tex-preview-port (open-input-string tex-sample) out)
      (get-output-string out)))
   tex-sample)
  (check-equal?
   (strip-ansi
    (let ([out (open-output-string)])
      (render-latex-preview-port (open-input-string latex-sample) out)
      (get-output-string out)))
   latex-sample))
