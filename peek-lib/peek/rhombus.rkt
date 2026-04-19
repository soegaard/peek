#lang racket/base

;;;
;;; Rhombus Preview
;;;
;;
;; Rhombus-specific terminal preview rendering built on `lexers/rhombus`.

;; render-rhombus-preview      : string? -> string?
;;   Render Rhombus source for terminal preview.
;; render-rhombus-preview-port : input-port? output-port? -> void?
;;   Render Rhombus source from a port for terminal preview.

(provide
 ;; render-rhombus-preview : string? -> string?
 ;;   Render Rhombus source for terminal preview.
 render-rhombus-preview
 ;; render-rhombus-preview-port : input-port? output-port? -> void?
 ;;   Render Rhombus source from a port for terminal preview.
 render-rhombus-preview-port)

(require lexers/rhombus
         "common-style.rkt"
         racket/promise
         racket/port
         racket/string)

;; rhombus-derived-token-category : rhombus-derived-token? -> symbol?
;;   Extract the coarse category from one derived Rhombus token.
(define (rhombus-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; rhombus-token-style : rhombus-derived-token? -> string?
;;   Choose the ANSI style for one derived Rhombus token.
(define (rhombus-token-style token)
  (rhombus-like-style (rhombus-derived-token-category token)
                      (rhombus-derived-token-tags token)))

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

;; rhombus-preview-available? : (-> boolean?)
;;   Determine whether the current installation can render Rhombus previews.
(define rhombus-preview-available?
  (delay/sync
   (with-handlers ([exn:fail? (lambda (_exn) #f)])
     (define lexer
       (make-rhombus-derived-lexer))
     (define in
       (open-input-string "#lang rhombus\n"))
     (port-count-lines! in)
     (void (lexer in))
     #t)))

;; render-rhombus-preview : string? -> string?
;;   Render Rhombus source for terminal preview.
(define (render-rhombus-preview source)
  (cond
    [(not (force rhombus-preview-available?))
     source]
    [else
     (apply string-append
            (for/list ([token (rhombus-string->derived-tokens source)])
              (colorize-text (rhombus-token-style token)
                             (rhombus-derived-token-text token))))]))

;; render-rhombus-preview-port : input-port? output-port? -> void?
;;   Render Rhombus source from a port for terminal preview.
(define (render-rhombus-preview-port in
                                     [out (current-output-port)])
  (port-count-lines! in)
  (cond
    [(not (force rhombus-preview-available?))
     (copy-port in out)]
    [else
     (define lexer
       (make-rhombus-derived-lexer))
     (let loop ()
       (define token
         (lexer in))
       (unless (eq? token 'eof)
         (display (colorize-text (rhombus-token-style token)
                                 (rhombus-derived-token-text token))
                  out)
         (loop)))]))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define sample
    "#lang rhombus\nfun add(x): x + 1\n")

  (check-equal?
   (strip-ansi (render-rhombus-preview sample))
   sample)

  (check-equal?
   (let ([out (open-output-string)])
     (render-rhombus-preview-port (open-input-string sample)
                                  out)
     (strip-ansi (get-output-string out)))
   sample))
