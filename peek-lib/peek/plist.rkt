#lang racket/base

;;;
;;; Plist Preview
;;;
;;
;; Property-list-specific terminal preview rendering built on `lexers/plist`.

;; render-plist-preview      : string? -> string?
;;   Render XML property-list source for terminal preview.
;; render-plist-preview-port : input-port? output-port? -> void?
;;   Render XML property-list source from a port for terminal preview.

(provide
 ;; render-plist-preview : string? -> string?
 ;;   Render XML property-list source for terminal preview.
 render-plist-preview
 ;; render-plist-preview-port : input-port? output-port? -> void?
 ;;   Render XML property-list source from a port for terminal preview.
 render-plist-preview-port)

(require lexers/plist
         racket/port
         "common-style.rkt")

;; plist-derived-token-category : plist-derived-token? -> symbol?
;;   Extract the coarse category from one derived plist token.
(define (plist-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; plist-token-style : plist-derived-token? -> string?
;;   Choose the ANSI style for one derived plist token.
(define (plist-token-style token)
  (plist-like-style (plist-derived-token-category token)
                    (plist-derived-token-tags token)))

;; render-plist-preview : string? -> string?
;;   Render XML property-list source for terminal preview.
(define (render-plist-preview source)
  (apply string-append
         (for/list ([token (plist-string->derived-tokens source)])
           (colorize-text (plist-token-style token)
                          (plist-derived-token-text token)))))

;; render-plist-preview-port : input-port? output-port? -> void?
;;   Render XML property-list source from a port for terminal preview.
(define (render-plist-preview-port in
                                   [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-plist-derived-lexer))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (plist-token-style token)
                              (plist-derived-token-text token))
               out)
      (loop))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define sample
    (string-append
     "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
     "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" "
     "\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
     "<plist version=\"1.0\">\n"
     "  <dict>\n"
     "    <key>Name</key>\n"
     "    <string>peek</string>\n"
     "    <key>Enabled</key>\n"
     "    <true/>\n"
     "  </dict>\n"
     "</plist>\n"))

  (check-equal?
   (strip-ansi (render-plist-preview sample))
   sample)

  (check-equal?
   (let ([out (open-output-string)])
     (render-plist-preview-port (open-input-string sample)
                                out)
     (strip-ansi (get-output-string out)))
   sample))
