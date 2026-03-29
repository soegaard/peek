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
;; make-preview-options                -- Construct preview options.
;; preview-string : string? ... -> string?
;;   Preview a source string using the selected options.
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
 ;; make-preview-options       Construct preview options.
 make-preview-options
 ;; preview-string : string? (or/c symbol? #f) preview-options? -> string?
 ;;   Preview a source string.
 preview-string
 ;; preview-file : path-string? preview-options? -> string?
 ;;   Preview a file from disk.
 preview-file)

(require racket/file
         racket/path
         racket/port
         "css.rkt"
         "js.rkt")

(struct preview-options (type align? swatches? color-mode) #:transparent)

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
       [(regexp-match? #px"(?i:\\.css)$" path-string)            'css]
       [(regexp-match? #px"(?i:\\.jsx)$" path-string)            'jsx]
       [(regexp-match? #px"(?i:\\.(?:js|mjs|cjs))$" path-string) 'js]
       [else                                                     #f])]))

;; effective-file-type : (or/c path-string? #f) preview-options? -> (or/c symbol? #f)
;;   Resolve the selected file type from options and path.
(define (effective-file-type maybe-path options)
  (cond
    [(preview-options-type options) => values]
    [else                             (detect-file-type maybe-path)]))

;; preview-string : string? (or/c path-string? #f) preview-options? -> string?
;;   Preview a source string.
(define (preview-string source
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
    [(eq? file-type 'js)
     (render-javascript-preview source)]
    [(eq? file-type 'jsx)
     (render-javascript-preview source
                                #:jsx? #t)]
    [else
     source]))

;; preview-file : path-string? preview-options? -> string?
;;   Preview a file from disk.
(define (preview-file path
                      [options (make-preview-options)]
                      [out (current-output-port)])
  (define source
    (file->string path))
  (preview-string source path options out))

(module+ test
  (require rackunit)

  (check-equal? (detect-file-type "theme.css") 'css)
  (check-equal? (detect-file-type "widget.js") 'js)
  (check-equal? (detect-file-type "widget.mjs") 'js)
  (check-equal? (detect-file-type "widget.cjs") 'js)
  (check-equal? (detect-file-type "widget.jsx") 'jsx)
  (check-false  (detect-file-type "README.txt"))
  (check-true
   (regexp-match? #px"\u001b\\["
                  (preview-string "const answer = 42;\n"
                                  "demo.js"
                                  (make-preview-options #:color-mode 'always))))
  (check-true
   (regexp-match? #px"Button"
                  (preview-string "const el = <Button>Hello</Button>;\n"
                                  "demo.jsx"
                                  (make-preview-options #:color-mode 'always)))))
