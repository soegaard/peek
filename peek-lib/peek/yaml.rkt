#lang racket/base

;;;
;;; YAML Preview
;;;
;;
;; YAML-specific terminal preview rendering built on `lexers/yaml`.

;; render-yaml-preview      : string? -> string?
;;   Render YAML source for terminal preview.
;; render-yaml-preview-port : input-port? output-port? -> void?
;;   Render YAML source from a port for terminal preview.

(provide
 ;; render-yaml-preview : string? -> string?
 ;;   Render YAML source for terminal preview.
 render-yaml-preview
 ;; render-yaml-preview-port : input-port? output-port? -> void?
 ;;   Render YAML source from a port for terminal preview.
 render-yaml-preview-port)

(require lexers/yaml
         racket/port
         racket/string
         "common-style.rkt")

;; yaml-derived-token-category : yaml-derived-token? -> symbol?
;;   Extract the coarse category from one derived YAML token.
(define (yaml-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; yaml-token-style : yaml-derived-token? -> string?
;;   Choose the ANSI style for one derived YAML token.
(define (yaml-token-style token)
  (yaml-like-style (yaml-derived-token-category token)
                   (yaml-derived-token-tags token)))

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

;; render-yaml-preview : string? -> string?
;;   Render YAML source for terminal preview.
(define (render-yaml-preview source)
  (apply string-append
         (for/list ([token (yaml-string->derived-tokens source)])
           (colorize-text (yaml-token-style token)
                          (yaml-derived-token-text token)))))

;; render-yaml-preview-port : input-port? output-port? -> void?
;;   Render YAML source from a port for terminal preview.
(define (render-yaml-preview-port in
                                  [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-yaml-derived-lexer))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (yaml-token-style token)
                              (yaml-derived-token-text token))
               out)
      (loop))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define sample
    "---\nname: &anchor !tag value\nalias: *anchor\nblock: |\n  hello\n  world\nflow: [one, two]\nmap: {a: 1, b: 2}\n")

  (check-equal?
   (strip-ansi (render-yaml-preview sample))
   sample)

  (check-equal?
   (let ([out (open-output-string)])
     (render-yaml-preview-port (open-input-string sample)
                               out)
     (strip-ansi (get-output-string out)))
   sample))
