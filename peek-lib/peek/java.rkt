#lang racket/base

;;;
;;; Java Preview
;;;
;;
;; Java-specific terminal preview rendering built on `lexers/java`.

;; render-java-preview      : string? -> string?
;;   Render Java source for terminal preview.
;; render-java-preview-port : input-port? output-port? -> void?
;;   Render Java source from a port for terminal preview.

(provide
 ;; render-java-preview : string? -> string?
 ;;   Render Java source for terminal preview.
 render-java-preview
 ;; render-java-preview-port : input-port? output-port? -> void?
 ;;   Render Java source from a port for terminal preview.
 render-java-preview-port)

(require lexers/java
         racket/port
         racket/string
         "common-style.rkt")

;; java-derived-token-category : java-derived-token? -> symbol?
;;   Extract the coarse category from one derived Java token.
(define (java-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; java-token-style : java-derived-token? -> string?
;;   Choose the ANSI style for one derived Java token.
(define (java-token-style token)
  (java-like-style (java-derived-token-category token)
                   (java-derived-token-tags token)))

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

;; render-java-preview : string? -> string?
;;   Render Java source for terminal preview.
(define (render-java-preview source)
  (apply string-append
         (for/list ([token (java-string->derived-tokens source)])
           (colorize-text (java-token-style token)
                          (java-derived-token-text token)))))

;; render-java-preview-port : input-port? output-port? -> void?
;;   Render Java source from a port for terminal preview.
(define (render-java-preview-port in
                                  [out (current-output-port)])
  (port-count-lines! in)
  (define lexer
    (make-java-derived-lexer))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (java-token-style token)
                              (java-derived-token-text token))
               out)
      (loop))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define sample
    (string-append
     "package demo;\n"
     "\n"
     "import java.util.List;\n"
     "\n"
     "/** docs */\n"
     "@Deprecated\n"
     "public class Example {\n"
     "  public static void main(String[] args) {\n"
     "    boolean ok = true;\n"
     "    Object nothing = null;\n"
     "    String text = \"\"\"\n"
     "hello\n"
     "\"\"\";\n"
     "    char c = 'x';\n"
     "    int n = 42;\n"
     "  }\n"
     "}\n"))

  (check-equal?
   (strip-ansi (render-java-preview sample))
   sample)

  (check-true
   (regexp-match? #px"\u001b\\["
                  (render-java-preview sample)))

  (check-equal?
   (let ([out (open-output-string)])
     (render-java-preview-port (open-input-string sample)
                               out)
     (strip-ansi (get-output-string out)))
   sample))
