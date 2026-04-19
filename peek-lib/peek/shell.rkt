#lang racket/base

;;;
;;; Shell Preview
;;;
;;
;; Shell-specific terminal preview rendering built on `lexers/shell`.

;; render-shell-preview      : string? #:shell symbol? -> string?
;;   Render shell source for terminal preview.
;; render-shell-preview-port : input-port? output-port? #:shell symbol? -> void?
;;   Render shell source from a port for terminal preview.

(provide
 ;; render-shell-preview : string? #:shell symbol? -> string?
 ;;   Render Bash, Zsh, or PowerShell for terminal preview.
 render-shell-preview
 ;; render-shell-preview-port : input-port? output-port? #:shell symbol? -> void?
 ;;   Render Bash, Zsh, or PowerShell from a port for terminal preview.
 render-shell-preview-port)

(require lexers/shell
         lexers/token
         parser-tools/lex
         "common-style.rkt")

;; shell-derived-token-category : shell-derived-token? -> symbol?
;;   Extract the coarse shell token category from one derived token.
(define (shell-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; shell-token-style : shell-derived-token? -> string?
;;   Choose the ANSI style for one derived shell token.
(define (shell-token-style token)
  (shell-like-style (shell-derived-token-category token)
                    (shell-derived-token-tags token)))

;; render-shell-preview : string? #:shell symbol? -> string?
;;   Render shell source for terminal preview.
(define (render-shell-preview source
                              #:shell [shell 'bash])
  (apply string-append
         (for/list ([token (shell-string->derived-tokens source
                                                         #:shell shell)])
           (colorize-text (shell-token-style token)
                          (shell-derived-token-text token)))))

;; render-shell-preview-port : input-port? output-port? #:shell symbol? -> void?
;;   Render shell source from a port for terminal preview.
(define (render-shell-preview-port in
                                   [out (current-output-port)]
                                   #:shell [shell 'bash])
  (port-count-lines! in)
  (define lexer
    (make-shell-derived-lexer #:shell shell))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (shell-token-style token)
                              (shell-derived-token-text token))
               out)
      (loop))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (check-equal?
   (strip-ansi
    (render-shell-preview "export PATH\n# note\n"
                          #:shell 'bash))
   "export PATH\n# note\n")

  (check-equal?
   (let ([out (open-output-string)])
     (render-shell-preview-port (open-input-string "$name = \"world\"\n")
                                out
                                #:shell 'powershell)
     (strip-ansi (get-output-string out)))
   "$name = \"world\"\n"))
