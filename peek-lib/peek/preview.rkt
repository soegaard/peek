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
;; preview-options-binary-mode         -- Binary rendering mode.
;; preview-options-search-bytes        -- Highlighted byte sequences.
;; preview-options-diff?               -- Whether Git-focused diff preview is enabled.
;; preview-options-pretty?             -- Whether pretty mode is enabled.
;; preview-options-section             -- Selected named section.
;; preview-options-grep-patterns       -- Line-matching regexps.
;; preview-options-line-numbers?       -- Whether line numbers are enabled.
;; preview-options-directory-sort      -- Directory sort mode.
;; supported-file-types                -- Supported explicit file type names.
;; make-preview-options                -- Construct preview options.
;; preview-string : string? ... -> string?
;;   Preview a source string using the selected options.
;; preview-port : input-port? ... -> void?
;;   Preview from an input port to an output port.
;; preview-path-port : path-string? ... -> void?
;;   Preview from a filesystem path to an output port.
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
 ;; preview-options-binary-mode Binary rendering mode.
 preview-options-binary-mode
 ;; preview-options-search-bytes Highlighted byte sequences.
 preview-options-search-bytes
 ;; preview-options-diff?       Whether Git-focused diff preview is enabled.
 preview-options-diff?
 ;; preview-options-pretty?     Whether pretty mode is enabled.
 preview-options-pretty?
 ;; preview-options-section     Selected named section.
 preview-options-section
 ;; preview-options-grep-patterns Line-matching regexps.
 preview-options-grep-patterns
 ;; preview-options-line-numbers? Whether line numbers are enabled.
 preview-options-line-numbers?
 ;; preview-options-directory-sort Directory sort mode.
 preview-options-directory-sort
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
 ;; preview-path-port : path-string? preview-options? output-port? -> void?
 ;;   Preview directly from a filesystem path to an output port.
 preview-path-port
 ;; preview-file : path-string? preview-options? -> string?
 ;;   Preview a file from disk.
 preview-file)

(require racket/file
         racket/bytes
         racket/list
         racket/path
         racket/port
         racket/string
         "common-style.rkt"
         "archive.rkt"
         "binary.rkt"
         "git-diff.rkt"
         "directory.rkt"
         "css.rkt"
         "c.rkt"
         "cpp.rkt"
         "delimited.rkt"
         "go.rkt"
         "html.rkt"
         "java.rkt"
         "js.rkt"
         "json.rkt"
         "haskell.rkt"
         "objc.rkt"
         "makefile.rkt"
         "markdown.rkt"
         "tex.rkt"
         "latex.rkt"
         "plist.rkt"
         "python.rkt"
         "pascal.rkt"
         "rust.rkt"
         "racket.rkt"
         "rhombus.rkt"
         "swift.rkt"
         "shell.rkt"
         "yaml.rkt"
         "scribble.rkt"
         "wat.rkt")

(struct preview-options (type align? swatches? color-mode binary-mode search-bytes diff? pretty? section grep-patterns line-numbers? directory-sort) #:transparent)

;; Supported explicit file-type names.
(define supported-file-types
  '(archive bash binary c cpp css csv go haskell html java js json jsx latex makefile md objc pascal plist powershell python rhombus rkt rust scrbl swift tex tsv wat yaml zsh))

;; make-preview-options : -> preview-options?
;;   Construct default preview options.
(define (make-preview-options #:type        [type #f]
                              #:align?      [align? #f]
                              #:swatches?   [swatches? #t]
                              #:color-mode  [color-mode 'always]
                              #:binary-mode [binary-mode 'hex]
                              #:search-bytes [search-bytes '()]
                              #:diff?       [diff? #f]
                              #:pretty?     [pretty? #f]
                              #:section     [section #f]
                              #:grep-patterns [grep-patterns '()]
                              #:line-numbers? [line-numbers? #f]
                              #:directory-sort [directory-sort 'kind])
  (preview-options type align? swatches? color-mode binary-mode search-bytes diff? pretty? section grep-patterns line-numbers? directory-sort))

;; -----------------------------------------------------------------------------
;; Line numbering

(define (ansi . codes)
  (string-append "\033[" (string-join (map number->string codes) ";") "m"))

(define ansi-pattern
  #px"\u001b\\[[0-9;]*m")

(define ansi-reset
  (ansi 0))

(define ansi-grep-background
  (ansi 48 2 64 64 28))

;; default-line-number-width : exact-positive-integer?
;;   Fallback line-number field width for streaming stdin previews.
(define default-line-number-width
  6)

;; estimated-line-number-width : (or/c path-string? #f) -> exact-positive-integer?
;;   Estimate the width of the line-number field from file size when possible.
(define (estimated-line-number-width maybe-path)
  (cond
    [(and maybe-path
          (file-exists? maybe-path))
     (string-length
      (number->string
       (max 1
            (file-size maybe-path))))]
    [else
     default-line-number-width]))

;; line-number-prefix : exact-positive-integer? exact-positive-integer? -> string?
;;   Build one nl-style line-number prefix.
(define (line-number-prefix width line-no)
  (define digits
    (number->string line-no))
  (string-append (make-string (max 0 (- width (string-length digits))) #\space)
                 digits
                 "\t"))

;; line-number-blank-prefix : exact-positive-integer? -> string?
;;   Build one empty nl-style prefix.
(define (line-number-blank-prefix width)
  (string-append (make-string width #\space)
                 "\t"))

;; make-line-number-output-port : output-port? exact-positive-integer? -> output-port?
;;   Wrap an output port with nl-style line numbers.
(define (make-line-number-output-port out width)
  (define current-line
    1)
  (define at-line-start?
    #t)
  (define (emit-prefix)
    (when at-line-start?
      (display (line-number-prefix width current-line) out)
      (set! at-line-start? #f)))
  (define (write-out bs start end non-block? breakable?)
    (let loop ([pos start]
               [segment-start start])
      (cond
        [(= pos end)
         (when (< segment-start end)
           (emit-prefix)
           (write-bytes bs out segment-start end))
         (- end start)]
        [(= (bytes-ref bs pos) 10)
         (emit-prefix)
         (write-bytes bs out segment-start (add1 pos))
         (set! at-line-start? #t)
         (set! current-line (add1 current-line))
         (loop (add1 pos) (add1 pos))]
        [else
         (loop (add1 pos) segment-start)])))
  (make-output-port 'peek/line-numbers
                    always-evt
                    write-out
                    (lambda ()
                      (flush-output out))))

;; maybe-wrap-line-number-output-port : output-port? (or/c path-string? #f) preview-options? -> output-port?
;;   Wrap an output port with line numbers when requested.
(define (maybe-wrap-line-number-output-port out maybe-path options)
  (cond
    [(preview-options-line-numbers? options)
     (make-line-number-output-port out
                                   (estimated-line-number-width maybe-path))]
    [else
     out]))

;; -----------------------------------------------------------------------------
;; Grep-style line highlighting

;; strip-ansi : string? -> string?
;;   Remove ANSI escape sequences from a string.
(define (strip-ansi text)
  (regexp-replace* ansi-pattern text ""))

;; grep-line-match? : string? (listof regexp?) -> boolean?
;;   Determine whether a rendered line matches any grep pattern.
(define (grep-line-match? line patterns)
  (define plain-line
    (strip-ansi line))
  (ormap (lambda (pattern)
           (regexp-match? pattern plain-line))
         patterns))

;; highlight-grep-line : string? boolean? -> string?
;;   Emphasize a matching line.
(define (highlight-grep-line line color?)
  (cond
    [color?
     (string-append ansi-grep-background
                    (regexp-replace* #px"\u001b\\[0m"
                                     line
                                     (string-append "\u001b[0m" ansi-grep-background))
                    ansi-reset)]
    [else
     (string-append "> " line)]))

;; make-grep-output-port : output-port? boolean? (listof regexp?) -> output-port?
;;   Wrap an output port to highlight matching rendered lines.
(define (make-grep-output-port out color? patterns)
  (define line-buffer
    (open-output-bytes))
  (define (flush-buffer)
    (define line-bytes
      (get-output-bytes line-buffer #t))
    (unless (zero? (bytes-length line-bytes))
      (define line
        (bytes->string/utf-8 line-bytes))
      (define rendered
        (if (grep-line-match? line patterns)
            (highlight-grep-line line color?)
            line))
      (display rendered out)))
  (define (write-out bs start end non-block? breakable?)
    (let loop ([pos start]
               [segment-start start])
      (cond
        [(= pos end)
         (when (< segment-start end)
           (write-bytes bs line-buffer segment-start end))
         (- end start)]
        [(= (bytes-ref bs pos) 10)
         (write-bytes bs line-buffer segment-start (add1 pos))
         (flush-buffer)
         (loop (add1 pos) (add1 pos))]
        [else
         (loop (add1 pos) segment-start)])))
  (make-output-port 'peek/grep
                    always-evt
                    write-out
                    (lambda ()
                      (flush-buffer)
                      (flush-output out))))

;; maybe-wrap-grep-output-port : output-port? boolean? preview-options? -> output-port?
;;   Wrap an output port with grep-style line highlighting when requested.
(define (maybe-wrap-grep-output-port out color? options)
  (cond
    [(pair? (preview-options-grep-patterns options))
     (make-grep-output-port out
                            color?
                            (preview-options-grep-patterns options))]
    [else
     out]))

;; add-grep-highlighting-to-string : string? boolean? preview-options? -> string?
;;   Add grep-style highlighting to a fully rendered preview string.
(define (add-grep-highlighting-to-string rendered color? options)
  (define out
    (open-output-string))
  (define grep-out
    (maybe-wrap-grep-output-port out color? options))
  (display rendered grep-out)
  (close-output-port grep-out)
  (get-output-string out))

;; postprocess-rendered-string : string? (or/c path-string? #f) boolean? preview-options? -> string?
;;   Apply generic line-oriented postprocessing to a rendered preview string.
(define (postprocess-rendered-string rendered maybe-path color? options)
  (define grep-rendered
    (cond
      [(pair? (preview-options-grep-patterns options))
       (add-grep-highlighting-to-string rendered color? options)]
      [else
       rendered]))
  (define out
    (open-output-string))
  (define numbered-out
    (maybe-wrap-line-number-output-port out maybe-path options))
  (display grep-rendered numbered-out)
  (close-output-port numbered-out)
  (get-output-string out))

;; color-enabled? : output-port? preview-options? -> boolean?
;;   Determine whether preview output should include ANSI color.
(define (color-enabled? out options)
  (case (preview-options-color-mode options)
    [(always) #t]
    [(never)  #f]
    [(auto)   (terminal-port? out)]
    [else     #t]))

;; diff-context-lines : exact-nonnegative-integer?
;;   Number of unchanged context lines to show around each Git hunk.
(define diff-context-lines
  2)

;; ensure-trailing-newline : string? -> string?
;;   Add a trailing newline when one is missing.
(define (ensure-trailing-newline text)
  (cond
    [(or (string=? text "")
         (string-suffix? text "\n"))
     text]
    [else
     (string-append text "\n")]))

;; slice-lines->string : (listof string?) exact-positive-integer? exact-nonnegative-integer? -> string?
;;   Convert a 1-based inclusive line slice back into source text.
(define (slice-lines->string lines start end)
  (cond
    [(< end start)
     ""]
    [else
     (string-join (take (drop lines (sub1 start))
                        (add1 (- end start)))
                  "\n"
                  #:after-last "\n")]))

;; diff-header-line : exact-positive-integer? boolean? -> string?
;;   Render one diff-hunk header line.
(define (diff-header-line anchor color?)
  (define header
    (format "@@ changed near line ~a @@" anchor))
  (cond
    [color?
     (string-append ansi-comment header ansi-reset "\n")]
    [else
     (string-append header "\n")]))

;; diff-line-marker : symbol? boolean? -> string?
;;   Render one diff line marker.
(define (diff-line-marker kind color?)
  (define marker
    (case kind
      [(added)   "+ "]
      [(removed) "- "]
      [else      "  "]))
  (cond
    [color?
     (string-append ansi-comment marker ansi-reset)]
    [else
     marker]))

;; diff-line-number-prefix : git-diff-line? exact-positive-integer? -> string?
;;   Render one numbered diff prefix.
(define (diff-line-number-prefix line width)
  (string-append (diff-line-marker (git-diff-line-kind line) #f)
                 (cond
                   [(git-diff-line-new-line-no line)
                    (line-number-prefix width
                                        (git-diff-line-new-line-no line))]
                   [(git-diff-line-old-line-no line)
                    (line-number-prefix width
                                        (git-diff-line-old-line-no line))]
                   [else
                    (line-number-blank-prefix width)])))

;; add-diff-line-numbers : string? exact-positive-integer? exact-positive-integer? -> string?
;;   Prefix rendered diff lines with original file line numbers.
(define (add-diff-line-numbers rendered start-line width)
  (define in
    (open-input-string (ensure-trailing-newline rendered)))
  (define out
    (open-output-string))
  (let loop ([line-no start-line])
    (define line
      (read-line in 'any))
    (unless (eof-object? line)
      (display (line-number-prefix width line-no) out)
      (display line out)
      (newline out)
      (loop (add1 line-no))))
  (get-output-string out))

;; rendered-lines : string? -> (listof string?)
;;   Split rendered preview text into lines without a trailing empty sentinel.
(define (rendered-lines rendered)
  (define pieces
    (string-split (ensure-trailing-newline rendered) "\n"))
  (cond
    [(and (pair? pieces)
          (string=? (last pieces) ""))
     (drop-right pieces 1)]
    [else
     pieces]))

;; render-diff-line : git-diff-line? string? boolean? exact-positive-integer? boolean? -> string?
;;   Render one parsed diff line with marker and optional numbering.
(define (render-diff-line line rendered-line color? line-number-width line-numbers?)
  (define prefix
    (cond
      [line-numbers?
       (string-append (diff-line-marker (git-diff-line-kind line) color?)
                      (cond
                        [(git-diff-line-new-line-no line)
                         (line-number-prefix line-number-width
                                             (git-diff-line-new-line-no line))]
                        [(git-diff-line-old-line-no line)
                         (line-number-prefix line-number-width
                                             (git-diff-line-old-line-no line))]
                        [else
                         (line-number-blank-prefix line-number-width)]))]
      [else
       (diff-line-marker (git-diff-line-kind line) color?)]))
  (string-append prefix rendered-line "\n"))

;; render-diff-line/fallback : git-diff-line? path-string? preview-options? output-port? boolean? exact-positive-integer? boolean? -> string?
;;   Render one diff line independently when hunk-level rendering cannot be used.
(define (render-diff-line/fallback line path options out color? line-number-width line-numbers?)
  (define rendered
    (preview-string/rendered (string-append (git-diff-line-text line) "\n")
                             path
                             options
                             out))
  (define rendered-line
    (cond
      [(pair? (rendered-lines rendered))
       (car (rendered-lines rendered))]
      [else
       ""]))
  (render-diff-line line
                    rendered-line
                    color?
                    line-number-width
                    line-numbers?))

;; current-file-rendered-lines : path-string? preview-options? output-port? -> (or/c (listof string?) #f)
;;   Render the whole current file and return one rendered line per source line when possible.
(define (current-file-rendered-lines path options out)
  (define source
    (file->string path))
  (define source-lines
    (drop-right (string-split source "\n" #:trim? #f) 1))
  (define rendered
    (preview-string/rendered source
                             path
                             options
                             out))
  (define lines
    (rendered-lines rendered))
  (and (= (length lines)
          (length source-lines))
       lines))

;; render-diff-hunk-snippet : git-diff-render-hunk? path-string? preview-options? output-port? boolean? exact-positive-integer? boolean? (or/c (listof string?) #f) -> string?
;;   Render one diff hunk, reusing whole-file rendered lines when possible.
(define (render-diff-hunk-snippet hunk path options out color? line-number-width line-numbers? file-rendered-lines)
  (apply string-append
         (for/list ([line (in-list (git-diff-render-hunk-lines hunk))])
           (cond
             [(and file-rendered-lines
                   (git-diff-line-new-line-no line))
              (render-diff-line line
                                (list-ref file-rendered-lines
                                          (sub1 (git-diff-line-new-line-no line)))
                                color?
                                line-number-width
                                line-numbers?)]
             [else
              (render-diff-line/fallback line
                                         path
                                         options
                                         out
                                         color?
                                         line-number-width
                                         line-numbers?)]))))

;; diff-preview-options : preview-options? -> preview-options?
;;   Remove incompatible postprocessing from per-hunk rendering.
(define (diff-preview-options options)
  (make-preview-options #:type           (preview-options-type options)
                        #:align?         (preview-options-align? options)
                        #:swatches?      (preview-options-swatches? options)
                        #:color-mode     (preview-options-color-mode options)
                        #:binary-mode    (preview-options-binary-mode options)
                        #:search-bytes   (preview-options-search-bytes options)
                        #:diff?          #f
                        #:pretty?        (preview-options-pretty? options)
                        #:section        #f
                        #:grep-patterns  '()
                        #:line-numbers?  #f
                        #:directory-sort (preview-options-directory-sort options)))

;; render-diff-preview : path-string? preview-options? output-port? -> string?
;;   Render Git-changed file hunks using the normal file-type previewer.
(define (render-diff-preview path options out)
  (define file-type
    (effective-file-type path options))
  (cond
    [(directory-exists? path)
     (raise-user-error 'diff "directory preview does not support --diff")]
    [(or (eq? file-type 'archive)
         (eq? file-type 'binary))
     (raise-user-error 'diff "archive and binary previews do not support --diff")]
    [(preview-options-section options)
     (raise-user-error 'diff "--section does not combine with --diff yet")]
    [else
     (define hunks
       (git-working-tree-render-hunks path))
     (when (null? hunks)
       (raise-user-error 'diff (format "no changed hunks: ~a" path)))
     (define hunk-options
       (diff-preview-options options))
     (define color?
       (color-enabled? out options))
     (define file-rendered-lines
       (current-file-rendered-lines path hunk-options out))
     (define line-number-width
       (string-length
        (number->string
         (max 1
              (for*/fold ([largest 1])
                         ([hunk (in-list hunks)]
                          [line (in-list (git-diff-render-hunk-lines hunk))])
                (max largest
                     (or (git-diff-line-new-line-no line)
                         (git-diff-line-old-line-no line)
                         1)))))))
     (define rendered-hunks
       (for/list ([hunk (in-list hunks)])
         (define rendered-snippet
           (render-diff-hunk-snippet hunk
                                     path
                                     hunk-options
                                     out
                                     color?
                                     line-number-width
                                     (preview-options-line-numbers? options)
                                     file-rendered-lines))
         (string-append (diff-header-line (git-diff-render-hunk-anchor hunk)
                                          color?)
                        rendered-snippet)))
     (define final-options
       (make-preview-options #:type           (preview-options-type options)
                             #:align?         (preview-options-align? options)
                             #:swatches?      (preview-options-swatches? options)
                             #:color-mode     (preview-options-color-mode options)
                             #:binary-mode    (preview-options-binary-mode options)
                             #:search-bytes   (preview-options-search-bytes options)
                             #:diff?          (preview-options-diff? options)
                             #:pretty?        (preview-options-pretty? options)
                             #:section        (preview-options-section options)
                             #:grep-patterns  (preview-options-grep-patterns options)
                             #:line-numbers?  #f
                             #:directory-sort (preview-options-directory-sort options)))
     (postprocess-rendered-string (string-join rendered-hunks "\n")
                                  path
                                  color?
                                  final-options)]))

;; detect-file-type : (or/c path-string? #f) -> (or/c symbol? #f)
;;   Infer a supported file type from a file path.
(define (detect-file-type maybe-path)
  (cond
    [(not maybe-path) #f]
    [else
     (cond
       [(directory-exists? maybe-path) 'directory]
       [else
     (define path-string
       (path->string (simple-form-path maybe-path)))
     (define file-name
       (let ([tail (file-name-from-path (simple-form-path maybe-path))])
         (if tail
             (path->string tail)
             path-string)))
     (cond
       [(regexp-match? #px"(?i:\\.zip)$" path-string) 'archive]
       [(regexp-match? #px"(?i:\\.tar)$" path-string) 'archive]
       [(regexp-match? #px"(?i:\\.(?:tar\\.gz|tgz))$" path-string) 'archive]
       [(or (regexp-match? #px"(?i:\\.go)$" path-string)
            (member file-name '("go.mod" "go.work")))
        'go]
       [(regexp-match? #px"(?i:\\.(?:hs|lhs)(?:-boot)?)$" path-string) 'haskell]
       [(regexp-match? #px"(?i:\\.css)$" path-string) 'css]
       [(regexp-match? #px"(?i:\\.(?:c|h))$" path-string) 'c]
       [(regexp-match? #px"(?i:\\.(?:cpp|cc|cxx|cp|c\\+\\+|cppm|ixx))$" path-string)
        'cpp]
       [(regexp-match? #px"(?i:\\.(?:hpp|hh|hxx|h\\+\\+|ipp|tpp))$" path-string)
        'cpp]
       [(regexp-match? #px"(?i:\\.mk)$" path-string) 'makefile]
       [(regexp-match? #px"(?i:(?:^|-)makefile$|(?:^|-)gnumakefile$)" (path->string (file-name-from-path (simple-form-path maybe-path))))
        'makefile]
       [(regexp-match? #px"(?i:\\.m)$" path-string) 'objc]
       [(regexp-match? #px"(?i:\\.csv)$" path-string) 'csv]
       [(regexp-match? #px"(?i:\\.html?)$" path-string) 'html]
       [(regexp-match? #px"(?i:\\.java)$" path-string) 'java]
       [(regexp-match? #px"(?i:\\.(?:sh|bash))$" path-string) 'bash]
       [(regexp-match? #px"(?i:\\.jsx)$" path-string) 'jsx]
       [(regexp-match? #px"(?i:\\.(?:json|webmanifest))$" path-string)
        'json]
       [(regexp-match? #px"(?i:\\.md)$" path-string) 'md]
       [(regexp-match? #px"(?i:\\.(?:cls|sty|latex|ltx))$" path-string) 'latex]
       [(regexp-match? #px"(?i:\\.plist)$" path-string) 'plist]
       [(regexp-match? #px"(?i:\\.ps1)$" path-string) 'powershell]
       [(regexp-match? #px"(?i:\\.(?:py|pyi|pyw))$" path-string) 'python]
       [(regexp-match? #px"(?i:\\.(?:pas|pp|dpr|lpr|inc))$" path-string) 'pascal]
       [(regexp-match? #px"(?i:\\.rs)$" path-string) 'rust]
       [(regexp-match? #px"(?i:\\.rhm)$" path-string) 'rhombus]
       [(regexp-match? #px"(?i:\\.tex)$" path-string) 'tex]
       [(regexp-match? #px"(?i:\\.swift)$" path-string) 'swift]
       [(regexp-match? #px"(?i:\\.(?:ya?ml))$" path-string) 'yaml]
       [(regexp-match? #px"(?i:\\.scrbl)$" path-string) 'scrbl]
       [(regexp-match? #px"(?i:\\.zsh)$" path-string) 'zsh]
       [(regexp-match? #px"(?i:\\.tsv)$" path-string) 'tsv]
       [(regexp-match? #px"(?i:\\.wat)$" path-string) 'wat]
       [(regexp-match? #px"(?i:\\.(?:js|mjs|cjs))$" path-string)
        'js]
       [(regexp-match? #px"(?i:\\.(?:rkt|ss|scm|rktd))$" path-string)
        'rkt]
       [else
        #f])])]))

;; effective-file-type : (or/c path-string? #f) preview-options? -> (or/c symbol? #f)
;;   Resolve the selected file type from options and path.
(define (effective-file-type maybe-path options)
  (cond
    [(preview-options-type options) => values]
    [else                             (detect-file-type maybe-path)]))

;; bytes->text-or-false : bytes? -> (or/c string? #f)
;;   Decode bytes as UTF-8 when possible.
(define (bytes->text-or-false bs)
  (with-handlers ([exn:fail? (lambda (_) #f)])
    (bytes->string/utf-8 bs)))

;; preview-string/rendered : string? (or/c path-string? #f) preview-options? output-port? -> string?
;;   Preview a source string and return the rendered result.
(define (preview-string/rendered source
                                 [maybe-path #f]
                                 [options (make-preview-options)]
                                 [out (current-output-port)])
  (define file-type
    (effective-file-type maybe-path options))
  (cond
    [(eq? file-type 'archive)
     (or (render-archive-preview (string->bytes/utf-8 source)
                                 #:path maybe-path
                                 #:color? (color-enabled? out options))
         source)]
    [(eq? file-type 'directory)
     source]
    [(eq? file-type 'binary)
     (render-binary-preview (string->bytes/utf-8 source)
                            #:color? (color-enabled? out options)
                            #:bits? (eq? (preview-options-binary-mode options)
                                         'bits)
                            #:search-bytes (preview-options-search-bytes options))]
    [(not (color-enabled? out options)) source]
    [(eq? file-type 'css)
     (render-css-preview source
                         #:align?    (preview-options-align? options)
                         #:swatches? (preview-options-swatches? options))]
    [(eq? file-type 'c)
     (render-c-preview source)]
    [(eq? file-type 'cpp)
     (render-cpp-preview source)]
    [(eq? file-type 'makefile)
     (render-makefile-preview source)]
    [(eq? file-type 'objc)
     (render-objc-preview source)]
    [(eq? file-type 'csv)
     (render-csv-preview source)]
    [(eq? file-type 'go)
     (render-go-preview source)]
    [(eq? file-type 'haskell)
     (render-haskell-preview source)]
    [(eq? file-type 'bash)
     (render-shell-preview source #:shell 'bash)]
    [(eq? file-type 'html)
     (render-html-preview source)]
    [(eq? file-type 'java)
     (render-java-preview source)]
    [(eq? file-type 'js)
     (render-javascript-preview source)]
    [(eq? file-type 'json)
     (render-json-preview source)]
    [(eq? file-type 'plist)
     (render-plist-preview source)]
    [(eq? file-type 'jsx)
     (render-javascript-preview source
                                #:jsx? #t)]
    [(eq? file-type 'md)
     (render-markdown-preview source
                              #:pretty? (preview-options-pretty? options)
                              #:section (preview-options-section options))]
    [(eq? file-type 'latex)
     (render-latex-preview source)]
    [(eq? file-type 'powershell)
     (render-shell-preview source #:shell 'powershell)]
    [(eq? file-type 'python)
     (render-python-preview source)]
    [(eq? file-type 'pascal)
     (render-pascal-preview source)]
    [(eq? file-type 'rust)
     (render-rust-preview source)]
    [(eq? file-type 'rhombus)
     (render-rhombus-preview source)]
    [(eq? file-type 'swift)
     (render-swift-preview source)]
    [(eq? file-type 'yaml)
     (render-yaml-preview source)]
    [(eq? file-type 'tsv)
     (render-tsv-preview source)]
    [(eq? file-type 'rkt)
     (render-racket-preview source)]
    [(eq? file-type 'tex)
     (render-tex-preview source)]
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
  (define rendered
    (preview-string/rendered source maybe-path options out))
  (postprocess-rendered-string rendered
                               maybe-path
                               (color-enabled? out options)
                               options))

;; preview-port : input-port? (or/c path-string? #f) preview-options? output-port? -> void?
;;   Preview from an input port to an output port.
(define (preview-port in
                      [maybe-path #f]
                      [options (make-preview-options)]
                      [out (current-output-port)])
  (define color?
    (color-enabled? out options))
  (define actual-out
    (maybe-wrap-grep-output-port
     (maybe-wrap-line-number-output-port out maybe-path options)
     color?
     options))
  (define file-type
    (effective-file-type maybe-path options))
  (begin0
   (cond
    [(eq? file-type 'archive)
     (define source-bytes
       (port->bytes in))
     (define rendered
       (render-archive-preview source-bytes
                               #:path maybe-path
                               #:color? color?))
     (if rendered
         (display rendered actual-out)
         (display (render-binary-preview source-bytes
                                         #:color? color?
                                         #:bits? (eq? (preview-options-binary-mode options)
                                                      'bits)
                                         #:search-bytes (preview-options-search-bytes options))
                  actual-out))]
    [(eq? file-type 'directory)
     (copy-port in actual-out)]
    [(eq? file-type 'binary)
     (display (render-binary-preview (port->bytes in)
                                     #:color? color?
                                     #:bits? (eq? (preview-options-binary-mode options)
                                                  'bits)
                                     #:search-bytes (preview-options-search-bytes options))
              actual-out)]
    [(and (or (eq? file-type 'bash)
              (eq? file-type 'css)
              (eq? file-type 'c)
              (eq? file-type 'cpp)
              (eq? file-type 'makefile)
              (eq? file-type 'objc)
              (eq? file-type 'csv)
              (eq? file-type 'go)
              (eq? file-type 'haskell)
              (eq? file-type 'java)
              (eq? file-type 'plist)
              (eq? file-type 'powershell)
              (eq? file-type 'pascal)
              (eq? file-type 'rust)
              (eq? file-type 'tex)
              (eq? file-type 'swift)
              (eq? file-type 'zsh))
          color?)
     (case file-type
       [(css)        (render-css-preview-port in
                                              actual-out
                                              #:align? (preview-options-align? options)
                                              #:swatches? (preview-options-swatches? options))]
       [(c)          (render-c-preview-port in actual-out)]
       [(cpp)        (render-cpp-preview-port in actual-out)]
       [(makefile)   (render-makefile-preview-port in actual-out)]
       [(objc)       (render-objc-preview-port in actual-out)]
       [(csv)        (render-csv-preview-port in actual-out)]
       [(go)         (render-go-preview-port in actual-out)]
       [(haskell)    (render-haskell-preview-port in actual-out)]
       [(java)       (render-java-preview-port in actual-out)]
       [(plist)      (render-plist-preview-port in actual-out)]
       [(latex)      (render-latex-preview-port in actual-out)]
       [(bash)       (render-shell-preview-port in actual-out #:shell 'bash)]
       [(powershell) (render-shell-preview-port in actual-out #:shell 'powershell)]
       [(pascal)     (render-pascal-preview-port in actual-out)]
       [(rust)       (render-rust-preview-port in actual-out)]
       [(tex)        (render-tex-preview-port in actual-out)]
       [(swift)      (render-swift-preview-port in actual-out)]
       [(zsh)        (render-shell-preview-port in actual-out #:shell 'zsh)])]
    [(or (eq? file-type 'bash)
         (eq? file-type 'css)
         (eq? file-type 'c)
         (eq? file-type 'cpp)
         (eq? file-type 'makefile)
         (eq? file-type 'objc)
         (eq? file-type 'csv)
         (eq? file-type 'go)
         (eq? file-type 'haskell)
         (eq? file-type 'java)
         (eq? file-type 'plist)
         (eq? file-type 'powershell)
         (eq? file-type 'pascal)
         (eq? file-type 'rust)
         (eq? file-type 'tex)
         (eq? file-type 'swift)
         (eq? file-type 'zsh))
     (copy-port in actual-out)]
    [(and (eq? file-type 'wat)
          color?)
     (render-wat-preview-port in actual-out)]
    [(eq? file-type 'wat)
     (copy-port in actual-out)]
    [(and (eq? file-type 'rkt)
          color?)
     (render-racket-preview-port in actual-out)]
    [(eq? file-type 'rkt)
     (copy-port in actual-out)]
    [(and (eq? file-type 'rhombus)
          color?)
     (render-rhombus-preview-port in actual-out)]
    [(eq? file-type 'rhombus)
     (copy-port in actual-out)]
    [(and (or (eq? file-type 'html)
              (eq? file-type 'java)
              (eq? file-type 'js)
              (eq? file-type 'json)
              (eq? file-type 'plist)
              (eq? file-type 'python)
              (eq? file-type 'jsx)
              (eq? file-type 'latex)
              (eq? file-type 'swift)
              (eq? file-type 'md)
              (eq? file-type 'scrbl))
          color?)
     (case file-type
       [(html)  (render-html-preview-port in actual-out)]
       [(java)  (render-java-preview-port in actual-out)]
       [(js)    (render-javascript-preview-port in actual-out)]
       [(json)  (render-json-preview-port in actual-out)]
       [(plist) (render-plist-preview-port in actual-out)]
       [(python) (render-python-preview-port in actual-out)]
       [(jsx)   (render-javascript-preview-port in actual-out #:jsx? #t)]
       [(latex) (render-latex-preview-port in actual-out)]
       [(swift) (render-swift-preview-port in actual-out)]
       [(md)    (render-markdown-preview-port in
                                              actual-out
                                              #:pretty? (preview-options-pretty? options)
                                              #:section (preview-options-section options))]
       [(scrbl) (render-scribble-preview-port in actual-out)])]
    [(and (eq? file-type 'md)
          (preview-options-section options))
     (display (extract-markdown-section (port->string in)
                                        (preview-options-section options))
              actual-out)]
    [(or (eq? file-type 'html)
         (eq? file-type 'js)
         (eq? file-type 'json)
         (eq? file-type 'plist)
         (eq? file-type 'python)
         (eq? file-type 'jsx)
         (eq? file-type 'latex)
         (eq? file-type 'swift)
         (eq? file-type 'scrbl))
     (copy-port in actual-out)]
    [(eq? file-type 'md)
     (copy-port in actual-out)]
    [(and (eq? file-type 'tsv)
          color?)
     (render-tsv-preview-port in actual-out)]
    [(eq? file-type 'tsv)
     (copy-port in actual-out)]
    [(and (eq? file-type 'yaml)
          color?)
     (render-yaml-preview-port in actual-out)]
    [(eq? file-type 'yaml)
     (copy-port in actual-out)]
    [else
     (define source-bytes
       (port->bytes in))
     (define source
       (bytes->text-or-false source-bytes))
     (define archive-rendered
       (render-archive-preview source-bytes
                               #:path maybe-path
                               #:color? color?))
     (cond
       [archive-rendered
        (display archive-rendered actual-out)]
       [(or (likely-binary-bytes? source-bytes)
            (not source))
        (display (render-binary-preview source-bytes
                                        #:color? color?
                                        #:bits? (eq? (preview-options-binary-mode options)
                                                     'bits)
                                        #:search-bytes (preview-options-search-bytes options))
                 actual-out)]
       [else
        (display source actual-out)])])
   (unless (eq? actual-out out)
     (close-output-port actual-out))))

;; preview-file : path-string? preview-options? -> string?
;;   Preview a file from disk.
(define (preview-path-port path
                           [options (make-preview-options)]
                           [out (current-output-port)])
  (define color?
    (color-enabled? out options))
  (define file-type
    (effective-file-type path options))
  (begin0
   (cond
    [(preview-options-diff? options)
     (display (render-diff-preview path options out) out)]
    [(directory-exists? path)
     (define actual-out
       (maybe-wrap-grep-output-port
        (maybe-wrap-line-number-output-port out path options)
        color?
        options))
     (display (render-directory-preview path
                                        #:color? color?
                                        #:sort-mode (preview-options-directory-sort options))
              actual-out)]
    [(or (eq? file-type 'archive)
         (eq? file-type 'binary))
     (display (preview-file path options out) out)]
    [else
     (call-with-input-file path
       (lambda (in)
         (preview-port in path options out)))] )
   (void)))

;; preview-file : path-string? preview-options? -> string?
;;   Preview a file from disk.
(define (preview-file path
                      [options (make-preview-options)]
                      [out (current-output-port)])
  (define file-type
    (effective-file-type path options))
  (define color?
    (color-enabled? out options))
  (cond
    [(preview-options-diff? options)
     (render-diff-preview path options out)]
    [(directory-exists? path)
     (define rendered
       (render-directory-preview path
                                 #:color? color?
                                 #:sort-mode (preview-options-directory-sort options)))
     (postprocess-rendered-string rendered path color? options)]
    [(eq? file-type 'archive)
     (define source-bytes
       (file->bytes path))
     (define rendered
       (or (render-archive-preview source-bytes
                                   #:path path
                                   #:color? color?)
           (render-binary-preview source-bytes
                                  #:color? color?
                                  #:bits? (eq? (preview-options-binary-mode options)
                                               'bits)
                                  #:search-bytes (preview-options-search-bytes options))))
     (postprocess-rendered-string rendered path color? options)]
    [(eq? file-type 'binary)
     (define rendered
       (open-output-string))
     (call-with-input-file path
       (lambda (in)
         (render-binary-preview-port in
                                     rendered
                                     #:color? color?
                                     #:bits? (eq? (preview-options-binary-mode options)
                                                  'bits)
                                     #:search-bytes (preview-options-search-bytes options)))
       #:mode 'binary)
     (define text
       (get-output-string rendered))
     (postprocess-rendered-string text path color? options)]
    [(or (eq? file-type 'wat)
         (eq? file-type 'css)
         (eq? file-type 'c)
         (eq? file-type 'cpp)
         (eq? file-type 'objc)
         (eq? file-type 'makefile)
         (eq? file-type 'csv)
         (eq? file-type 'go)
         (eq? file-type 'haskell)
         (eq? file-type 'java)
         (eq? file-type 'bash)
         (eq? file-type 'powershell)
         (eq? file-type 'pascal)
         (eq? file-type 'rhombus)
         (eq? file-type 'zsh)
         (eq? file-type 'rkt)
         (eq? file-type 'html)
         (eq? file-type 'java)
         (eq? file-type 'js)
         (eq? file-type 'json)
         (eq? file-type 'plist)
         (eq? file-type 'latex)
         (eq? file-type 'tex)
         (eq? file-type 'python)
         (eq? file-type 'jsx)
         (eq? file-type 'rust)
         (eq? file-type 'tex)
         (eq? file-type 'swift)
         (eq? file-type 'md)
         (eq? file-type 'yaml)
         (eq? file-type 'tsv)
         (eq? file-type 'scrbl))
     (define rendered
       (open-output-string))
     (call-with-input-file path
       (lambda (in)
         (preview-port in path options rendered)))
     (get-output-string rendered)]
    [else
     (define source-bytes
       (file->bytes path))
     (define source
       (bytes->text-or-false source-bytes))
     (define archive-rendered
       (render-archive-preview source-bytes
                               #:path path
                               #:color? color?))
     (cond
       [archive-rendered
        (postprocess-rendered-string archive-rendered path color? options)]
       [(or (likely-binary-bytes? source-bytes)
            (not source))
        (define rendered
          (render-binary-preview source-bytes
                                 #:color? color?
                                 #:bits? (eq? (preview-options-binary-mode options)
                                              'bits)
                                 #:search-bytes (preview-options-search-bytes options)))
        (postprocess-rendered-string rendered path color? options)]
       [else
        (postprocess-rendered-string source path color? options)])]))
