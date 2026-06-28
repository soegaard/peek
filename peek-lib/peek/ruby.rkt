#lang racket/base

;;;
;;; Ruby Preview
;;;
;;
;; Ruby-specific terminal preview rendering built on `lexers/ruby`.

;; render-ruby-preview      : string? -> string?
;;   Render Ruby source for terminal preview.
;; render-ruby-preview-port : input-port? output-port? -> void?
;;   Render Ruby source from a port for terminal preview.

(provide
 ;; render-ruby-preview : string? -> string?
 ;;   Render Ruby source for terminal preview.
 render-ruby-preview
 ;; render-ruby-preview-port : input-port? output-port? -> void?
 ;;   Render Ruby source from a port for terminal preview.
 render-ruby-preview-port)

(require lexers/ruby
         racket/port
         racket/string
         "common-style.rkt")

;; ruby-derived-token-category : ruby-derived-token? -> symbol?
;;   Extract the coarse category from one derived Ruby token.
(define (ruby-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; ruby-token-style : ruby-derived-token? -> string?
;;   Choose the ANSI style for one derived Ruby token.
(define (ruby-token-style token)
  (ruby-like-style (ruby-derived-token-category token)
                   (ruby-derived-token-tags token)))

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

;; render-ruby-preview : string? -> string?
;;   Render Ruby source for terminal preview.
(define (render-ruby-preview source)
  (apply string-append
         (for/list ([token (ruby-string->derived-tokens source)])
           (colorize-text (ruby-token-style token)
                          (ruby-derived-token-text token)))))

;; render-ruby-preview-port : input-port? output-port? -> void?
;;   Render Ruby source from a port for terminal preview.
(define (render-ruby-preview-port in
                                  [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-ruby-derived-lexer))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (ruby-token-style token)
                              (ruby-derived-token-text token))
               out)
      (loop))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define sample
    (string-append
     "#!/usr/bin/env ruby\n"
     "class Demo\n"
     "  def greet(name:, loud: false)\n"
     "    message = \"hello #{name}\"\n"
     "    loud ? message.upcase : message\n"
     "  end\n"
     "end\n"))

  (check-equal?
   (strip-ansi (render-ruby-preview sample))
   sample)

  (check-true
   (regexp-match? #px"\u001b\\[" (render-ruby-preview sample)))

  (check-equal?
   (let ([out (open-output-string)])
     (render-ruby-preview-port (open-input-string sample)
                               out)
     (strip-ansi (get-output-string out)))
   sample))
