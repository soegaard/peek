#lang racket/base

;;;
;;; Git Diff
;;;
;;
;; Helpers for discovering changed line ranges and hunk bodies from Git.

;; git-diff-hunk                   -- One changed hunk in working-tree line space.
;; git-diff-hunk?                  -- Recognize Git diff hunks.
;; git-diff-hunk-start             -- First changed line number in the working tree.
;; git-diff-hunk-count             -- Number of changed working-tree lines.
;; git-diff-line                   -- One parsed line from a unified diff hunk.
;; git-diff-line?                  -- Recognize parsed diff lines.
;; git-diff-render-hunk            -- One parsed unified diff hunk with visible lines.
;; git-diff-render-hunk?           -- Recognize parsed render hunks.
;; git-diff-slice                  -- One expanded preview slice.
;; git-diff-slice?                 -- Recognize preview slices.
;; git-diff-slice-anchor           -- Representative line number for a slice header.
;; git-diff-slice-start            -- First visible line in a slice.
;; git-diff-slice-end              -- Last visible line in a slice.
;; parse-git-diff-hunks            -- Parse unified-diff hunk headers.
;; git-working-tree-hunks          -- Ask Git for changed hunks for one file.
;; parse-git-diff-render-hunks     -- Parse unified-diff hunk bodies.
;; git-working-tree-render-hunks   -- Ask Git for parsed render hunks.
;; expand-git-diff-hunks           -- Add context and merge overlapping hunks.

(provide
 ;; git-diff-hunk : exact-positive-integer? exact-nonnegative-integer? -> git-diff-hunk?
 ;;   One changed hunk in working-tree line space.
 git-diff-hunk
 ;; git-diff-hunk? : any/c -> boolean?
 ;;   Recognize Git diff hunks.
 git-diff-hunk?
 ;; git-diff-hunk-start : git-diff-hunk? -> exact-positive-integer?
 ;;   First changed line number in the working tree.
 git-diff-hunk-start
 ;; git-diff-hunk-count : git-diff-hunk? -> exact-nonnegative-integer?
 ;;   Number of changed working-tree lines.
 git-diff-hunk-count
 ;; git-diff-line : symbol? (or/c exact-positive-integer? #f) (or/c exact-positive-integer? #f) string? -> git-diff-line?
 ;;   One parsed unified-diff line.
 git-diff-line
 ;; git-diff-line? : any/c -> boolean?
 ;;   Recognize parsed diff lines.
 git-diff-line?
 ;; git-diff-line-kind : git-diff-line? -> symbol?
 ;;   Kind of diff line: context, added, or removed.
 git-diff-line-kind
 ;; git-diff-line-old-line-no : git-diff-line? -> (or/c exact-positive-integer? #f)
 ;;   Old-file line number when present.
 git-diff-line-old-line-no
 ;; git-diff-line-new-line-no : git-diff-line? -> (or/c exact-positive-integer? #f)
 ;;   New-file line number when present.
 git-diff-line-new-line-no
 ;; git-diff-line-text : git-diff-line? -> string?
 ;;   Line text without diff prefix.
 git-diff-line-text
 ;; git-diff-render-hunk : exact-positive-integer? (listof git-diff-line?) -> git-diff-render-hunk?
 ;;   One parsed unified-diff hunk.
 git-diff-render-hunk
 ;; git-diff-render-hunk? : any/c -> boolean?
 ;;   Recognize parsed render hunks.
 git-diff-render-hunk?
 ;; git-diff-render-hunk-anchor : git-diff-render-hunk? -> exact-positive-integer?
 ;;   Representative line number for the hunk header.
 git-diff-render-hunk-anchor
 ;; git-diff-render-hunk-lines : git-diff-render-hunk? -> (listof git-diff-line?)
 ;;   Visible lines in the parsed hunk.
 git-diff-render-hunk-lines
 ;; git-diff-slice : exact-positive-integer? exact-positive-integer? exact-nonnegative-integer? -> git-diff-slice?
 ;;   One expanded preview slice.
 git-diff-slice
 ;; git-diff-slice? : any/c -> boolean?
 ;;   Recognize preview slices.
 git-diff-slice?
 ;; git-diff-slice-anchor : git-diff-slice? -> exact-positive-integer?
 ;;   Representative line number for a slice header.
 git-diff-slice-anchor
 ;; git-diff-slice-start : git-diff-slice? -> exact-positive-integer?
 ;;   First visible line in a slice.
 git-diff-slice-start
 ;; git-diff-slice-end : git-diff-slice? -> exact-nonnegative-integer?
 ;;   Last visible line in a slice.
 git-diff-slice-end
 ;; parse-git-diff-hunks : string? -> (listof git-diff-hunk?)
 ;;   Parse unified-diff hunk headers from text.
 parse-git-diff-hunks
 ;; git-working-tree-hunks : path-string? -> (listof git-diff-hunk?)
 ;;   Ask Git for working-tree hunks for one file.
 git-working-tree-hunks
 ;; parse-git-diff-render-hunks : string? -> (listof git-diff-render-hunk?)
 ;;   Parse unified-diff hunk bodies into visible lines.
 parse-git-diff-render-hunks
 ;; git-working-tree-render-hunks : path-string? -> (listof git-diff-render-hunk?)
 ;;   Ask Git for parsed render hunks for one file.
 git-working-tree-render-hunks
 ;; expand-git-diff-hunks : (listof git-diff-hunk?) exact-nonnegative-integer? exact-nonnegative-integer? -> (listof git-diff-slice?)
 ;;   Add context and merge overlapping diff hunks.
 expand-git-diff-hunks)

(require racket/file
         racket/list
         racket/path
         racket/port
         racket/string
         racket/system)

(struct git-diff-hunk (start count) #:transparent)
(struct git-diff-line (kind old-line-no new-line-no text) #:transparent)
(struct git-diff-render-hunk (anchor lines) #:transparent)
(struct git-diff-slice (anchor start end) #:transparent)

;; parse-hunk-line : string? -> (or/c git-diff-hunk? #f)
;;   Parse one unified-diff hunk header.
(define (parse-hunk-line line)
  (cond
    [(regexp-match #px"^@@ -[0-9]+(?:,[0-9]+)? \\+([0-9]+)(?:,([0-9]+))? @@"
                   line)
     =>
     (lambda (match)
       (define start
         (string->number (list-ref match 1)))
       (define maybe-count
         (list-ref match 2))
       (define count
         (cond
           [maybe-count
            (string->number maybe-count)]
           [else
            1]))
       (and (exact-positive-integer? start)
            (exact-nonnegative-integer? count)
            (git-diff-hunk start count)))]
    [else
     #f]))

;; parse-git-diff-hunks : string? -> (listof git-diff-hunk?)
;;   Parse unified-diff hunk headers from text.
(define (parse-git-diff-hunks text)
  (for/list ([line (in-list (string-split text "\n"))]
             #:when (parse-hunk-line line))
    (parse-hunk-line line)))

;; path-directory+name : path-string? -> (values path-string? path-string?)
;;   Split a target path into a Git working directory and relative basename.
(define (path-directory+name target-path)
  (define simple
    (simple-form-path target-path))
  (define file-name
    (file-name-from-path simple))
  (define parent
    (or (path-only simple)
        (current-directory)))
  (values (path->string (simple-form-path parent))
          (if file-name
              (path->string file-name)
              (path->string simple))))

;; git-command-output : path-string? exact-nonnegative-integer? -> string?
;;   Run `git diff` with the requested context for one file and capture stdout.
(define (git-command-output target-path unified)
  (define git-path
    (find-executable-path "git"))
  (unless git-path
    (raise-user-error 'git-diff "could not find `git` on PATH"))
  (define-values (directory file-name)
    (path-directory+name target-path))
  (define-values (proc stdout stdin stderr)
    (subprocess #f
                #f
                #f
                git-path
                "-C"
                directory
                "diff"
                "--no-ext-diff"
                "--no-color"
                (format "--unified=~a" unified)
                "--"
                file-name))
  (close-output-port stdin)
  (define output
    (port->string stdout))
  (define error-output
    (string-trim (port->string stderr)))
  (subprocess-wait proc)
  (define status
    (subprocess-status proc))
  (close-input-port stdout)
  (close-input-port stderr)
  (cond
    [(zero? status)
     output]
    [else
     (raise-user-error 'git-diff
                       (if (string=? error-output "")
                           (format "git diff failed for ~a" target-path)
                           error-output))]))

;; git-working-tree-hunks : path-string? -> (listof git-diff-hunk?)
;;   Ask Git for working-tree hunks for one file.
(define (git-working-tree-hunks target-path)
  (parse-git-diff-hunks (git-command-output target-path 0)))

;; parse-render-hunk-header : string? -> (or/c (vector exact-positive-integer? exact-nonnegative-integer? exact-positive-integer? exact-nonnegative-integer?) #f)
;;   Parse one unified-diff hunk header into old/new coordinates.
(define (parse-render-hunk-header line)
  (cond
    [(regexp-match #px"^@@ -([0-9]+)(?:,([0-9]+))? \\+([0-9]+)(?:,([0-9]+))? @@"
                   line)
     =>
     (lambda (match)
       (define old-start
         (string->number (list-ref match 1)))
       (define old-count
         (let ([raw (list-ref match 2)])
           (if raw
               (string->number raw)
               1)))
       (define new-start
         (string->number (list-ref match 3)))
       (define new-count
         (let ([raw (list-ref match 4)])
           (if raw
               (string->number raw)
               1)))
       (and (exact-positive-integer? old-start)
            (exact-nonnegative-integer? old-count)
            (exact-positive-integer? new-start)
            (exact-nonnegative-integer? new-count)
            (vector old-start old-count new-start new-count)))]
    [else
     #f]))

;; diff-hunk-anchor : exact-positive-integer? (listof git-diff-line?) -> exact-positive-integer?
;;   Choose a representative line number for a parsed render hunk.
(define (diff-hunk-anchor fallback lines)
  (cond
    [(for/or ([line (in-list lines)])
       (and (git-diff-line-new-line-no line)
            (not (eq? (git-diff-line-kind line) 'removed))
            (git-diff-line-new-line-no line)))
     =>
     values]
    [(for/or ([line (in-list lines)])
       (git-diff-line-old-line-no line))
     =>
     values]
    [else
     fallback]))

;; parse-git-diff-render-hunks : string? -> (listof git-diff-render-hunk?)
;;   Parse unified-diff hunk bodies into visible lines.
(define (parse-git-diff-render-hunks text)
  (define raw-lines
    (string-split text "\n"))
  (let loop ([remaining raw-lines]
             [current-header #f]
             [old-line-no #f]
             [new-line-no #f]
             [current-lines '()]
             [hunks '()])
    (define (finish-current rest hunks*)
      (cond
        [current-header
         (loop rest
               #f
               #f
               #f
               '()
               (cons (git-diff-render-hunk
                      (diff-hunk-anchor (vector-ref current-header 2)
                                        (reverse current-lines))
                      (reverse current-lines))
                     hunks*))]
        [else
         (loop rest #f #f #f '() hunks*)]))
    (cond
      [(null? remaining)
       (reverse
        (if current-header
            (cons (git-diff-render-hunk
                   (diff-hunk-anchor (vector-ref current-header 2)
                                     (reverse current-lines))
                   (reverse current-lines))
                  hunks)
            hunks))]
      [else
       (define line
         (car remaining))
       (cond
         [(parse-render-hunk-header line)
          =>
          (lambda (header)
            (if current-header
                (loop remaining #f #f #f '() (cons (git-diff-render-hunk
                                                    (diff-hunk-anchor (vector-ref current-header 2)
                                                                      (reverse current-lines))
                                                    (reverse current-lines))
                                                   hunks))
                (loop (cdr remaining)
                      header
                      (vector-ref header 0)
                      (vector-ref header 2)
                      '()
                      hunks)))]
         [(not current-header)
          (loop (cdr remaining) #f #f #f '() hunks)]
         [(string-prefix? line "\\ No newline at end of file")
          (loop (cdr remaining)
                current-header
                old-line-no
                new-line-no
                current-lines
                hunks)]
         [(and (positive? (string-length line))
               (char=? (string-ref line 0) #\space))
          (loop (cdr remaining)
                current-header
                (and old-line-no (add1 old-line-no))
                (and new-line-no (add1 new-line-no))
                (cons (git-diff-line 'context
                                     old-line-no
                                     new-line-no
                                     (substring line 1))
                      current-lines)
                hunks)]
         [(and (positive? (string-length line))
               (char=? (string-ref line 0) #\+))
          (loop (cdr remaining)
                current-header
                old-line-no
                (and new-line-no (add1 new-line-no))
                (cons (git-diff-line 'added
                                     #f
                                     new-line-no
                                     (substring line 1))
                      current-lines)
                hunks)]
         [(and (positive? (string-length line))
               (char=? (string-ref line 0) #\-))
          (loop (cdr remaining)
                current-header
                (and old-line-no (add1 old-line-no))
                new-line-no
                (cons (git-diff-line 'removed
                                     old-line-no
                                     #f
                                     (substring line 1))
                      current-lines)
                hunks)]
         [else
          (finish-current (cdr remaining) hunks)])])))

;; git-working-tree-render-hunks : path-string? -> (listof git-diff-render-hunk?)
;;   Ask Git for parsed render hunks for one file.
(define (git-working-tree-render-hunks target-path)
  (parse-git-diff-render-hunks (git-command-output target-path 2)))

;; hunk-anchor-line : git-diff-hunk? exact-nonnegative-integer? -> exact-positive-integer?
;;   Choose the representative line number for a hunk.
(define (hunk-anchor-line hunk line-count)
  (define start
    (git-diff-hunk-start hunk))
  (cond
    [(zero? line-count)
     1]
    [else
     (min line-count
          (max 1 start))]))

;; hunk-visible-end : git-diff-hunk? exact-positive-integer? exact-nonnegative-integer? -> exact-positive-integer?
;;   Choose the last visible changed line for a hunk before context expansion.
(define (hunk-visible-end hunk anchor line-count)
  (define count
    (git-diff-hunk-count hunk))
  (cond
    [(zero? line-count)
     0]
    [(positive? count)
     (min line-count
          (+ (git-diff-hunk-start hunk)
             count
             -1))]
    [else
     anchor]))

;; expand-git-diff-hunks : (listof git-diff-hunk?) exact-nonnegative-integer? exact-nonnegative-integer? -> (listof git-diff-slice?)
;;   Add context and merge overlapping diff hunks.
(define (expand-git-diff-hunks hunks line-count context-lines)
  (define raw-slices
    (for/list ([hunk (in-list hunks)])
      (define anchor
        (hunk-anchor-line hunk line-count))
      (define visible-end
        (hunk-visible-end hunk anchor line-count))
      (git-diff-slice anchor
                      (if (zero? line-count)
                          1
                          (max 1 (- anchor context-lines)))
                      (if (zero? line-count)
                          0
                          (min line-count
                               (+ visible-end context-lines))))))
  (if (null? raw-slices)
      '()
      (let loop ([current (car raw-slices)]
                 [rest    (cdr raw-slices)]
                 [merged  '()])
        (if (null? rest)
            (reverse (cons current merged))
            (let ([next (car rest)])
              (if (<= (git-diff-slice-start next)
                      (add1 (git-diff-slice-end current)))
                  (loop (git-diff-slice (git-diff-slice-anchor current)
                                        (git-diff-slice-start current)
                                        (max (git-diff-slice-end current)
                                             (git-diff-slice-end next)))
                        (cdr rest)
                        merged)
                  (loop next
                        (cdr rest)
                        (cons current merged))))))))
