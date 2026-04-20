#lang racket/base

;;;
;;; C++ Preview
;;;
;;
;; C++-specific terminal preview rendering built on `lexers/cpp`.

;; render-cpp-preview      : string? -> string?
;;   Render C++ source for terminal preview.
;; render-cpp-preview-port : input-port? output-port? -> void?
;;   Render C++ source from a port for terminal preview.

(provide
 ;; render-cpp-preview : string? -> string?
 ;;   Render C++ source for terminal preview.
 render-cpp-preview
 ;; render-cpp-preview-port : input-port? output-port? -> void?
 ;;   Render C++ source from a port for terminal preview.
 render-cpp-preview-port)

(require lexers/cpp
         racket/port
         racket/string
         "common-style.rkt")

;; cpp-derived-token-category : cpp-derived-token? -> symbol?
;;   Extract the coarse category from one derived C++ token.
(define (cpp-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; cpp-token-style : cpp-derived-token? -> string?
;;   Choose the ANSI style for one derived C++ token.
(define (cpp-token-style token)
  (cpp-like-style (cpp-derived-token-category token)
                  (cpp-derived-token-tags token)))

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

;; render-cpp-preview : string? -> string?
;;   Render C++ source for terminal preview.
(define (render-cpp-preview source)
  (apply string-append
         (for/list ([token (cpp-string->derived-tokens source)])
           (colorize-text (cpp-token-style token)
                          (cpp-derived-token-text token)))))

;; render-cpp-preview-port : input-port? output-port? -> void?
;;   Render C++ source from a port for terminal preview.
(define (render-cpp-preview-port in
                                 [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-cpp-derived-lexer))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (cpp-token-style token)
                              (cpp-derived-token-text token))
               out)
      (loop))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define sample
    "#include <vector>\n#define ANSWER 42\nstd::string s = R\"cpp(hi)cpp\";\n")

  (check-equal?
   (strip-ansi (render-cpp-preview sample))
   sample)

  (check-equal?
   (let ([out (open-output-string)])
     (render-cpp-preview-port (open-input-string sample)
                              out)
     (strip-ansi (get-output-string out)))
   sample))
