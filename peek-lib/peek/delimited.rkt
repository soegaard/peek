#lang racket/base

;;;
;;; Delimited Text Preview
;;;
;;
;; CSV/TSV-specific terminal preview rendering built on `lexers/csv`
;; and `lexers/tsv`.

;; render-csv-preview      : string? -> string?
;;   Render CSV source for terminal preview.
;; render-csv-preview-port : input-port? output-port? -> void?
;;   Render CSV source from a port for terminal preview.
;; render-tsv-preview      : string? -> string?
;;   Render TSV source for terminal preview.
;; render-tsv-preview-port : input-port? output-port? -> void?
;;   Render TSV source from a port for terminal preview.

(provide
 render-csv-preview
 render-csv-preview-port
 render-tsv-preview
 render-tsv-preview-port)

(require lexers/csv
         lexers/tsv
         racket/port
         racket/string
         "common-style.rkt")

;; csv-derived-token-category : csv-derived-token? -> symbol?
;;   Extract the coarse category from one derived CSV token.
(define (csv-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; tsv-derived-token-category : tsv-derived-token? -> symbol?
;;   Extract the coarse category from one derived TSV token.
(define (tsv-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; delimited-token-style : symbol? (listof symbol?) -> string?
;;   Choose the ANSI style for one derived delimited-text token.
(define (delimited-token-style category tags)
  (delimited-like-style category tags))

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

;; render-derived-preview : (listof any/c) (-> string?) (-> symbol?) (-> (listof symbol?)) -> string?
;;   Render a derived-token stream as terminal preview.
(define (render-derived-preview tokens token-text token-category token-tags)
  (apply string-append
         (for/list ([token (in-list tokens)])
           (colorize-text (delimited-token-style (token-category token)
                                                 (token-tags token))
                          (token-text token)))))

;; render-csv-preview : string? -> string?
;;   Render CSV source for terminal preview.
(define (render-csv-preview source)
  (render-derived-preview (csv-string->derived-tokens source)
                          csv-derived-token-text
                          csv-derived-token-category
                          csv-derived-token-tags))

;; render-tsv-preview : string? -> string?
;;   Render TSV source for terminal preview.
(define (render-tsv-preview source)
  (render-derived-preview (tsv-string->derived-tokens source)
                          tsv-derived-token-text
                          tsv-derived-token-category
                          tsv-derived-token-tags))

;; render-csv-preview-port : input-port? output-port? -> void?
;;   Render CSV source from a port for terminal preview.
(define (render-csv-preview-port in
                                 [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-csv-derived-lexer))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (delimited-token-style (csv-derived-token-category token)
                                                     (csv-derived-token-tags token))
                              (csv-derived-token-text token))
               out)
      (loop))))

;; render-tsv-preview-port : input-port? output-port? -> void?
;;   Render TSV source from a port for terminal preview.
(define (render-tsv-preview-port in
                                 [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-tsv-derived-lexer))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (delimited-token-style (tsv-derived-token-category token)
                                                     (tsv-derived-token-tags token))
                              (tsv-derived-token-text token))
               out)
      (loop))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define csv-sample
    "name,age,city\nAda,37,London\n")
  (define tsv-sample
    "name\tage\tcity\nAda\t37\tLondon\n")

  (check-equal?
   (strip-ansi (render-csv-preview csv-sample))
   csv-sample)

  (check-equal?
   (let ([out (open-output-string)])
     (render-csv-preview-port (open-input-string csv-sample)
                              out)
     (strip-ansi (get-output-string out)))
   csv-sample)

  (check-equal?
   (strip-ansi (render-tsv-preview tsv-sample))
   tsv-sample)

  (check-equal?
   (let ([out (open-output-string)])
     (render-tsv-preview-port (open-input-string tsv-sample)
                              out)
     (strip-ansi (get-output-string out)))
   tsv-sample))
