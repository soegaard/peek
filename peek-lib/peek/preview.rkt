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
         "json.rkt"
         "markdown.rkt"
         "racket.rkt"
         "rhombus.rkt"
         "shell.rkt"
         "scribble.rkt"
         "wat.rkt")

(struct preview-options (type align? swatches? color-mode) #:transparent)

;; Supported explicit file-type names.
(define supported-file-types
  '(bash css html js json jsx md powershell rhombus rkt scrbl wat zsh))

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
       [(regexp-match? #px"(?i:\\.(?:sh|bash))$" path-string) 'bash]
       [(regexp-match? #px"(?i:\\.jsx)$" path-string) 'jsx]
       [(regexp-match? #px"(?i:\\.(?:json|webmanifest))$" path-string)
        'json]
       [(regexp-match? #px"(?i:\\.md)$" path-string) 'md]
       [(regexp-match? #px"(?i:\\.ps1)$" path-string) 'powershell]
       [(regexp-match? #px"(?i:\\.rhm)$" path-string) 'rhombus]
       [(regexp-match? #px"(?i:\\.scrbl)$" path-string) 'scrbl]
       [(regexp-match? #px"(?i:\\.zsh)$" path-string) 'zsh]
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
    [(eq? file-type 'bash)
     (render-shell-preview source #:shell 'bash)]
    [(eq? file-type 'html)
     (render-html-preview source)]
    [(eq? file-type 'js)
     (render-javascript-preview source)]
    [(eq? file-type 'json)
     (render-json-preview source)]
    [(eq? file-type 'jsx)
     (render-javascript-preview source
                                #:jsx? #t)]
    [(eq? file-type 'md)
     (render-markdown-preview source)]
    [(eq? file-type 'powershell)
     (render-shell-preview source #:shell 'powershell)]
    [(eq? file-type 'rhombus)
     (render-rhombus-preview source)]
    [(eq? file-type 'rkt)
     (render-racket-preview source)]
    [(eq? file-type 'scrbl)
     (render-scribble-preview source)]
    [(eq? file-type 'zsh)
     (render-shell-preview source #:shell 'zsh)]
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
    [(and (or (eq? file-type 'bash)
              (eq? file-type 'powershell)
              (eq? file-type 'zsh))
          (color-enabled? out options))
     (case file-type
       [(bash)       (render-shell-preview-port in out #:shell 'bash)]
       [(powershell) (render-shell-preview-port in out #:shell 'powershell)]
       [(zsh)        (render-shell-preview-port in out #:shell 'zsh)])]
    [(or (eq? file-type 'bash)
         (eq? file-type 'powershell)
         (eq? file-type 'zsh))
     (copy-port in out)]
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
    [(and (eq? file-type 'rhombus)
          (color-enabled? out options))
     (render-rhombus-preview-port in out)]
    [(eq? file-type 'rhombus)
     (copy-port in out)]
    [(and (or (eq? file-type 'html)
              (eq? file-type 'js)
              (eq? file-type 'json)
              (eq? file-type 'jsx)
              (eq? file-type 'md)
              (eq? file-type 'scrbl))
          (color-enabled? out options))
     (case file-type
       [(html)  (render-html-preview-port in out)]
       [(js)    (render-javascript-preview-port in out)]
       [(json)  (render-json-preview-port in out)]
       [(jsx)   (render-javascript-preview-port in out #:jsx? #t)]
       [(md)    (render-markdown-preview-port in out)]
       [(scrbl) (render-scribble-preview-port in out)])]
    [(or (eq? file-type 'html)
         (eq? file-type 'js)
         (eq? file-type 'json)
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
         (eq? file-type 'bash)
         (eq? file-type 'powershell)
         (eq? file-type 'rhombus)
         (eq? file-type 'zsh)
         (eq? file-type 'rkt)
         (eq? file-type 'html)
         (eq? file-type 'js)
         (eq? file-type 'json)
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
