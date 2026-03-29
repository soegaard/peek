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

;; write-through-pager : string? -> void?
;;   Send rendered output through the configured pager.
(define (write-through-pager text)
  (define command
    (pager-command))
  (define-values (pager-pid pager-out pager-in pager-err)
    (apply subprocess
           (current-output-port)
           #f
           (current-error-port)
           command))
  (display text pager-in)
  (close-output-port pager-in)
  (subprocess-wait pager-pid))

;; main : -> void?
;;   Run the peek command-line interface.
(define (main)
  (define align? #f)
  (define swatches? #t)
  (define color-mode 'always)
  (define pager? #f)
  (define type #f)
  (define file-path #f)
  (command-line
   #:program "peek"
   #:once-each
   [("--type") value
               "Explicit file type for stdin input."
               (set! type (string->symbol value))]
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
  (define options
    (make-preview-options #:type      type
                          #:align?    align?
                          #:swatches? swatches?
                          #:color-mode color-mode))
  (define output
    (cond
      [file-path
       (unless (file-exists? file-path)
         (usage-error (format "file not found: ~a" file-path)))
       (preview-file file-path options (current-output-port))]
      [else
       (define source
         (port->string (current-input-port)))
       (preview-string source #f options (current-output-port))]))
  (cond
    [pager?
     (write-through-pager output)]
    [else
     (display output)]))

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
   "color: #fff;")
  (check-not-exn
   (lambda ()
     (define-values (pager-pid pager-out pager-in pager-err)
       (subprocess (current-output-port) #f (current-error-port) "/bin/cat"))
     (display "peek pager smoke\n" pager-in)
     (close-output-port pager-in)
     (subprocess-wait pager-pid))))
