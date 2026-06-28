#lang racket/base

;;;
;;; Preview Stats
;;;
;;
;; Shared summary data and rendering for directory and archive previews.

;; stats-entry                -- One summarized file-system-like entry.
;; stats-entry?               -- Recognize summarized entries.
;; preview-stats              -- Aggregate summary statistics.
;; preview-stats?             -- Recognize aggregate summary values.
;; directory-path->preview-stats -- Collect recursive stats for one directory path.
;; stats-entries->preview-stats  -- Collect aggregate stats from normalized entries.
;; render-preview-stats       -- Render a compact stats block.

(provide
 ;; stats-entry                 One summarized file-system-like entry.
 (struct-out stats-entry)
 ;; preview-stats              Aggregate summary statistics.
 (struct-out preview-stats)
 ;; directory-path->preview-stats Collect recursive stats for one directory path.
 directory-path->preview-stats
 ;; stats-entries->preview-stats Collect aggregate stats from normalized entries.
 stats-entries->preview-stats
 ;; render-preview-stats       Render a compact stats block.
 render-preview-stats)

(require racket/file
         racket/list
         racket/path
         racket/string
         "common-style.rkt")

(struct stats-entry (path kind size) #:transparent)
(struct preview-stats (directories files links total-bytes largest-files kind-counts) #:transparent)

;; -----------------------------------------------------------------------------
;; Shared helpers

;; top-preview-stats-count : exact-positive-integer?
;;   Maximum number of largest files and file kinds to display.
(define top-preview-stats-count
  5)

;; format-byte-count : exact-nonnegative-integer? -> string?
;;   Render a byte count with a simple human-readable unit.
(define (format-byte-count bytes)
  (cond
    [(< bytes 1024)
     (format "~a B" bytes)]
    [(< bytes (* 1024 1024))
     (format "~a KB"
             (real->decimal-string (/ bytes 1024.0) 1))]
    [(< bytes (* 1024 1024 1024))
     (format "~a MB"
             (real->decimal-string (/ bytes (* 1024.0 1024.0)) 1))]
    [else
     (format "~a GB"
             (real->decimal-string (/ bytes (* 1024.0 1024.0 1024.0)) 1))]))

;; stats-kind-label : string? -> string?
;;   Infer one file-kind label from a path string.
(define (stats-kind-label path-text)
  (define name
    (let ([pieces (string-split path-text "/" #:trim? #f)])
      (if (null? pieces)
          path-text
          (last pieces))))
  (define match
    (regexp-match #px"(?i:\\.([^.]+))$" name))
  (cond
    [match
     (string-downcase (cadr match))]
    [else
     "[no extension]"]))

;; pluralize : exact-nonnegative-integer? string? string? -> string?
;;   Render one singular/plural phrase.
(define (pluralize count singular plural)
  (format "~a ~a"
          count
          (if (= count 1)
              singular
              plural)))

;; take-top-largest-files : (listof stats-entry?) -> (listof stats-entry?)
;;   Sort and trim file entries by descending size.
(define (take-top-largest-files entries)
  (take (sort entries
              (lambda (a b)
                (or (> (or (stats-entry-size a) -1)
                       (or (stats-entry-size b) -1))
                    (and (= (or (stats-entry-size a) -1)
                            (or (stats-entry-size b) -1))
                         (string-ci<? (stats-entry-path a)
                                      (stats-entry-path b))))))
        (min top-preview-stats-count
             (length entries))))

;; count-file-kinds : (listof stats-entry?) -> (listof (cons/c string? exact-nonnegative-integer?))
;;   Count file kinds/extensions for regular files.
(define (count-file-kinds entries)
  (define counts
    (make-hash))
  (for ([entry (in-list entries)])
    (define label
      (stats-kind-label (stats-entry-path entry)))
    (hash-update! counts label add1 0))
  (take (sort (hash->list counts)
              (lambda (a b)
                (or (> (cdr a) (cdr b))
                    (and (= (cdr a) (cdr b))
                         (string-ci<? (car a)
                                      (car b))))))
        (min top-preview-stats-count
             (hash-count counts))))

;; stats-entries->preview-stats : (listof stats-entry?) -> preview-stats?
;;   Collect aggregate stats from normalized entries.
(define (stats-entries->preview-stats entries)
  (define directories
    (count (lambda (entry)
             (eq? (stats-entry-kind entry) 'directory))
           entries))
  (define files
    (count (lambda (entry)
             (eq? (stats-entry-kind entry) 'file))
           entries))
  (define links
    (count (lambda (entry)
             (eq? (stats-entry-kind entry) 'link))
           entries))
  (define file-entries
    (filter (lambda (entry)
              (eq? (stats-entry-kind entry) 'file))
            entries))
  (define total-bytes
    (for/sum ([entry (in-list file-entries)])
      (or (stats-entry-size entry)
          0)))
  (preview-stats directories
                 files
                 links
                 total-bytes
                 (take-top-largest-files file-entries)
                 (count-file-kinds file-entries)))

;; -----------------------------------------------------------------------------
;; Directory collection

;; safe-entry-kind : path-string? -> (or/c symbol? #f)
;;   Read one filesystem entry kind without raising.
(define (safe-entry-kind path)
  (with-handlers ([exn:fail? (lambda (_exn) #f)])
    (file-or-directory-type path #t)))

;; relative-display-path : path-string? path-string? -> string?
;;   Render a path relative to a root directory.
(define (relative-display-path root full-path)
  (path->string (find-relative-path root full-path)))

;; directory-path->preview-stats : path-string? -> preview-stats?
;;   Recursively collect stats for one directory path.
(define (directory-path->preview-stats root-path)
  (define entries
    (let walk ([dir root-path]
               [acc '()])
      (for/fold ([entries acc])
                ([name (in-list (directory-list dir))])
        (define full-path
          (build-path dir name))
        (define kind
          (safe-entry-kind full-path))
        (define relative-path
          (relative-display-path root-path full-path))
        (case kind
          [(directory)
           (walk full-path
                 (cons (stats-entry relative-path 'directory #f)
                       entries))]
          [(link)
           (cons (stats-entry relative-path 'link #f)
                 entries)]
          [(file)
           (cons (stats-entry relative-path
                              'file
                              (with-handlers ([exn:fail? (lambda (_exn) 0)])
                                (file-size full-path)))
                 entries)]
          [else
           entries]))))
  (stats-entries->preview-stats entries))

;; -----------------------------------------------------------------------------
;; Rendering

;; styled : boolean? string? string? -> string?
;;   Optionally wrap text in ANSI styling.
(define (styled color? style text)
  (if color?
      (string-append style text ansi-reset)
      text))

;; pad-right : string? exact-nonnegative-integer? -> string?
;;   Pad a string on the right with spaces to a target width.
(define (pad-right text width)
  (define missing
    (- width (string-length text)))
  (if (positive? missing)
      (string-append text
                     (make-string missing #\space))
      text))

;; render-largest-files : (listof stats-entry?) boolean? -> (listof string?)
;;   Render the largest-file rows.
(define (render-largest-files entries color?)
  (define width
    (for/fold ([max-width 0])
              ([entry (in-list entries)])
      (max max-width
           (string-length (stats-entry-path entry)))))
  (for/list ([entry (in-list entries)])
    (string-append (styled color?
                           ansi-identifier
                           (pad-right (stats-entry-path entry)
                                      width))
                   "  "
                   (styled color?
                           ansi-literal
                           (format-byte-count (or (stats-entry-size entry)
                                                  0))))))

;; render-kind-counts : (listof (cons/c string? exact-nonnegative-integer?)) boolean? -> (listof string?)
;;   Render the file-kind count rows.
(define (render-kind-counts counts color?)
  (define width
    (for/fold ([max-width 0])
              ([entry (in-list counts)])
      (max max-width
           (string-length (car entry)))))
  (for/list ([entry (in-list counts)])
    (string-append (styled color?
                           ansi-identifier
                           (pad-right (car entry)
                                      width))
                   "  "
                   (styled color?
                           ansi-literal
                           (number->string (cdr entry))))))

;; render-preview-stats : preview-stats? boolean? -> string?
;;   Render a compact stats block.
(define (render-preview-stats stats
                              [color? #t])
  (define largest-files
    (preview-stats-largest-files stats))
  (define kind-counts
    (preview-stats-kind-counts stats))
  (string-append
   (styled color? ansi-keyword "Stats")
   "\n"
   (styled color?
           ansi-comment
           (string-append
            (pluralize (preview-stats-directories stats)
                       "directory"
                       "directories")
            ", "
            (pluralize (preview-stats-files stats)
                       "file"
                       "files")
            ", "
            (pluralize (preview-stats-links stats)
                       "link"
                       "links")))
   "\n"
   (styled color?
           ansi-comment
           (format "~a total"
                   (format-byte-count (preview-stats-total-bytes stats))))
   (cond
     [(null? largest-files)
      ""]
     [else
      (string-append
       "\n\n"
       (styled color? ansi-keyword "Largest files")
       "\n"
       (string-join (render-largest-files largest-files color?)
                    "\n"))])
   (cond
     [(null? kind-counts)
      ""]
     [else
      (string-append
       "\n\n"
       (styled color? ansi-keyword "File kinds")
       "\n"
       (string-join (render-kind-counts kind-counts color?)
                    "\n"))])
   "\n"))
