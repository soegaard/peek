#lang racket/base

;;;
;;; webracket Markdown Round-Trip Corpus Test
;;;
;;
;; Round-trip fidelity test for Markdown files copied from the local
;; `../webracket` checkout into `/tmp`.

;; run-webracket-markdown-roundtrip-tests : -> void?
;;   Copy the local `webracket` Markdown corpus to `/tmp` and verify that
;;   previewing with ANSI color and then stripping ANSI yields the exact
;;   original file contents.

(require rackunit
         racket/file
         racket/list
         racket/match
         racket/path
         racket/runtime-path
         (lib "peek/preview.rkt"))

(define-runtime-path peek-root "..")

;; Temporary corpus snapshot root.
(define temp-root
  (build-path "/tmp" "peek-webracket-markdown-roundtrip"))

;; Maximum number of Markdown files to check.
;; #f means "use all files."
(define corpus-limit
  #f)

;; Maximum seconds to spend on one file.
(define per-file-timeout-seconds
  120)

;; ANSI color stripping pattern.
(define ansi-pattern
  #px"\u001b\\[[0-9;]*m")

;; roundtrip-options : preview-options?
;;   Rendering options for round-trip fidelity checks.
(define roundtrip-options
  (make-preview-options #:color-mode 'always))

;; strip-ansi : string? -> string?
;;   Remove ANSI color escapes from preview output.
(define (strip-ansi text)
  (regexp-replace* ansi-pattern text ""))

;; corpus-path? : path-string? -> boolean?
;;   Recognize Markdown corpus files.
(define (corpus-path? path)
  (define text
    (path->string path))
  (regexp-match? #px"(?i:\\.md)$" text))

;; collect-corpus-files : path? -> (listof path?)
;;   Collect Markdown corpus files from one source tree.
(define (collect-corpus-files root)
  (sort (for/list ([path (in-directory root)]
                   #:when (file-exists? path)
                   #:when (corpus-path? path))
          path)
        string<?
        #:key path->string))

;; trim-corpus-files : (listof path?) (or/c exact-nonnegative-integer? #f) -> (listof path?)
;;   Keep the largest Markdown files when a limit is provided.
(define (trim-corpus-files paths limit)
  (define ordered
    (sort paths > #:key file-size))
  (cond
    [(not limit) ordered]
    [else
     (take ordered
           (min limit (length ordered)))]))

;; copy-corpus-file : path? path? path? -> path?
;;   Copy one corpus file to the temp snapshot, preserving relative path.
(define (copy-corpus-file source-root temp-root source-path)
  (define relative
    (find-relative-path source-root source-path))
  (define target
    (build-path temp-root relative))
  (make-directory* (path-only target))
  (copy-file source-path target #t)
  target)

;; copied-corpus-files : path? path? -> (listof path?)
;;   Copy all Markdown corpus files to `/tmp` and return copied paths.
(define (copied-corpus-files source-root temp-root)
  (when (directory-exists? temp-root)
    (delete-directory/files temp-root))
  (make-directory* temp-root)
  (for/list ([source-path (in-list (trim-corpus-files
                                    (collect-corpus-files source-root)
                                    corpus-limit))])
    (copy-corpus-file source-root temp-root source-path)))

;; roundtrip-result : path? -> (or/c 'ok (list 'timeout path-string?) (list 'exn path-string? string?) (list 'mismatch path-string? string? string?))
;;   Check one copied corpus file with a hard per-file timeout.
(define (roundtrip-result path)
  (define result-box
    (box #f))
  (define cust
    (make-custodian))
  (define worker
    (parameterize ([current-custodian cust])
      (thread
       (lambda ()
         (set-box!
          result-box
          (with-handlers ([exn:fail?
                           (lambda (e)
                             (list 'exn
                                   (path->string path)
                                   (exn-message e)))])
            (define original
              (file->string path))
            (define rendered
              (preview-file path roundtrip-options))
            (define stripped
              (strip-ansi rendered))
            (if (string=? stripped original)
                'ok
                (list 'mismatch
                      (path->string path)
                      stripped
                      original))))))))
  (define result
    (sync/timeout per-file-timeout-seconds
                  (thread-dead-evt worker)))
  (custodian-shutdown-all cust)
  (cond
    [result (unbox result-box)]
    [else   (list 'timeout (path->string path))]))

;; run-webracket-markdown-roundtrip-tests : -> void?
;;   Execute the copied-corpus round-trip test or skip clearly if unavailable.
(define (run-webracket-markdown-roundtrip-tests)
  (define source-root
    (simplify-path (build-path peek-root ".." "webracket")))
  (cond
    [(not (directory-exists? source-root))
     (displayln
      (format "Skipping webracket Markdown round-trip test; repo not found at ~a"
              (path->string source-root)))]
    [else
     (define copied-paths
       (copied-corpus-files source-root temp-root))
     (check-true (pair? copied-paths)
                 (format "No Markdown files found under ~a"
                         (path->string source-root)))
     (for ([path (in-list copied-paths)])
       (match (roundtrip-result path)
         ['ok
          (void)]
         [(list 'timeout timed-out-path)
          (error 'webracket-markdown-roundtrip
                 "round-trip timed out for ~a after ~a seconds"
                 timed-out-path
                 per-file-timeout-seconds)]
         [(list 'exn failed-path message)
          (error 'webracket-markdown-roundtrip
                 "~a\n~a"
                 failed-path
                 message)]
         [(list 'mismatch failed-path actual expected)
          (check-equal? actual
                        expected
                        (format "round-trip mismatch for ~a"
                                failed-path))]))]))

(module+ test
  (run-webracket-markdown-roundtrip-tests))
