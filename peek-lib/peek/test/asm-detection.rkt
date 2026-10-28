#lang racket/base

;;;
;;; Assembly Detection Tests
;;;
;;
;; Test bounded, inspectable automatic selection and its calibration gate.

(require json
         rackunit
         "../asm.rkt"
         (only-in "../preview.rkt"
                  make-preview-options
                  preview-port
                  preview-string)
         "../private/assembly-options.rkt"
         "../private/input-probe.rkt")

(define utf-16-probe
  (probe-input-port (open-input-bytes #"\377\376l\0d\0a\0")
                    #:availability-timeout-ms 0))
(define detection
  (assembly-detection-jsexpr utf-16-probe
                             #:path "startup.S"
                             #:assembly (make-assembly-options #:dialect #f)))

(check-equal? (hash-ref detection 'schema_version) 2)
(check-equal? (hash-ref detection 'encoding) "utf-16le")
(check-equal? (hash-ref detection 'artifact_kind) "source")
(check-equal? (hash-ref detection 'path_hint) ".S")
(check-equal? (hash-ref (hash-ref detection 'selection) 'effective) #f)
(check-equal? (hash-ref (hash-ref detection 'resolved_selection) 'dialect)
              "generic")
(check-equal? (hash-ref (hash-ref detection 'automatic) 'band)
              "unknown")

;; Strong source evidence may admit the assembly family, but only a lexer
;; calibration record can select its exact profile for preview.
(define ca65-source
  #".setcpu \"6502\"\n.feature at_in_identifiers\n")
(define ca65-resolution
  (resolve-assembly-options ca65-source
                            (make-assembly-options #:dialect #f)
                            #:automatic? #t))

(check-true (assembly-probe-plausibly-source? ca65-resolution))
(check-equal? (assembly-resolution-origin ca65-resolution)
              'generic-fallback)
(check-equal? (assembly-options-dialect
               (assembly-resolution-options ca65-resolution))
              'generic)

;; An ambiguous include switches to generic assembly only with strong assembly
;; evidence; ordinary Pascal includes retain the existing Pascal preview path.
(define preview-options
  (make-preview-options #:color-mode 'always))
(define assembly-include-preview
  (preview-string (bytes->string/utf-8 ca65-source)
                  "startup.inc"
                  preview-options))
(define generic-assembly-preview
  (preview-string (bytes->string/utf-8 ca65-source)
                  "startup.inc"
                  (make-preview-options #:type 'asm #:color-mode 'always)))
(define pascal-include-source
  "const Answer = 42;\n")
(define automatic-pascal-preview
  (preview-string pascal-include-source "constants.inc" preview-options))
(define explicit-pascal-preview
  (preview-string pascal-include-source
                  "constants.inc"
                  (make-preview-options #:type 'pascal #:color-mode 'always)))
(define assembly-include-port-preview
  (let ([out (open-output-string)])
    (preview-port (open-input-bytes ca65-source)
                  "startup.inc"
                  preview-options
                  out)
    (get-output-string out)))
(define pascal-include-port-preview
  (let ([out (open-output-string)])
    (preview-port (open-input-bytes (string->bytes/utf-8 pascal-include-source))
                  "constants.inc"
                  preview-options
                  out)
    (get-output-string out)))

(check-equal? assembly-include-preview generic-assembly-preview)
(check-equal? automatic-pascal-preview explicit-pascal-preview)
(check-equal? assembly-include-port-preview generic-assembly-preview)
(check-equal? pascal-include-port-preview explicit-pascal-preview)

(define explanation
  (let ([out (open-output-string)])
    (write-assembly-explanation utf-16-probe
                                out
                                #:path "startup.S"
                                #:assembly (make-assembly-options #:dialect 'generic))
    (get-output-string out)))

(check-true (regexp-match? #px"requested generic" explanation))
(check-true (regexp-match? #px"encoding utf-16le" explanation))

;; The JSON representation is a normal one-record payload with no terminal ANSI.
(define json-output
  (let ([out (open-output-string)])
    (write-json detection out)
    (get-output-string out)))

(check-false (regexp-match? #px"\u001b" json-output))
