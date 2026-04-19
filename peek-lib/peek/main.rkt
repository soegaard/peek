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
         racket/list
         racket/string
         racket/system
         racket/port
         "preview.rkt")

;; usage-error : string? -> nothing
;;   Print a command-line error and exit.
(define (usage-error message)
  (eprintf "peek: ~a\n" message)
  (exit 1))

;; pager-command : -> (listof path-string?)
;;   Resolve the configured pager command.
(define (pager-command)
  (cond
    [(getenv "PAGER")
     =>
     (lambda (pager)
       (define pieces
         (filter (lambda (piece)
                   (not (string=? piece "")))
                 (string-split pager)))
       (cond
         [(null? pieces)
          (pager-command/fallback)]
         [else
          (define executable
            (or (find-executable-path (car pieces))
                (error 'peek (format "could not find pager executable: ~a"
                                     (car pieces)))))
          (cons executable (cdr pieces))]))]
    [else
     (pager-command/fallback)]))

;; pager-command/fallback : -> (listof path-string?)
;;   Resolve the default pager command.
(define (pager-command/fallback)
  (define less-path
    (find-executable-path "less"))
  (cond
    [less-path (list less-path "-R")]
    [else
     (error 'peek
            "could not find a pager; set PAGER or install `less`")]))

;; call-with-pager-output : (output-port? -> any/c) -> void?
;;   Run a writer with the configured pager's stdin as output.
(define (call-with-pager-output writer)
  (define command
    (pager-command))
  (define-values (pager-pid pager-out pager-in pager-err)
    (apply subprocess
           (current-output-port)
           #f
           (current-error-port)
           command))
  (writer pager-in)
  (close-output-port pager-in)
  (subprocess-wait pager-pid))

;; print-supported-file-types : -> void?
;;   Print supported explicit file-type names, one per line.
(define (print-supported-file-types)
  (for ([file-type (in-list supported-file-types)])
    (displayln file-type)))

;; main : -> void?
;;   Run the peek command-line interface.
(define (main)
  (define align? #f)
  (define swatches? #t)
  (define color-mode 'always)
  (define pager? #f)
  (define list-file-types? #f)
  (define type #f)
  (define file-path #f)
  (command-line
   #:program "peek"
   #:once-each
   [("--type") value
               "Explicit file type for stdin input."
               (set! type (string->symbol value))]
   [("--list-file-types")
    "Print supported file type names and exit."
    (set! list-file-types? #t)]
   [("-a" "--align")
    "Enable CSS intra-rule alignment."
    (set! align? #t)]
   [("--no-swatches")
    "Disable CSS swatches."
    (set! swatches? #f)]
   [("-p" "--pager")
    "Pipe output through $PAGER or less -R."
    (set! pager? #t)]
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
  (cond
    [list-file-types?
     (print-supported-file-types)]
    [else
     (when file-path
       (unless (file-exists? file-path)
         (usage-error (format "file not found: ~a" file-path))))
     (define options
       (make-preview-options #:type      type
                             #:align?    align?
                             #:swatches? swatches?
                             #:color-mode color-mode))
     (define (write-preview out)
       (cond
         [file-path
          (call-with-input-file file-path
            (lambda (in)
              (preview-port in file-path options out)))]
         [else
          (preview-port (current-input-port) #f options out)]))
     (cond
       [pager?
        (call-with-pager-output write-preview)]
       [else
        (write-preview (current-output-port))])]))

(module+ main
  (main))
