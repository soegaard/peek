#lang racket/base

;; Generate a bundled map of standard #lang racket forms and builtin bindings.
;; This follows the same namespace-inspection idea as:
;; https://github.com/soegaard/racket-highlight-for-github

(require racket/cmdline
         racket/list
         racket/match
         racket/port
         racket/pretty
         racket/string)

(define output-path
  (make-parameter #f))

(command-line
 #:program "racket-map-build.rkt"
 #:once-each
 [("--out") path
  "Write generated entries to path"
  (output-path path)])

(define missing (gensym 'missing))

(define (syntax-identifier? str)
  (define sym (string->symbol str))
  (eq? (namespace-variable-value sym #t (lambda () missing)) missing))

(define racket-namespace
  (parameterize ([current-namespace (make-base-namespace)])
    (namespace-require 'racket)
    (current-namespace)))

(define bound-identifiers
  (parameterize ([current-namespace racket-namespace])
    (sort (remove-duplicates (map symbol->string (namespace-mapped-symbols)))
          string<?)))

(define-values (forms builtins)
  (parameterize ([current-namespace racket-namespace])
    (partition syntax-identifier? bound-identifiers)))

(define entries
  (append (for/list ([s (in-list forms)])
            (list 'form s))
          (for/list ([s (in-list builtins)])
            (list 'builtin s))))

(define (entry? v)
  (match v
    [(list kind token)
     (and (memq kind '(form builtin))
          (string? token)
          (not (string=? "" (string-trim token))))]
    [_ #f]))

(unless (and (list? entries) (andmap entry? entries))
  (raise-arguments-error 'racket-map-build
                         "invalid generated entries"
                         "entries" entries))

(module+ main
  (if (output-path)
      (call-with-output-file (output-path)
        (lambda (out) (pretty-write entries out))
        #:exists 'truncate/replace)
      (pretty-write entries)))

(module+ test
  (require rackunit)
  (check-true (pair? entries))
  (check-true (andmap entry? entries))
  (check-not-false (member (list 'form "define") entries))
  (check-not-false (member (list 'form "lambda") entries))
  (check-not-false (member (list 'builtin "string-length") entries))
  (check-not-false (member (list 'builtin "hash-update") entries)))
