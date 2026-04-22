#lang racket/base

;;;
;;; Python Preview
;;;
;;
;; Python-specific terminal preview rendering built on `lexers/python`.

;; render-python-preview      : string? -> string?
;;   Render Python source for terminal preview.
;; render-python-preview-port : input-port? output-port? -> void?
;;   Render Python source from a port for terminal preview.

(provide
 ;; render-python-preview : string? -> string?
 ;;   Render Python source for terminal preview.
 render-python-preview
 ;; render-python-preview-port : input-port? output-port? -> void?
 ;;   Render Python source from a port for terminal preview.
 render-python-preview-port)

(require lexers/python
         racket/port
         racket/string
         "common-style.rkt")

;; python-derived-token-category : python-derived-token? -> symbol?
;;   Extract the coarse category from one derived Python token.
(define (python-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; python-token-style : python-derived-token? -> string?
;;   Choose the ANSI style for one derived Python token.
(define (python-token-style token)
  (python-like-style (python-derived-token-category token)
                     (python-derived-token-tags token)))

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

;; render-python-preview : string? -> string?
;;   Render Python source for terminal preview.
(define (render-python-preview source)
  (apply string-append
         (for/list ([token (python-string->derived-tokens source)])
           (colorize-text (python-token-style token)
                          (python-derived-token-text token)))))

;; render-python-preview-port : input-port? output-port? -> void?
;;   Render Python source from a port for terminal preview.
(define (render-python-preview-port in
                                    [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-python-derived-lexer))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (python-token-style token)
                              (python-derived-token-text token))
               out)
      (loop))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define sample
    (string-append
     "def answer(name):\n"
     "    data = b\"hello\"\n"
     "    raw = r\"c:\\\\tmp\"\n"
     "    templ = t\"hello\"\n"
     "    return f\"hello, {name} \" + data.decode() + raw + templ\n"))

  (check-equal?
   (strip-ansi (render-python-preview sample))
   sample)

  (check-true
   (regexp-match? #px"\u001b\\[" (render-python-preview sample)))

  (check-equal?
   (let ([out (open-output-string)])
     (render-python-preview-port (open-input-string sample)
                                 out)
     (strip-ansi (get-output-string out)))
   sample))
