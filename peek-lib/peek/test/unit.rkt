#lang racket/base

(require rackunit
         racket/file
         racket/runtime-path
         racket/string
         "../css.rkt"
         "../html.rkt"
         "../js.rkt"
         "../main.rkt"
         "../markdown.rkt"
         "../preview.rkt"
         "../racket.rkt"
         "../scribble.rkt"
         "../wat.rkt")

(define-runtime-path demo-markdown-path
  "fixtures/demo.md")
(define-runtime-path demo-racket-path
  "fixtures/demo.rkt")
(define-runtime-path demo-scribble-path
  "fixtures/demo.scrbl")
(define-runtime-path demo-wat-path
  "fixtures/demo.wat")

(define ansi-pattern
  #px"\u001b\\[[0-9;]*m")

(define (strip-ansi text)
  (regexp-replace* ansi-pattern text ""))

(check-equal? supported-file-types
              '(css html js jsx md rkt scrbl wat))

(check-equal? (preview-string "color: #fff;" #f
                              (make-preview-options #:type 'css
                                                    #:color-mode 'never))
              "color: #fff;")
(check-true
 (regexp-match? #px"\u001b\\["
                (preview-string "color: #fff;" #f
                                (make-preview-options #:type 'css
                                                      #:color-mode 'always))))

(check-true
 (regexp-match? #px"doctype"
                (render-html-preview
                 "<!doctype html><main id=\"app\">Hi &amp; bye<style>.x { color: #fff; }</style><script>const answer = 42;</script><!-- note --></main>")))
(check-true
 (regexp-match? #px"answer"
                (render-javascript-preview "const answer = 42;\nobj.run(answer);\n")))
(check-true
 (regexp-match? #px"Button"
                (render-javascript-preview "const el = <Button kind=\"primary\">Hello {name}</Button>;\n"
                                           #:jsx? #t)))
(check-true
 (regexp-match? #px"Title"
                (render-markdown-preview "# Title\n\nText\n")))
(check-true
 (regexp-match? #px"#lang"
                (render-racket-preview "#lang racket/base\n(define x 1)\n")))
(check-true
 (regexp-match? #px"title"
                (render-scribble-preview "@title{Hi}\n")))
(check-true
 (regexp-match? #px"module"
                (render-wat-preview "(module (func (result i32) (i32.const 42)))\n")))

(check-true
 (regexp-match? #px"\u001b\\["
                (preview-string "const answer = 42;\n"
                                "demo.js"
                                (make-preview-options #:color-mode 'always))))
(check-true
 (let ([out (open-output-string)])
   (preview-port (open-input-string "#lang racket/base\n(define x 1)\n")
                 "program.rkt"
                 (make-preview-options #:color-mode 'always)
                 out)
   (regexp-match? #px"\u001b\\[" (get-output-string out))))

(check-equal?
 (let ([out (open-output-string)])
   (preview-port (open-input-string "<!doctype html><main id=\"app\">Hi</main>\n")
                 "index.html"
                 (make-preview-options #:color-mode 'always)
                 out)
   (strip-ansi (get-output-string out)))
 "<!doctype html><main id=\"app\">Hi</main>\n")

(check-true
 (regexp-match? #px"greet"
                (preview-file demo-racket-path
                              (make-preview-options #:color-mode 'always))))
(check-true
 (regexp-match? #px"Title"
                (preview-string "# Title\n\nText\n"
                                "README.md"
                                (make-preview-options #:color-mode 'always))))
(check-true
 (regexp-match? #px"Demo Document"
                (preview-file demo-markdown-path
                              (make-preview-options #:color-mode 'always))))
(check-true
 (regexp-match? #px"itemlist"
                (preview-file demo-scribble-path
                              (make-preview-options #:color-mode 'always))))
(check-true
 (regexp-match? #px"answer"
                (preview-file demo-wat-path
                              (make-preview-options #:color-mode 'always))))
