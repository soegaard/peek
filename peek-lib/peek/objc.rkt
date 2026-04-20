#lang racket/base

;;;
;;; Objective-C Preview
;;;
;;
;; Objective-C-specific terminal preview rendering built on `lexers/objc`.

;; render-objc-preview      : string? -> string?
;;   Render Objective-C source for terminal preview.
;; render-objc-preview-port : input-port? output-port? -> void?
;;   Render Objective-C source from a port for terminal preview.

(provide
 ;; render-objc-preview : string? -> string?
 ;;   Render Objective-C source for terminal preview.
 render-objc-preview
 ;; render-objc-preview-port : input-port? output-port? -> void?
 ;;   Render Objective-C source from a port for terminal preview.
 render-objc-preview-port)

(require lexers/objc
         racket/port
         racket/string
         "common-style.rkt")

;; objc-derived-token-category : objc-derived-token? -> symbol?
;;   Extract the coarse category from one derived Objective-C token.
(define (objc-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; objc-token-style : objc-derived-token? -> string?
;;   Choose the ANSI style for one derived Objective-C token.
(define (objc-token-style token)
  (objc-like-style (objc-derived-token-category token)
                   (objc-derived-token-tags token)))

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

;; render-objc-preview : string? -> string?
;;   Render Objective-C source for terminal preview.
(define (render-objc-preview source)
  (apply string-append
         (for/list ([token (objc-string->derived-tokens source)])
           (colorize-text (objc-token-style token)
                          (objc-derived-token-text token)))))

;; render-objc-preview-port : input-port? output-port? -> void?
;;   Render Objective-C source from a port for terminal preview.
(define (render-objc-preview-port in
                                  [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-objc-derived-lexer))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (objc-token-style token)
                              (objc-derived-token-text token))
               out)
      (loop))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define sample
    "#import <Foundation/Foundation.h>\n@interface Foo : NSObject\n@property NSString *name;\n@end\n")

  (check-equal?
   (strip-ansi (render-objc-preview sample))
   sample)

  (check-equal?
   (let ([out (open-output-string)])
     (render-objc-preview-port (open-input-string sample)
                               out)
     (strip-ansi (get-output-string out)))
   sample))
