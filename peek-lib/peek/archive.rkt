#lang racket/base

;;;
;;; Archive Preview
;;;
;;
;; Tree-style preview rendering for archive input.

;; render-archive-preview : bytes? ... -> (or/c string? #f)
;;   Render archive bytes as a tree preview when the format is recognized.
;; render-archive-preview-port : input-port? output-port? ... -> boolean?
;;   Render archive data from a port and report whether previewing succeeded.
;; likely-archive-bytes? : bytes? -> boolean?
;;   Heuristically decide whether a byte string looks like a supported archive.

(provide
 ;; render-archive-preview : bytes? #:path (or/c path-string? #f) #:color? boolean? -> (or/c string? #f)
 ;;   Render bytes as an archive tree when possible.
 render-archive-preview
 ;; render-archive-preview-port : input-port? output-port? #:path (or/c path-string? #f) #:color? boolean? -> boolean?
 ;;   Render archive data from a port and report success.
 render-archive-preview-port
 ;; likely-archive-bytes? : bytes? -> boolean?
 ;;   Recognize likely archive bytes.
 likely-archive-bytes?)

(require file/unzip
         file/gunzip
         file/untar
         file/untgz
         racket/file
         racket/list
         racket/path
         racket/port
         racket/string
         "common-style.rkt")

(struct archive-entry (segments kind size target) #:transparent)
(struct tree-node (name kind children size target) #:mutable #:transparent)

;; styled : boolean? string? string? -> string?
;;   Optionally wrap text in ANSI styling.
(define (styled color? style text)
  (if color?
      (string-append style text ansi-reset)
      text))

;; zip-signature? : bytes? -> boolean?
;;   Recognize a ZIP local/central directory signature.
(define (zip-signature? bs)
  (and (>= (bytes-length bs) 4)
       (= (bytes-ref bs 0) #x50)
       (= (bytes-ref bs 1) #x4B)
       (memv (bytes-ref bs 2) '(#x03 #x05 #x07))
       (memv (bytes-ref bs 3) '(#x04 #x06 #x08))))

;; gzip-signature? : bytes? -> boolean?
;;   Recognize a gzip stream header.
(define (gzip-signature? bs)
  (and (>= (bytes-length bs) 2)
       (= (bytes-ref bs 0) #x1F)
       (= (bytes-ref bs 1) #x8B)))

;; tar-signature? : bytes? -> boolean?
;;   Recognize a USTAR header signature.
(define (tar-signature? bs)
  (and (>= (bytes-length bs) 262)
       (bytes=? (subbytes bs 257 262) #"ustar")))

;; likely-archive-bytes? : bytes? -> boolean?
;;   Decide whether bytes look like a supported archive.
(define (likely-archive-bytes? bs)
  (or (zip-signature? bs)
      (tar-signature? bs)
      (gzip-signature? bs)))

;; archive-format-from-path : (or/c path-string? #f) -> (or/c symbol? #f)
;;   Infer a supported archive format from a path.
(define (archive-format-from-path maybe-path)
  (cond
    [(not maybe-path) #f]
    [else
     (define path-string
       (path->string (simple-form-path maybe-path)))
     (cond
       [(regexp-match? #px"(?i:\\.zip)$" path-string) 'zip]
       [(regexp-match? #px"(?i:\\.tar)$" path-string) 'tar]
       [(regexp-match? #px"(?i:\\.(?:tar\\.gz|tgz))$" path-string) 'tgz]
       [else #f])]))

;; archive-candidate-formats : bytes? (or/c path-string? #f) -> (listof symbol?)
;;   Choose archive parsers to try, in order.
(define (archive-candidate-formats bs maybe-path)
  (define by-path
    (archive-format-from-path maybe-path))
  (cond
    [by-path
     (remove-duplicates
      (cons by-path
            (append (if (zip-signature? bs) '(zip) '())
                    (if (tar-signature? bs) '(tar) '())
                    (if (gzip-signature? bs) '(tgz) '()))))]
    [else
     (append (if (zip-signature? bs) '(zip) '())
             (if (tar-signature? bs) '(tar) '())
             (if (gzip-signature? bs) '(tgz) '()))]))

;; bytes-path->segments : bytes? -> (listof string?)
;;   Split a ZIP entry path into display segments.
(define (bytes-path->segments bstr)
  (filter (lambda (piece)
            (not (string=? piece "")))
          (string-split (bytes->string/latin-1 bstr) "/")))

;; path->segments : path? -> (listof string?)
;;   Split a filesystem path into display segments.
(define (path->segments p)
  (for/list ([piece (in-list (explode-path p))]
             #:unless (or (eq? piece 'relative)
                          (eq? piece 'same)))
    (cond
      [(path? piece)   (path->string piece)]
      [(symbol? piece) (symbol->string piece)]
      [else            (format "~a" piece)])))

;; consume-bytes! : input-port? exact-nonnegative-integer? -> void?
;;   Read and discard an exact number of bytes.
(define (consume-bytes! in size)
  (define buffer
    (make-bytes 4096))
  (let loop ([remaining size])
    (unless (zero? remaining)
      (define wanted
        (min remaining (bytes-length buffer)))
      (define got
        (read-bytes! buffer in 0 wanted))
      (unless (and (exact-nonnegative-integer? got)
                   (= got wanted))
        (error 'render-archive-preview "unexpected EOF while scanning archive entry"))
      (loop (- remaining got)))))

;; collect-zip-entries : bytes? -> (listof archive-entry?)
;;   Read ZIP directory entries without inflating file content.
(define (collect-zip-entries bs)
  (define zipdir
    (read-zip-directory (open-input-bytes bs)))
  (for/list ([entry (in-list (zip-directory-entries zipdir))]
             #:when (positive? (bytes-length entry)))
    (define dir?
      (and (positive? (bytes-length entry))
           (= (bytes-ref entry (sub1 (bytes-length entry)))
              (char->integer #\/))))
    (archive-entry (bytes-path->segments (if dir?
                                            (subbytes entry 0 (sub1 (bytes-length entry)))
                                            entry))
                   (if dir? 'directory 'file)
                   #f
                   #f)))

;; collect-tar-entries : bytes? symbol? -> (listof archive-entry?)
;;   Scan TAR-like archive content and collect structural entries.
(define (collect-tar-entries bs format)
  (define entries '())
  (define (record-entry kind path content size _attribs)
    (when (eq? kind 'file)
      (consume-bytes! content size))
    (set! entries
          (cons (archive-entry (path->segments path)
                               kind
                               (and (eq? kind 'file) size)
                               (and (eq? kind 'link) (path->string content)))
                entries))
    null)
  (define (filter-entry _archive-path _dest-path type _size _target _mtime _mode)
    (memq type '(file dir link)))
  ((case format
     [(tar) untar]
     [else  untar])
   (open-input-bytes
    (if (eq? format 'tgz)
        (let ([out (open-output-bytes)])
          (gunzip-through-ports (open-input-bytes bs) out)
          (get-output-bytes out))
        bs))
   #:permissive? #t
   #:filter filter-entry
   #:handle-entry record-entry)
  (reverse entries))

;; collect-archive-entries : bytes? symbol? -> (listof archive-entry?)
;;   Collect archive entries for a specific supported format.
(define (collect-archive-entries bs format)
  (case format
    [(zip) (collect-zip-entries bs)]
    [(tar tgz) (collect-tar-entries bs format)]
    [else (error 'render-archive-preview "unsupported archive format: ~a" format)]))

;; entry-key : archive-entry? -> string?
;;   Produce a stable key for deduplicating entries.
(define (entry-key entry)
  (string-join (archive-entry-segments entry) "/"))

;; add-implied-directories : (listof archive-entry?) -> (listof archive-entry?)
;;   Ensure that parent directories exist as explicit entries.
(define (add-implied-directories entries)
  (define seen
    (make-hash))
  (define all
    '())
  (define (remember! entry)
    (define key
      (entry-key entry))
    (unless (hash-has-key? seen key)
      (hash-set! seen key #t)
      (set! all (cons entry all))))
  (for ([entry (in-list entries)])
    (define segments
      (archive-entry-segments entry))
    (for ([n (in-range 1 (length segments))])
      (remember! (archive-entry (take segments n) 'directory #f #f)))
    (remember! entry))
  (reverse all))

;; build-tree : (listof archive-entry?) -> tree-node?
;;   Build a tree representation from archive entries.
(define (build-tree entries)
  (define root
    (tree-node "" 'directory (make-hash) #f #f))
  (for ([entry (in-list (add-implied-directories entries))])
    (define segments
      (archive-entry-segments entry))
    (when (pair? segments)
      (let loop ([node root]
                 [rest segments])
        (define segment
          (car rest))
        (define last?
          (null? (cdr rest)))
        (define children
          (tree-node-children node))
        (define child
          (hash-ref children
                    segment
                    (lambda ()
                      (define fresh
                        (tree-node segment 'directory (make-hash) #f #f))
                      (hash-set! children segment fresh)
                      fresh)))
        (when last?
          (set-tree-node-kind! child (archive-entry-kind entry))
          (set-tree-node-size! child (archive-entry-size entry))
          (set-tree-node-target! child (archive-entry-target entry)))
        (unless last?
          (set-tree-node-kind! child 'directory))
        (unless last?
          (loop child (cdr rest)))))) 
  root)

;; tree-children : tree-node? -> (listof tree-node?)
;;   Return child nodes sorted for display.
(define (tree-children node)
  (define (kind-rank kind)
    (case kind
      [(directory) 0]
      [(file)      1]
      [(link)      2]
      [else        3]))
  (sort (hash-values (tree-node-children node))
        (lambda (a b)
          (cond
            [(< (kind-rank (tree-node-kind a))
                (kind-rank (tree-node-kind b)))
             #t]
            [(> (kind-rank (tree-node-kind a))
                (kind-rank (tree-node-kind b)))
             #f]
            [else
             (string-ci<? (tree-node-name a)
                          (tree-node-name b))]))))

;; node-base-label : tree-node? -> string?
;;   Render the unstyled label text for one node, without any size suffix.
(define (node-base-label node)
  (case (tree-node-kind node)
    [(directory)
     (string-append (tree-node-name node) "/")]
    [(link)
     (string-append
      (tree-node-name node)
      (if (tree-node-target node)
          (string-append " -> " (tree-node-target node))
          ""))]
    [else
     (tree-node-name node)]))

;; node-base-style : tree-node? -> string?
;;   Choose the primary style for a node label.
(define (node-base-style node)
  (case (tree-node-kind node)
    [(directory) ansi-keyword]
    [(link)      ansi-builtin]
    [else        ansi-identifier]))

;; node-label-width : tree-node? -> exact-nonnegative-integer?
;;   Compute the visible width of a node label before any size suffix.
(define (node-label-width node)
  (string-length (node-base-label node)))

;; node-size-width : tree-node? -> exact-nonnegative-integer?
;;   Compute the width of a node's size in decimal digits.
(define (node-size-width node)
  (cond
    [(tree-node-size node)
     (string-length (number->string (tree-node-size node)))]
    [else
     0]))

;; node-label : tree-node? boolean? exact-nonnegative-integer? exact-nonnegative-integer? -> string?
;;   Render one node label with optional aligned size columns.
(define (node-label node
                    color?
                    [size-column-width 0]
                    [size-value-width 0])
  (define base-text
    (node-base-label node))
  (define padded-base
    (if (tree-node-size node)
        (string-append base-text
                       (make-string (max 0 (- size-column-width
                                              (string-length base-text)))
                                    #\space))
        base-text))
  (define base
    (case (tree-node-kind node)
      [(directory) (styled color? ansi-keyword padded-base)]
      [(link)
       (string-append
        (styled color? ansi-builtin padded-base)
        (if (tree-node-target node)
            (styled color? ansi-comment
                    "")
            ""))]
      [else
       (styled color? ansi-identifier padded-base)]))
  (cond
    [(tree-node-size node)
     (define size-text
       (number->string (tree-node-size node)))
     (string-append base
                    (styled color? ansi-comment
                            (format " (~a bytes)"
                                    (string-append
                                     (make-string (max 0 (- size-value-width
                                                            (string-length size-text)))
                                                  #\space)
                                     size-text))))]
    [else
     base]))

;; append-tree-lines! : tree-node? string? boolean? boolean? exact-nonnegative-integer? exact-nonnegative-integer? (listof string?) -> (listof string?)
;;   Render child lines recursively.
(define (append-tree-lines! node prefix last? color? size-column-width size-value-width lines)
  (define branch
    (styled color? ansi-delimiter
            (if last? "└── " "├── ")))
  (define next-prefix
    (string-append prefix
                   (styled color? ansi-delimiter
                           (if last? "    " "│   "))))
  (define here
    (string-append prefix branch
                   (node-label node color? size-column-width size-value-width)))
  (define children
    (tree-children node))
  (define child-size-column-width
    (for/fold ([max-width 0])
              ([child (in-list children)])
      (if (tree-node-size child)
          (max max-width (node-label-width child))
          max-width)))
  (define child-size-value-width
    (for/fold ([max-width 0])
              ([child (in-list children)])
      (max max-width (node-size-width child))))
  (define with-self
    (append lines (list here)))
  (for/fold ([acc with-self])
            ([child (in-list children)]
             [i (in-naturals)])
    (define child-branch
      (styled color? ansi-delimiter
              (if (= i (sub1 (length children))) "└── " "├── ")))
    (define child-next-prefix
      (string-append next-prefix
                     (styled color? ansi-delimiter
                             (if (= i (sub1 (length children))) "    " "│   "))))
    (define child-line
      (string-append next-prefix
                     child-branch
                     (node-label child
                                 color?
                                 child-size-column-width
                                 child-size-value-width)))
    (define child-children
      (tree-children child))
    (define with-child
      (append acc (list child-line)))
    (for/fold ([acc2 with-child])
              ([grandchild (in-list child-children)]
               [j (in-naturals)])
      (append-tree-lines! grandchild
                          child-next-prefix
                          (= j (sub1 (length child-children)))
                          color?
                          child-size-column-width
                          child-size-value-width
                          acc2))))

;; tree->lines : tree-node? string? boolean? -> (listof string?)
;;   Render a tree to text lines with a root heading.
(define (tree->lines root root-name color?)
  (define children
    (tree-children root))
  (define header
    (styled color? ansi-delimiter root-name))
  (cond
    [(null? children)
     (list header
           (styled color? ansi-comment "(empty archive)"))]
    [else
     (define root-size-column-width
       (for/fold ([max-width 0])
                 ([child (in-list children)])
         (if (tree-node-size child)
             (max max-width (node-label-width child))
             max-width)))
     (define root-size-value-width
       (for/fold ([max-width 0])
                 ([child (in-list children)])
         (max max-width (node-size-width child))))
     (for/fold ([lines (list header)])
               ([child (in-list children)]
                [i (in-naturals)])
       (append-tree-lines! child
                           ""
                           (= i (sub1 (length children)))
                           color?
                           root-size-column-width
                           root-size-value-width
                           lines))]))

;; tree-counts : tree-node? -> (values exact-nonnegative-integer? exact-nonnegative-integer? exact-nonnegative-integer?)
;;   Count directories, files, and links under a tree.
(define (tree-counts root)
  (define (walk node)
    (for/fold ([dirs 0] [files 0] [links 0])
              ([child (in-list (tree-children node))])
      (define-values (sub-dirs sub-files sub-links)
        (walk child))
      (define-values (self-dirs self-files self-links)
        (case (tree-node-kind child)
          [(directory) (values 1 0 0)]
          [(link)      (values 0 0 1)]
          [else        (values 0 1 0)]))
      (values (+ dirs self-dirs sub-dirs)
              (+ files self-files sub-files)
              (+ links self-links sub-links))))
  (walk root))

;; archive-root-name : (or/c path-string? #f) symbol? -> string?
;;   Choose a display name for the archive root.
(define (archive-root-name maybe-path format)
  (cond
    [maybe-path
     (path->string (file-name-from-path (simple-form-path maybe-path)))]
    [else
     (case format
       [(zip) "archive.zip"]
       [(tar) "archive.tar"]
       [(tgz) "archive.tar.gz"]
       [else  "archive"]) ]))

;; render-summary : tree-node? boolean? -> string?
;;   Render a short archive summary line.
(define (render-summary root color?)
  (define-values (dirs files links)
    (tree-counts root))
  (styled color?
          ansi-comment
          (string-append
           (format "~a director~a, ~a file~a"
                   dirs
                   (if (= dirs 1) "y" "ies")
                   files
                   (if (= files 1) "" "s"))
           (if (zero? links)
               ""
               (format ", ~a link~a"
                       links
                       (if (= links 1) "" "s"))))))

;; render-archive-preview : bytes? #:path (or/c path-string? #f) #:color? boolean? -> (or/c string? #f)
;;   Render archive bytes as a tree preview when the format is recognized.
(define (render-archive-preview bs
                                #:path [maybe-path #f]
                                #:color? [color? #t])
  (let loop ([formats (archive-candidate-formats bs maybe-path)])
    (cond
      [(null? formats) #f]
      [else
       (define format
         (car formats))
       (define maybe-rendered
         (with-handlers ([exn:fail? (lambda (_) #f)])
           (define entries
             (collect-archive-entries bs format))
           (define root
             (build-tree entries))
           (string-append
            (string-join (tree->lines root
                                      (archive-root-name maybe-path format)
                                      color?)
                         "\n")
            "\n\n"
            (render-summary root color?)
            "\n")))
       (or maybe-rendered
           (loop (cdr formats)))])))

;; render-archive-preview-port : input-port? output-port? #:path (or/c path-string? #f) #:color? boolean? -> boolean?
;;   Render archive data from a port and report whether previewing succeeded.
(define (render-archive-preview-port in
                                     out
                                     #:path [maybe-path #f]
                                     #:color? [color? #t])
  (define rendered
    (render-archive-preview (port->bytes in)
                            #:path maybe-path
                            #:color? color?))
  (and rendered
       (begin
         (display rendered out)
         #t)))
