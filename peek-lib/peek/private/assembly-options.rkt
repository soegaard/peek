#lang racket/base

;;;
;;; Assembly Preview Options
;;;

;; Immutable, per-preview settings for the shared assembly lexer.  This module
;; deliberately records only dimensions with an implemented meaning in peek.

;; assembly-options?                  : any/c -> boolean?
;;   Recognize assembly preview configuration.
;; assembly-options-dialect           : assembly-options? -> (or/c symbol? #f)
;;   Extract the requested lexer dialect.
;; assembly-options-architecture      : assembly-options? -> (or/c symbol? #f)
;;   Extract the requested target architecture.
;; assembly-options-encoding          : assembly-options? -> symbol?
;;   Extract the requested source encoding.
;; assembly-options-detection-mode    : assembly-options? -> symbol?
;;   Extract the bounded automatic-detection sampling schedule.
;; make-assembly-options              : keyword-arguments -> assembly-options?
;;   Construct validated assembly preview configuration.

(provide (struct-out assembly-options)
         make-assembly-options)

;; Settings that affect assembly parsing or bounded automatic selection, not
;; terminal presentation.
(struct assembly-options (dialect architecture encoding detection-mode) #:transparent)

;; supported-assembly-encodings : (listof symbol?)
;; Source encodings implemented by `lexers/asm`.
(define supported-assembly-encodings
  '(auto utf-8 utf-16le utf-16be))

;; supported-assembly-detection-modes : (listof symbol?)
;; Automatic-selection sampling schedules implemented by `peek`.
(define supported-assembly-detection-modes
  '(interactive fixed-prefix))

;; make-assembly-options : [#:dialect (or/c symbol? #f)] [#:architecture (or/c symbol? #f)] [#:encoding symbol?] [#:detection-mode symbol?] -> assembly-options?
;;   Construct settings that can be passed unchanged through preview entry points.
(define (make-assembly-options #:dialect  [dialect 'generic]
                               #:architecture [architecture #f]
                               #:encoding [encoding 'auto]
                               #:detection-mode [detection-mode 'interactive])
  (unless (or (not dialect)
              (symbol? dialect))
    (raise-argument-error 'make-assembly-options "(or/c symbol? #f)" dialect))
  (unless (or (not architecture)
              (symbol? architecture))
    (raise-argument-error 'make-assembly-options
                          "(or/c symbol? #f)"
                          architecture))
  (unless (memq encoding supported-assembly-encodings)
    (raise-argument-error 'make-assembly-options
                          "(or/c 'auto 'utf-8 'utf-16le 'utf-16be)"
                          encoding))
  (unless (memq detection-mode supported-assembly-detection-modes)
    (raise-argument-error 'make-assembly-options
                          "(or/c 'interactive 'fixed-prefix)"
                          detection-mode))
  (assembly-options dialect architecture encoding detection-mode))

(module+ test
  (require rackunit)

  (check-equal? (assembly-options-dialect (make-assembly-options))
                'generic)
  (check-equal? (assembly-options-architecture
                 (make-assembly-options #:architecture 'x86))
                'x86)
  (check-equal? (assembly-options-detection-mode
                 (make-assembly-options #:detection-mode 'fixed-prefix))
                'fixed-prefix)
  (check-equal? (assembly-options-encoding
                 (make-assembly-options #:encoding 'utf-16le))
                'utf-16le)
  (check-exn exn:fail:contract?
             (lambda ()
               (make-assembly-options #:encoding 'latin-1))))
