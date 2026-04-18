#lang racket/base

;;;
;;; Preview
;;;
;;
;; Generic preview dispatch for files and strings.

;; preview-options                     -- Rendering options.
;; preview-options?                    -- Recognize preview options.
;; preview-options-type                -- Explicit file-type override.
;; preview-options-align?              -- Whether alignment is enabled.
;; preview-options-swatches?           -- Whether swatches are enabled.
;; preview-options-color-mode          -- Color mode selection.
;; supported-file-types                -- Supported explicit file type names.
;; make-preview-options                -- Construct preview options.
;; preview-string : string? ... -> string?
;;   Preview a source string using the selected options.
;; preview-port : input-port? ... -> void?
;;   Preview from an input port to an output port.
;; preview-file : path-string? ... -> string?
;;   Preview a file using the selected options.

(provide
 ;; preview-options            Shared preview configuration.
 preview-options
 ;; preview-options?           Recognize preview configuration values.
 preview-options?
 ;; preview-options-type       Explicit file-type override.
 preview-options-type
 ;; preview-options-align?     Whether alignment is enabled.
 preview-options-align?
 ;; preview-options-swatches?  Whether swatches are enabled.
 preview-options-swatches?
 ;; preview-options-color-mode Color mode selection.
 preview-options-color-mode
 ;; supported-file-types       Supported explicit file type names.
 supported-file-types
 ;; make-preview-options       Construct preview options.
 make-preview-options
 ;; preview-string : string? (or/c symbol? #f) preview-options? -> string?
 ;;   Preview a source string.
 preview-string
 ;; preview-port : input-port? (or/c path-string? #f) preview-options? output-port? -> void?
 ;;   Preview from an input port to an output port.
 preview-port
 ;; preview-file : path-string? preview-options? -> string?
 ;;   Preview a file from disk.
 preview-file)

(require racket/file
         racket/path
         racket/port
         "css.rkt"
         "html.rkt"
         "js.rkt"
         "markdown.rkt"
         "racket.rkt"
         "scribble.rkt"
         "wat.rkt")

(struct preview-options (type align? swatches? color-mode) #:transparent)

;; Supported explicit file-type names.
(define supported-file-types
  '(css html js jsx md rkt scrbl wat))

;; make-preview-options : -> preview-options?
;;   Construct default preview options.
(define (make-preview-options #:type      [type #f]
                              #:align?    [align? #f]
                              #:swatches? [swatches? #t]
                              #:color-mode [color-mode 'always])
  (preview-options type align? swatches? color-mode))

;; color-enabled? : output-port? preview-options? -> boolean?
;;   Determine whether preview output should include ANSI color.
(define (color-enabled? out options)
  (case (preview-options-color-mode options)
    [(always) #t]
    [(never)  #f]
    [(auto)   (terminal-port? out)]
    [else     #t]))

;; detect-file-type : (or/c path-string? #f) -> (or/c symbol? #f)
;;   Infer a supported file type from a file path.
(define (detect-file-type maybe-path)
  (cond
    [(not maybe-path) #f]
    [else
     (define path-string
       (path->string (simple-form-path maybe-path)))
     (cond
       [(regexp-match? #px"(?i:\\.css)$" path-string) 'css]
       [(regexp-match? #px"(?i:\\.html?)$" path-string) 'html]
       [(regexp-match? #px"(?i:\\.jsx)$" path-string) 'jsx]
       [(regexp-match? #px"(?i:\\.md)$" path-string) 'md]
       [(regexp-match? #px"(?i:\\.scrbl)$" path-string) 'scrbl]
       [(regexp-match? #px"(?i:\\.wat)$" path-string) 'wat]
       [(regexp-match? #px"(?i:\\.(?:js|mjs|cjs))$" path-string)
        'js]
       [(regexp-match? #px"(?i:\\.(?:rkt|ss|scm|rktd))$" path-string)
        'rkt]
       [else
        #f])]))

;; effective-file-type : (or/c path-string? #f) preview-options? -> (or/c symbol? #f)
;;   Resolve the selected file type from options and path.
(define (effective-file-type maybe-path options)
  (cond
    [(preview-options-type options) => values]
    [else                             (detect-file-type maybe-path)]))

;; preview-string/rendered : string? (or/c path-string? #f) preview-options? output-port? -> string?
;;   Preview a source string and return the rendered result.
(define (preview-string/rendered source
                                 [maybe-path #f]
                                 [options (make-preview-options)]
                                 [out (current-output-port)])
  (define file-type
    (effective-file-type maybe-path options))
  (cond
    [(not (color-enabled? out options)) source]
    [(eq? file-type 'css)
     (render-css-preview source
                         #:align?    (preview-options-align? options)
                         #:swatches? (preview-options-swatches? options))]
    [(eq? file-type 'html)
     (render-html-preview source)]
    [(eq? file-type 'js)
     (render-javascript-preview source)]
    [(eq? file-type 'jsx)
     (render-javascript-preview source
                                #:jsx? #t)]
    [(eq? file-type 'md)
     (render-markdown-preview source)]
    [(eq? file-type 'rkt)
     (render-racket-preview source)]
    [(eq? file-type 'scrbl)
     (render-scribble-preview source)]
    [(eq? file-type 'wat)
     (render-wat-preview source)]
    [else
     source]))

;; preview-string : string? (or/c path-string? #f) preview-options? -> string?
;;   Preview a source string.
(define (preview-string source
                        [maybe-path #f]
                        [options (make-preview-options)]
                        [out (current-output-port)])
  (preview-string/rendered source maybe-path options out))

;; preview-port : input-port? (or/c path-string? #f) preview-options? output-port? -> void?
;;   Preview from an input port to an output port.
(define (preview-port in
                      [maybe-path #f]
                      [options (make-preview-options)]
                      [out (current-output-port)])
  (define file-type
    (effective-file-type maybe-path options))
  (cond
    [(and (eq? file-type 'wat)
          (color-enabled? out options))
     (render-wat-preview-port in out)]
    [(eq? file-type 'wat)
     (copy-port in out)]
    [(and (eq? file-type 'rkt)
          (color-enabled? out options))
     (render-racket-preview-port in out)]
    [(eq? file-type 'rkt)
     (copy-port in out)]
    [(and (or (eq? file-type 'html)
              (eq? file-type 'js)
              (eq? file-type 'jsx)
              (eq? file-type 'md)
              (eq? file-type 'scrbl))
          (color-enabled? out options))
     (case file-type
       [(html)  (render-html-preview-port in out)]
       [(js)    (render-javascript-preview-port in out)]
       [(jsx)   (render-javascript-preview-port in out #:jsx? #t)]
       [(md)    (render-markdown-preview-port in out)]
       [(scrbl) (render-scribble-preview-port in out)])]
    [(or (eq? file-type 'html)
         (eq? file-type 'js)
         (eq? file-type 'jsx)
         (eq? file-type 'md)
         (eq? file-type 'scrbl))
     (copy-port in out)]
    [else
     (define source
       (port->string in))
     (display (preview-string/rendered source maybe-path options out)
              out)]))

;; preview-file : path-string? preview-options? -> string?
;;   Preview a file from disk.
(define (preview-file path
                      [options (make-preview-options)]
                      [out (current-output-port)])
  (define file-type
    (effective-file-type path options))
  (cond
    [(or (eq? file-type 'wat)
         (eq? file-type 'rkt)
         (eq? file-type 'html)
         (eq? file-type 'js)
         (eq? file-type 'jsx)
         (eq? file-type 'md)
         (eq? file-type 'scrbl))
     (define rendered
       (open-output-string))
     (call-with-input-file path
       (lambda (in)
         (preview-port in path options rendered)))
     (get-output-string rendered)]
    [else
     (define source
       (file->string path))
     (preview-string/rendered source path options out)]))

(module+ test
  (require rackunit
           racket/runtime-path
           racket/string)

  (define-runtime-path demo-markdown-path
    "../../test/fixtures/demo.md")
  (define-runtime-path demo-racket-path
    "../../test/fixtures/demo.rkt")
  (define-runtime-path demo-scribble-path
    "../../test/fixtures/demo.scrbl")
  (define-runtime-path demo-wat-path
    "../../test/fixtures/demo.wat")

  (define ansi-pattern
    #px"\u001b\\[[0-9;]*m")

  (define (strip-ansi text)
    (regexp-replace* ansi-pattern text ""))

  (check-equal? (detect-file-type "theme.css") 'css)
  (check-equal? (detect-file-type "index.html") 'html)
  (check-equal? (detect-file-type "index.htm") 'html)
  (check-equal? (detect-file-type "widget.js") 'js)
  (check-equal? (detect-file-type "widget.mjs") 'js)
  (check-equal? (detect-file-type "widget.cjs") 'js)
  (check-equal? (detect-file-type "widget.jsx") 'jsx)
  (check-equal? (detect-file-type "README.md") 'md)
  (check-equal? (detect-file-type "manual.scrbl") 'scrbl)
  (check-equal? (detect-file-type "demo.wat") 'wat)
  (check-equal? (detect-file-type "program.rkt") 'rkt)
  (check-equal? (detect-file-type "program.ss") 'rkt)
  (check-equal? (detect-file-type "program.scm") 'rkt)
  (check-equal? (detect-file-type "data.rktd") 'rkt)
  (check-false  (detect-file-type "README.txt"))
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
   (regexp-match? #px"Button"
                  (preview-string "const el = <Button>Hello</Button>;\n"
                                  "demo.jsx"
                                  (make-preview-options #:color-mode 'always))))
  (check-true
   (regexp-match? #px"Title"
                  (preview-string "# Title\n\nText\n"
                                  "README.md"
                                  (make-preview-options #:color-mode 'always))))
  (check-true
   (regexp-match? #px"doctype"
                  (preview-string "<!doctype html><main id=\"app\">Hi</main>\n"
                                  "index.html"
                                  (make-preview-options #:color-mode 'always))))
  (check-true
   (regexp-match? #px"#lang"
                  (preview-string "#lang racket/base\n(define x 1)\n"
                                  "program.rkt"
                                  (make-preview-options #:color-mode 'always))))
  (check-true
   (regexp-match? #px"module"
                  (preview-string "(module (func (result i32) (i32.const 42)))\n"
                                  "demo.wat"
                                  (make-preview-options #:color-mode 'always))))
  (check-true
   (let ([out (open-output-string)])
     (preview-port (open-input-string "(module (func (result i32) (i32.const 42)))\n")
                   "demo.wat"
                   (make-preview-options #:color-mode 'always)
                   out)
     (regexp-match? #px"\u001b\\[" (get-output-string out))))
  (check-equal?
   (let ([out (open-output-string)])
     (preview-port (open-input-string "(module (func))\n")
                   "demo.wat"
                   (make-preview-options #:color-mode 'never)
                   out)
     (get-output-string out))
   "(module (func))\n")
  (check-equal?
   (let ([out (open-output-string)])
     (preview-port (open-input-string "#lang at-exp racket/base\n@title{Hi}\n(define x 1)\n")
                   "program.rkt"
                   (make-preview-options #:color-mode 'always)
                   out)
     (strip-ansi (get-output-string out)))
   "#lang at-exp racket/base\n@title{Hi}\n(define x 1)\n")
  (check-equal?
   (let ([out (open-output-string)])
     (preview-port (open-input-string "const answer = 42;\n")
                   "demo.js"
                   (make-preview-options #:color-mode 'always)
                   out)
     (strip-ansi (get-output-string out)))
   "const answer = 42;\n")
  (check-equal?
   (let ([out (open-output-string)])
     (preview-port (open-input-string "# Title\n\nText\n")
                   "README.md"
                   (make-preview-options #:color-mode 'always)
                   out)
     (strip-ansi (get-output-string out)))
   "# Title\n\nText\n")
  (check-equal?
   (let ([out (open-output-string)])
     (preview-port (open-input-string "```sh\r\nx\r\n```\r\n")
                   "README.md"
                   (make-preview-options #:color-mode 'always)
                   out)
     (strip-ansi (get-output-string out)))
   "```sh\r\nx\r\n```\r\n")
  (check-true
   (regexp-match? #px"greet"
                  (preview-file demo-racket-path
                                (make-preview-options #:color-mode 'always))))
  (check-equal?
   (let ([out (open-output-string)])
     (preview-port (open-input-string "#lang racket/base\n(define x 1)\n")
                   "program.rkt"
                   (make-preview-options #:color-mode 'never)
                   out)
     (get-output-string out))
   "#lang racket/base\n(define x 1)\n")
  (check-true
   (regexp-match? #px"Demo Document"
                  (preview-file demo-markdown-path
                                (make-preview-options #:color-mode 'always))))
  (check-true
   (regexp-match? #px"title"
                  (preview-string "@title{Hi}\n"
                                  "manual.scrbl"
                                  (make-preview-options #:color-mode 'always))))
  (check-equal?
   (let ([out (open-output-string)])
     (preview-port (open-input-string "#lang scribble/manual\n@title{Hi}\n")
                   "manual.scrbl"
                   (make-preview-options #:color-mode 'always)
                   out)
     (strip-ansi (get-output-string out)))
   "#lang scribble/manual\n@title{Hi}\n")
  (check-true
   (regexp-match? #px"itemlist"
                  (preview-file demo-scribble-path
                                (make-preview-options #:color-mode 'always))))
  (check-true
   (regexp-match? #px"answer"
                  (preview-file demo-wat-path
                                (make-preview-options #:color-mode 'always)))))
