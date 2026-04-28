#lang racket/base

;;;
;;; Directory Preview
;;;
;;
;; Flat, ls-like preview rendering for directory paths.

;; render-directory-preview -- Render a directory listing with simple kind-aware styling.

(provide
 ;; render-directory-preview  Render a flat directory listing.
 render-directory-preview)

(require racket/file
         racket/list
         racket/path
         racket/string
         "common-style.rkt")

(struct directory-entry (name display-name kind size target executable?) #:transparent)

;; styled : boolean? string? string? -> string?
;;   Optionally wrap text in ANSI styling.
(define (styled color? style text)
  (if color?
      (string-append style text ansi-reset)
      text))

;; entry-rank : symbol? -> exact-nonnegative-integer?
;;   Sort directories first, then links, then regular files.
(define (entry-rank kind)
  (case kind
    [(directory) 0]
    [(link)      1]
    [else        2]))

;; entry-style : directory-entry? -> string?
;;   Choose an ANSI style for a directory entry.
(define (entry-style entry)
  (case (directory-entry-kind entry)
    [(directory) ansi-keyword]
    [(link)      ansi-comment]
    [else
     (if (directory-entry-executable? entry)
         ansi-builtin
         ansi-identifier)]))

;; executable-file? : path-string? -> boolean?
;;   Recognize executable regular files on Unix-like systems.
(define (executable-file? path)
  (with-handlers ([exn:fail? (lambda (_exn) #f)])
    (define perms
      (file-or-directory-permissions path))
    (and (list? perms)
         (ormap (lambda (flag)
                  (memq flag perms))
                '(execute execute-bit user-execute group-execute other-execute)))))

;; link-target-string : path-string? -> (or/c string? #f)
;;   Resolve a symlink target for display when possible.
(define (link-target-string path)
  (with-handlers ([exn:fail? (lambda (_exn) #f)])
    (path->string (resolve-path path))))

;; pad-right : string? exact-nonnegative-integer? -> string?
;;   Pad a string on the right with spaces to a target width.
(define (pad-right text width)
  (define missing
    (- width (string-length text)))
  (cond
    [(positive? missing)
     (string-append text (make-string missing #\space))]
    [else
     text]))

;; pad-left : string? exact-nonnegative-integer? -> string?
;;   Pad a string on the left with spaces to a target width.
(define (pad-left text width)
  (define missing
    (- width (string-length text)))
  (cond
    [(positive? missing)
     (string-append (make-string missing #\space) text)]
    [else
     text]))

;; collect-directory-entries : path-string? -> (listof directory-entry?)
;;   Read and classify directory entries for display.
(define (collect-directory-entries path)
  (for/list ([name (in-list (directory-list path))])
    (define full-path
      (build-path path name))
    (define kind
      (file-or-directory-type full-path #t))
    (define display-name
      (case kind
        [(directory) (string-append (path->string name) "/")]
        [else        (path->string name)]))
    (directory-entry name
                     display-name
                     kind
                     (and (eq? kind 'file) (file-size full-path))
                     (and (eq? kind 'link) (link-target-string full-path))
                     (and (eq? kind 'file) (executable-file? full-path)))))

;; entry-name< ? : directory-entry? directory-entry? -> boolean?
;;   Compare entries by visible name.
(define (entry-name<? a b)
  (string-ci<? (directory-entry-display-name a)
               (directory-entry-display-name b)))

;; file-kind-key : directory-entry? -> string?
;;   Compute a grouping key for file-kind sorting.
(define (file-kind-key entry)
  (case (directory-entry-kind entry)
    [(directory) ""]
    [(link) "~link"]
    [else
     (define name
       (path->string (directory-entry-name entry)))
     (define match
       (regexp-match #px"(?i:(\\.[^.]+))$" name))
     (cond
       [match
        (string-downcase (cadr match))]
       [else
        "~none"])]))

;; sort-directory-entries : (listof directory-entry?) symbol? -> (listof directory-entry?)
;;   Sort entries by the selected directory sort mode.
(define (sort-directory-entries entries sort-mode)
  (sort entries
        (lambda (a b)
          (define rank-a
            (entry-rank (directory-entry-kind a)))
          (define rank-b
            (entry-rank (directory-entry-kind b)))
          (case sort-mode
            [(size)
             (or (< rank-a rank-b)
                 (and (= rank-a rank-b)
                      (or (> (or (directory-entry-size a) -1)
                             (or (directory-entry-size b) -1))
                          (and (= (or (directory-entry-size a) -1)
                                  (or (directory-entry-size b) -1))
                               (entry-name<? a b)))))]
            [else
             (or (< rank-a rank-b)
                 (and (= rank-a rank-b)
                      (or (string-ci<? (file-kind-key a)
                                       (file-kind-key b))
                          (and (string-ci=? (file-kind-key a)
                                            (file-kind-key b))
                               (entry-name<? a b)))))]))))

;; size-field-width : (listof directory-entry?) -> exact-nonnegative-integer?
;;   Compute the width needed for right-aligned file sizes.
(define (size-field-width entries)
  (for/fold ([width 0])
            ([entry (in-list entries)])
    (cond
      [(directory-entry-size entry)
       (max width
            (string-length (number->string (directory-entry-size entry))))]
      [else
       width])))

;; name-field-width : (listof directory-entry?) -> exact-nonnegative-integer?
;;   Compute the width of the visible entry-name column.
(define (name-field-width entries)
  (for/fold ([width 0])
            ([entry (in-list entries)])
    (max width
         (string-length (directory-entry-display-name entry)))))

;; render-entry-line : directory-entry? exact-nonnegative-integer? exact-nonnegative-integer? boolean? -> string?
;;   Render one directory entry.
(define (render-entry-line entry name-width size-width color?)
  (define padded-name
    (if (directory-entry-size entry)
        (pad-right (directory-entry-display-name entry)
                   name-width)
        (directory-entry-display-name entry)))
  (define styled-name
    (styled color?
            (entry-style entry)
            padded-name))
  (cond
    [(directory-entry-target entry)
     (string-append styled-name
                    " "
                    (styled color? ansi-delimiter "->")
                    " "
                    (directory-entry-target entry))]
    [(directory-entry-size entry)
     (string-append styled-name
                    " "
                    (styled color? ansi-comment "(")
                    (styled color?
                            ansi-comment
                            (pad-left (number->string (directory-entry-size entry))
                                      size-width))
                    (styled color? ansi-comment " bytes)"))]
    [else
     styled-name]))

;; group-boundary? : (or/c directory-entry? #f) directory-entry? symbol? -> boolean?
;;   Decide whether a blank-line divider should appear before the current entry.
(define (group-boundary? previous entry sort-mode)
  (and previous
       (or (not (= (entry-rank (directory-entry-kind previous))
                   (entry-rank (directory-entry-kind entry))))
           (and (eq? sort-mode 'kind)
                (string-ci=? (file-kind-key previous)
                             (file-kind-key entry))
                #f)
           (and (eq? sort-mode 'kind)
                (= (entry-rank (directory-entry-kind previous))
                   (entry-rank (directory-entry-kind entry)))
                (not (string-ci=? (file-kind-key previous)
                                  (file-kind-key entry)))))))

;; render-directory-preview : path-string? #:color? boolean? #:sort-mode symbol? -> string?
;;   Render a directory listing.
(define (render-directory-preview path
                                  #:color? [color? #t]
                                  #:sort-mode [sort-mode 'kind])
  (define entries
    (sort-directory-entries (collect-directory-entries path)
                            sort-mode))
  (cond
    [(null? entries)
     (styled color? ansi-comment "(empty directory)\n")]
    [else
     (define name-width
       (name-field-width entries))
     (define size-width
       (size-field-width entries))
     (define rendered-lines
       (let loop ([rest entries]
                  [previous #f]
                  [acc '()])
         (cond
           [(null? rest)
            (reverse acc)]
           [else
            (define entry
              (car rest))
            (define next-acc
              (cons (render-entry-line entry name-width size-width color?)
                    (if (group-boundary? previous entry sort-mode)
                        (cons "" acc)
                        acc)))
            (loop (cdr rest)
                  entry
                  next-acc)])))
     (string-append
      (string-join rendered-lines "\n")
      "\n")]))
