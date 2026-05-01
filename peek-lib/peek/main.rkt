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

;; hex-digit->value : char? -> (or/c exact-nonnegative-integer? #f)
;;   Convert a hexadecimal digit to its numeric value.
(define (hex-digit->value ch)
  (cond
    [(char<=? #\0 ch #\9) (- (char->integer ch) (char->integer #\0))]
    [(char<=? #\a ch #\f) (+ 10 (- (char->integer ch) (char->integer #\a)))]
    [(char<=? #\A ch #\F) (+ 10 (- (char->integer ch) (char->integer #\A)))]
    [else #f]))

;; search-byte-spec->bytes : string? -> bytes?
;;   Parse a hex byte specification into raw bytes.
(define (search-byte-spec->bytes spec)
  (define cleaned
    (regexp-replace* #px"[\\s,_:-]+" (string-trim spec) ""))
  (cond
    [(zero? (string-length cleaned))
     (usage-error "expected at least one byte after --search-bytes")]
    [(odd? (string-length cleaned))
     (usage-error (format "expected an even number of hex digits after --search-bytes: ~a"
                          spec))]
    [else
     (define out
       (open-output-bytes))
     (for ([i (in-range 0 (string-length cleaned) 2)])
       (define hi
         (hex-digit->value (string-ref cleaned i)))
       (define lo
         (hex-digit->value (string-ref cleaned (add1 i))))
       (unless (and hi lo)
         (usage-error (format "expected hex bytes after --search-bytes: ~a" spec)))
     (write-byte (+ (* 16 hi) lo) out))
     (get-output-bytes out)]))

;; search-text-spec->bytes : string? -> bytes?
;;   Encode a UTF-8 text search string as raw bytes.
(define (search-text-spec->bytes spec)
  (cond
    [(zero? (string-length spec))
     (usage-error "expected at least one character after --search-text")]
    [else
     (string->bytes/utf-8 spec)]))

;; grep-spec->regexp : string? -> regexp?
;;   Compile a grep pattern as a regular expression.
(define (grep-spec->regexp spec)
  (with-handlers ([exn:fail?
                   (lambda (_)
                     (usage-error (format "invalid regexp after --grep: ~a" spec)))])
    (pregexp spec)))

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
  (define binary-mode 'hex)
  (define diff? #f)
  (define pretty? #f)
  (define section #f)
  (define line-numbers? #f)
  (define directory-sort 'kind)
  (define search-byte-specs '())
  (define search-text-specs '())
  (define grep-specs '())
  (define pager? #t)
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
   [("--pager")
    "Pipe output through $PAGER or less -R."
    (set! pager? #t)]
   [("-P" "--no-pager")
    "Do not pipe output through $PAGER or less -R."
    (set! pager? #f)]
   [("--color") value
                "Choose color mode: always, auto, or never."
                (set! color-mode
                      (case (string->symbol value)
                        [(always auto never) (string->symbol value)]
                        [else
                         (usage-error (format "unknown color mode: ~a" value))]))]
   [("--bits")
    "Render binary input as bits instead of hex."
    (set! binary-mode 'bits)]
   [("--diff")
    "Preview only changed Git hunks for a file path."
    (set! diff? #t)]
   [("-p" "--pretty")
    "Enable pretty rendering when the selected file type supports it."
    (set! pretty? #t)]
   [("--section") value
    "Render one named section when the selected file type supports it."
    (set! section value)]
   [("-n" "--line-numbers")
    "Prefix output lines with nl-style line numbers."
    (set! line-numbers? #t)]
   [("--kind")
    "Sort directory previews by kind and then by name."
    (set! directory-sort 'kind)]
   [("--size")
    "Sort directory previews by kind and then by file size."
    (set! directory-sort 'size)]
   #:multi
   [("--search-bytes") spec
    "Highlight raw bytes; repeat to add another hex byte sequence."
    (set! search-byte-specs (cons spec search-byte-specs))]
   [("--search-text") spec
    "Highlight UTF-8 text; repeat to add another search string."
    (set! search-text-specs (cons spec search-text-specs))]
   [("--grep") spec
    "Emphasize preview lines whose rendered text matches a regexp."
    (set! grep-specs (cons spec grep-specs))]
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
       (unless (or (file-exists? file-path)
                   (directory-exists? file-path))
         (usage-error (format "file not found: ~a" file-path))))
     (when (and diff?
                (not file-path))
       (usage-error "--diff requires a file path"))
     (define options
       (make-preview-options #:type      type
                             #:align?    align?
                             #:swatches? swatches?
                             #:color-mode color-mode
                             #:binary-mode binary-mode
                             #:diff?     diff?
                             #:directory-sort directory-sort
                             #:search-bytes (append (map search-byte-spec->bytes
                                                         (reverse search-byte-specs))
                                                    (map search-text-spec->bytes
                                                         (reverse search-text-specs)))
                             #:section section
                             #:grep-patterns (map grep-spec->regexp
                                                  (reverse grep-specs))
                             #:line-numbers? line-numbers?
                             #:pretty? pretty?))
     (define (write-preview out)
       (cond
         [file-path
          (preview-path-port file-path options out)]
         [else
          (preview-port (current-input-port) #f options out)]))
     (with-handlers ([exn:fail:user?
                      (lambda (e)
                        (usage-error (exn-message e)))])
       (cond
         [pager?
          (call-with-pager-output write-preview)]
         [else
          (write-preview (current-output-port))]))]))

(module+ main
  (main))

(module+ test
  (require rackunit)

  (check-equal? (search-text-spec->bytes "peek")
                (string->bytes/utf-8 "peek"))
  (check-equal? (search-text-spec->bytes "π")
                (string->bytes/utf-8 "π")))
