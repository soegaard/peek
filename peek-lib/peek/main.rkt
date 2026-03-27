#lang racket/base

;;;
;;; Main
;;;
;;
;; Command-line entry point for peek.

;; main : -> void?
;;   Run the peek command-line interface.

(provide
 ;; main : -> void?
 ;;   Run the peek command-line interface.
 main)

(require racket/cmdline
         racket/port
         "preview.rkt")

;; usage-error : string? -> nothing
;;   Print a command-line error and exit.
(define (usage-error message)
  (eprintf "peek: ~a\n" message)
  (exit 1))

;; main : -> void?
;;   Run the peek command-line interface.
(define (main)
  (define align? #f)
  (define swatches? #t)
  (define color-mode 'always)
  (define type #f)
  (define file-path #f)
  (command-line
   #:program "peek"
   #:once-each
   [("--type") value
               "Explicit file type for stdin input."
               (set! type (string->symbol value))]
   [("--align")
    "Enable CSS intra-rule alignment."
    (set! align? #t)]
   [("--no-swatches")
    "Disable CSS swatches."
    (set! swatches? #f)]
   [("--color") value
                "Choose color mode: always, auto, or never."
                (set! color-mode
                      (case (string->symbol value)
                        [(always auto never) (string->symbol value)]
                        [else
                         (usage-error (format "unknown color mode: ~a" value))]))]
   #:args args
   (cond
     [(null? args)
      (void)]
     [(null? (cdr args))
      (set! file-path (car args))]
     [else
      (usage-error "expected at most one input file")]))
  (define options
    (make-preview-options #:type      type
                          #:align?    align?
                          #:swatches? swatches?
                          #:color-mode color-mode))
  (cond
    [file-path
     (unless (file-exists? file-path)
       (usage-error (format "file not found: ~a" file-path)))
     (display (preview-file file-path options (current-output-port)))]
    [else
     (define source
       (port->string (current-input-port)))
     (display (preview-string source #f options (current-output-port)))]))

(module+ main
  (main))

(module+ test
  (require rackunit)

  (define plain-options
    (make-preview-options #:type 'css
                          #:color-mode 'never))

  (check-equal? (preview-string "color: #fff;" #f plain-options)
                "color: #fff;")
  (check-true
   (regexp-match? #px"\u001b\\["
                  (preview-string "color: #fff;"
                                  #f
                                  (make-preview-options #:type 'css
                                                        #:color-mode 'always))))
  (check-equal?
   (preview-string "color: #fff;"
                   #f
                   (make-preview-options #:type 'css
                                         #:color-mode 'auto)
                   (open-output-string))
   "color: #fff;"))
