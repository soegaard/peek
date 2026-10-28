#lang racket/base

;;;
;;; Assembly Preview Tests
;;;
;;
;; Focused rendering and source-safety tests for the shared generic assembly
;; lexer integration.

(require rackunit
         racket/string
         "../asm.rkt"
         "../common-style.rkt"
         "../private/assembly-options.rkt"
         "../preview.rkt")

;; ansi-pattern : regexp?
;; ANSI SGR sequences emitted by the preview palette.
(define ansi-pattern
  #px"\u001b\\[[0-9;]*m")

;; strip-ansi : string? -> string?
;;   Remove terminal styling for source-display assertions.
(define (strip-ansi text)
  (regexp-replace* ansi-pattern text ""))

;; source : string?
;; Generic source must preserve uncertain punctuation rather than calling it a comment.
(define source
  "entry:\nmov a, b ; generic punctuation\n")

(define options
  (make-preview-options #:type 'asm
                        #:color-mode 'always))

(check-equal? (strip-ansi (render-asm-preview source))
              source)
(check-equal? (render-asm-preview source #:color? #f)
              source)
(check-equal? (preview-string source
                              #f
                              (make-preview-options #:type 'asm
                                                    #:color-mode 'never))
              source)
(check-true (regexp-match? ansi-pattern
                           (render-asm-preview source)))

;; Explicit profiles provide semantic roles that the assembly renderer maps to
;; the shared palette; generic source keeps unclassified words conservative.
(define styled-source
  "entry:\nMOVE.W #1,D0\nDC.W $100\n; comment\n")

(define styled-output
  (render-asm-preview styled-source
                      #:assembly (make-assembly-options
                                  #:dialect 'native-motorola)))

(check-true (string-contains? styled-output
                              (string-append ansi-identifier "entry" ansi-reset)))
(check-true (string-contains? styled-output
                              (string-append ansi-delimiter ":" ansi-reset)))
(check-true (string-contains? styled-output
                              (string-append ansi-keyword "MOVE.W" ansi-reset)))
(check-true (string-contains? styled-output
                              (string-append ansi-literal "1" ansi-reset)))
(check-true (string-contains? styled-output
                              (string-append ansi-delimiter "," ansi-reset)))
(check-true (string-contains? styled-output
                              (string-append ansi-builtin "D0" ansi-reset)))
(check-true (string-contains? styled-output
                              (string-append ansi-keyword "DC.W" ansi-reset)))
(check-true (string-contains? styled-output
                              (string-append ansi-literal "$100" ansi-reset)))
(check-true (string-contains? styled-output
                              (string-append ansi-comment ";" ansi-reset)))

;; Invalid bytes, ESC, and lone CR are visibly escaped; CRLF is one output newline.
(define unsafe-output
  (let ([out (open-output-string)])
    (render-asm-preview-port (open-input-bytes #"a\303\033[31m\r\nb\r")
                             out
                             #:color? #f)
    (get-output-string out)))

(check-equal? unsafe-output
              "a\\xC3\\x1B[31m\nb\\x0D")

;; UTF-16 is decoded before a NUL check can route it to binary rendering.
(define utf-16-output
  (let ([out (open-output-string)])
    (preview-port (open-input-bytes #"\377\376l\0d\0a\0:\0\r\0\n\0")
                  #f
                  (make-preview-options #:type 'asm
                                        #:color-mode 'never)
                  out)
    (get-output-string out)))

(check-equal? utf-16-output "lda:\n")
