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
;; preview-options-color?              -- Whether colored output is enabled.
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
 ;; preview-options-color?     Whether colored output is enabled.
 preview-options-color?
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
         "css.rkt")

(struct preview-options (type align? swatches? color?) #:transparent)

;; make-preview-options : -> preview-options?
;;   Construct default preview options.
(define (make-preview-options #:type      [type #f]
                              #:align?    [align? #f]
                              #:swatches? [swatches? #t]
                              #:color?    [color? #t])
  (preview-options type align? swatches? color?))

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
       [else                                      #f])]))

;; effective-file-type : (or/c path-string? #f) preview-options? -> (or/c symbol? #f)
;;   Resolve the selected file type from options and path.
(define (effective-file-type maybe-path options)
  (cond
    [(preview-options-type options) => values]
    [else                             (detect-file-type maybe-path)]))

;; preview-string : string? (or/c path-string? #f) preview-options? -> string?
;;   Preview a source string.
(define (preview-string source [maybe-path #f] [options (make-preview-options)])
  (define file-type
    (effective-file-type maybe-path options))
  (cond
    [(not (preview-options-color? options)) source]
    [(eq? file-type 'css)
     (render-css-preview source
                         #:align?    (preview-options-align? options)
                         #:swatches? (preview-options-swatches? options))]
    [else
     source]))

;; preview-file : path-string? preview-options? -> string?
;;   Preview a file from disk.
(define (preview-file path [options (make-preview-options)])
  (define source
    (file->string path))
  (preview-string source path options))
