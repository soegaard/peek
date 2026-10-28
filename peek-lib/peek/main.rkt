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

(require json
         racket/cmdline
         racket/list
         racket/string
         racket/system
         racket/port
         "asm.rkt"
         "preview.rkt"
         "private/input-probe.rkt")

;; usage-error : string? -> nothing
;;   Print a command-line error and exit.
(define (usage-error message)
  (eprintf "peek: ~a\n" message)
  (exit 1))

;; interactive-stdin-without-file? : input-port? (or/c path-string? #f) -> boolean?
;;   Determine whether `peek` started without a file while stdin is a terminal.
(define (interactive-stdin-without-file? in file-path)
  (and (not file-path)
       (terminal-port? in)))

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

;; parse-positive-line-number : string? string? -> exact-positive-integer?
;;   Parse one positive line number for `--lines`.
(define (parse-positive-line-number raw which-end)
  (define maybe-number
    (string->number raw))
  (unless (exact-positive-integer? maybe-number)
    (usage-error (format "expected a positive ~a line number after --lines: ~a"
                         which-end
                         raw)))
  maybe-number)

;; line-range-spec->range : string? -> preview-line-range?
;;   Parse one `--lines` specification into a shared preview line range.
(define (line-range-spec->range spec)
  (define trimmed
    (string-trim spec))
  (cond
    [(regexp-match #px"^([0-9]+):([0-9]+)$" trimmed)
     =>
     (lambda (match)
       (define start
         (parse-positive-line-number (list-ref match 1) "start"))
       (define end
         (parse-positive-line-number (list-ref match 2) "end"))
       (when (> start end)
         (usage-error (format "expected --lines start to be <= end: ~a"
                              spec)))
       (preview-line-range start end))]
    [(regexp-match #px"^([0-9]+):$" trimmed)
     =>
     (lambda (match)
       (preview-line-range (parse-positive-line-number (list-ref match 1) "start")
                           #f))]
    [(regexp-match #px"^:([0-9]+)$" trimmed)
     =>
     (lambda (match)
       (preview-line-range #f
                           (parse-positive-line-number (list-ref match 1) "end")))]
    [(regexp-match #px"^[0-9]+$" trimmed)
     (define line-no
       (parse-positive-line-number trimmed "single"))
     (preview-line-range line-no line-no)]
    [else
     (usage-error (format "expected --lines N, N:M, N:, or :M; got ~a"
                          spec))]))

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

;; option-symbol : string? -> symbol?
;;   Normalize one symbolic command-line option without changing punctuation.
(define (option-symbol value)
  (string->symbol (string-downcase value)))

;; call-with-assembly-input : (or/c path-string? #f) (input-port? -> any/c) -> any/c
;;   Open a byte-authoritative input path, or pass standard input through unchanged.
(define (call-with-assembly-input file-path proc)
  (cond
    [file-path
     (call-with-input-file file-path proc #:mode 'binary)]
    [else
     (proc (current-input-port))]))

;; write-assembly-detection : input-port? (or/c path-string? #f) assembly-options? output-port? -> void?
;;   Emit one bounded JSON detection record without consuming unsampled source.
(define (write-assembly-detection in file-path assembly out)
  (define probe
    (probe-input-port in
                      #:mode (assembly-options-detection-mode assembly)))
  (write-json (assembly-detection-jsexpr probe
                                         #:path file-path
                                         #:assembly assembly)
              out)
  (newline out)
  (flush-output out))

;; write-assembly-token-dump : input-port? assembly-options? output-port? -> void?
;;   Emit source tokens only after representation routing accepts source input.
(define (write-assembly-token-dump in assembly out)
  (define probe
    (probe-input-port in
                      #:mode (assembly-options-detection-mode assembly)))
  (define input-kind
    (assembly-input-kind (input-probe-sample probe) assembly))
  (unless (eq? input-kind 'source)
    (raise-user-error 'assembly
                      (format "cannot dump assembly tokens for ~a input"
                              input-kind)))
  (write-asm-token-jsonl (input-probe-replay-port probe)
                         out
                         #:assembly assembly))

;; main : -> void?
;;   Run the peek command-line interface.
(define (main)
  (define align? #f)
  (define swatches? #t)
  (define color-mode 'always)
  (define binary-mode 'hex)
  (define diff? #f)
  (define diff-staged? #f)
  (define pretty? #f)
  (define toc? #f)
  (define section #f)
  (define follow? #f)
  (define line-range #f)
  (define line-numbers? #f)
  (define stats? #f)
  (define directory-sort 'kind)
  (define search-byte-specs '())
  (define search-text-specs '())
  (define grep-specs '())
  (define pager? #t)
  (define list-file-types? #f)
  (define dialect #f)
  (define architecture #f)
  (define encoding #f)
  (define detection-mode 'interactive)
  (define detect-only? #f)
  (define json? #f)
  (define explain-type? #f)
  (define dump-tokens-format #f)
  (define type #f)
  (define file-path #f)
  (command-line
   #:program "peek"
   #:once-each
   [("--type") value
               "Explicit file type for stdin input."
               (set! type (string->symbol value))]
   [("--dialect") value
    "Assembly dialect, such as generic, ca65, gas, or nasm."
    (set! dialect (option-symbol value))]
   [("--arch") value
    "Assembly target architecture, such as x86, arm, aarch64, or m68k."
    (set! architecture (option-symbol value))]
   [("--encoding") value
    "Assembly source encoding: auto, utf-8, utf-16le, or utf-16be."
    (set! encoding (option-symbol value))]
   [("--detection-mode") value
    "Assembly detection schedule: interactive or fixed-prefix."
    (set! detection-mode (option-symbol value))]
   [("--detect-only")
    "Inspect a bounded assembly input sample without rendering it."
    (set! detect-only? #t)]
   [("--json")
    "With --detect-only, emit the inspection record as JSON."
    (set! json? #t)]
   [("--explain-type")
    "Write the assembly selection and representation explanation to stderr."
    (set! explain-type? #t)]
   [("--dump-tokens") value
    "Stream assembly-derived tokens; the only supported format is jsonl."
    (set! dump-tokens-format (option-symbol value))]
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
   [("--cached")
    "With --diff, compare the staged/index version against HEAD."
    (set! diff-staged? #t)]
   [("--staged")
    "With --diff, compare the staged/index version against HEAD."
    (set! diff-staged? #t)]
   [("-p" "--pretty")
    "Enable pretty rendering when the selected file type supports it."
    (set! pretty? #t)]
   [("--toc")
    "Render a heading outline when the selected file type supports it."
    (set! toc? #t)]
   [("--section") value
    "Render one named section when the selected file type supports it."
    (set! section value)]
   [("--follow")
    "Keep previewing a file as new content is appended."
    (set! follow? #t)]
   [("--lines") value
    "Render only one output line range: N, N:M, N:, or :M."
    (set! line-range (line-range-spec->range value))]
   [("-n" "--line-numbers")
    "Prefix output lines with nl-style line numbers."
    (set! line-numbers? #t)]
   [("--stats")
    "Append a compact summary block for directory and archive previews."
    (set! stats? #t)]
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
  (when follow?
    (set! pager? #f))
  (when (or detect-only?
            dump-tokens-format)
    (set! pager? #f))
  (cond
    [list-file-types?
     (print-supported-file-types)]
    [else
     (when (interactive-stdin-without-file? (current-input-port)
                                            file-path)
       (usage-error "Missing filename (\"peek --help\" for help)"))
     (when file-path
       (unless (or (file-exists? file-path)
                   (directory-exists? file-path))
         (usage-error (format "file not found: ~a" file-path))))
     (when (and diff?
                (not file-path))
       (usage-error "--diff requires a file path"))
     (when (and diff-staged?
                (not diff?))
       (usage-error "--cached and --staged require --diff"))
     (when (and follow?
                (not file-path))
       (usage-error "--follow requires a file path"))
     (when (and follow?
                (directory-exists? file-path))
       (usage-error "--follow requires a regular file"))
     (when (and follow?
                diff?)
       (usage-error "--follow does not combine with --diff"))
     (when (and follow?
                stats?)
       (usage-error "--follow does not combine with --stats"))
     (when (and follow?
                toc?)
       (usage-error "--follow does not combine with --toc"))
     (when (and follow?
                section)
       (usage-error "--follow does not combine with --section"))
     (when (and (or dialect architecture encoding
                    (not (eq? detection-mode 'interactive)))
                (not (or (eq? type 'asm)
                         detect-only?
                         (not type))))
       (usage-error "assembly selection options require --type asm, --detect-only, or automatic type selection"))
     (when (and detect-only?
                (not json?))
       (usage-error "--detect-only requires --json"))
     (when (and detect-only?
                type
                (not (eq? type 'asm)))
       (usage-error "--detect-only accepts only --type asm"))
     (when (and json?
                (not detect-only?))
       (usage-error "--json currently requires --detect-only"))
     (when (and explain-type?
                type
                (not (eq? type 'asm)))
       (usage-error "--explain-type accepts --type asm or automatic type selection"))
     (when (and dump-tokens-format
                (not (eq? dump-tokens-format 'jsonl)))
       (usage-error "--dump-tokens supports only jsonl"))
     (when (and dump-tokens-format
                (not (eq? type 'asm)))
       (usage-error "--dump-tokens requires --type asm"))
     (when (and detect-only?
                dump-tokens-format)
       (usage-error "--detect-only does not combine with --dump-tokens"))
     (when (and detect-only?
                explain-type?)
       (usage-error "--detect-only does not combine with --explain-type"))
     (when (and follow?
                (eq? type 'asm))
       (usage-error "--follow is not available for assembly previews yet"))
     (unless (memq detection-mode '(interactive fixed-prefix))
       (usage-error (format "unknown assembly detection mode: ~a"
                            detection-mode)))
     (when (and (or detect-only?
                    dump-tokens-format)
                (or align?
                    (not swatches?)
                    (not (eq? binary-mode 'hex))
                    diff?
                    diff-staged?
                    pretty?
                    toc?
                    section
                    follow?
                    line-range
                    (pair? grep-specs)
                    line-numbers?
                    stats?
                    (not (eq? directory-sort 'kind))
                    (pair? search-byte-specs)
                    (pair? search-text-specs)))
       (usage-error "machine-readable assembly modes do not combine with presentation options"))
     (define assembly
       (make-assembly-options
        #:dialect (cond
                    [(eq? type 'asm)
                     (or dialect 'generic)]
                    [else
                     dialect])
        #:architecture architecture
        #:encoding (or encoding 'auto)
        #:detection-mode detection-mode))
     (define options
       (make-preview-options #:type      type
                             #:align?    align?
                             #:swatches? swatches?
                             #:color-mode color-mode
                             #:binary-mode binary-mode
                             #:diff?     diff?
                             #:diff-staged? diff-staged?
                             #:directory-sort directory-sort
                             #:search-bytes (append (map search-byte-spec->bytes
                                                         (reverse search-byte-specs))
                                                    (map search-text-spec->bytes
                                                         (reverse search-text-specs)))
                             #:toc? toc?
                             #:section section
                             #:follow? follow?
                             #:line-range line-range
                             #:grep-patterns (map grep-spec->regexp
                                                  (reverse grep-specs))
                             #:line-numbers? line-numbers?
                             #:stats? stats?
                             #:pretty? pretty?))
     (define (write-preview out)
       (cond
         [detect-only?
          (call-with-assembly-input
           file-path
           (lambda (in)
             (write-assembly-detection in file-path assembly out)))]
         [dump-tokens-format
          (call-with-assembly-input
           file-path
           (lambda (in)
             (write-assembly-token-dump in assembly out)))]
         [(and explain-type?
               file-path)
          (call-with-assembly-input
           file-path
           (lambda (in)
             (define probe
               (probe-input-port in
                                 #:mode (assembly-options-detection-mode assembly)))
             (write-assembly-explanation probe
                                         (current-error-port)
                                         #:path file-path
                                         #:assembly assembly
                                         #:automatic? (not type))
             (preview-port (input-probe-replay-port probe)
                           file-path
                           options
                           out
                           #:assembly assembly)))]
         [file-path
          (preview-path-port file-path options out #:assembly assembly)]
         [explain-type?
          (define probe
            (probe-input-port (current-input-port)
                              #:mode (assembly-options-detection-mode assembly)))
          (write-assembly-explanation probe
                                      (current-error-port)
                                      #:assembly assembly
                                      #:automatic? (not type))
          (preview-port (input-probe-replay-port probe)
                        #f
                        options
                        out
                        #:assembly assembly)]
         [else
          (preview-port (current-input-port)
                        #f
                        options
                        out
                        #:assembly assembly)]))
     (with-handlers ([exn:break?
                      (lambda (_)
                        (void))]
                     [exn:fail:user?
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

  (check-false (interactive-stdin-without-file? (open-input-string "peek")
                                                #f))
  (check-false (interactive-stdin-without-file? (current-input-port)
                                                "demo.txt"))

  (check-equal? (search-text-spec->bytes "peek")
                (string->bytes/utf-8 "peek"))
  (check-equal? (search-text-spec->bytes "π")
                (string->bytes/utf-8 "π")))
