#lang racket/base

;;;
;;; lexers Shell Round-Trip Corpus Test
;;;
;;
;; Round-trip fidelity test for shell files copied from the local
;; `/tmp/lexers-shell-corpus` snapshot.

;; run-lexers-shell-roundtrip-tests : -> void?
;;   Verify that shell previews round-trip after ANSI stripping, skipping
;;   any files that contain literal ESC bytes because those cannot be checked
;;   with the same ANSI-stripping comparison.

(require rackunit
         racket/file
         racket/list
         racket/match
         racket/path
         (lib "peek/preview.rkt"))

;; Corpus snapshot root.
(define corpus-root
  (or (getenv "PEEK_SHELL_CORPUS")
      "/tmp/lexers-shell-corpus"))

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

;; shell-path? : path-string? -> boolean?
;;   Recognize shell corpus files.
(define (shell-path? path)
  (define text
    (path->string path))
  (regexp-match? #px"(?i:\\.(?:sh|bash|zsh|ps1))$" text))

;; contains-raw-esc? : path? -> boolean?
;;   Recognize files that contain a literal ESC byte and cannot be round-tripped
;;   with the ANSI-stripping comparison.
(define (contains-raw-esc? path)
  (regexp-match? #rx"\x1b" (file->bytes path)))

;; collect-corpus-files : path? -> (listof path?)
;;   Collect shell corpus files from one source tree.
(define (collect-corpus-files root)
  (sort (for/list ([path (in-directory root)]
                   #:when (file-exists? path)
                   #:when (shell-path? path))
          path)
        string<?
        #:key path->string))

;; filtered-corpus-files : path? -> (listof path?)
;;   Remove literal-ESC files from the shell corpus before testing.
(define (filtered-corpus-files root)
  (filter (lambda (path)
            (not (contains-raw-esc? path)))
          (collect-corpus-files root)))

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

;; roundtrip-result : path? -> (or/c 'ok (list 'timeout path-string?) (list 'exn path-string? string?) (list 'mismatch path-string? string? string?))
;;   Check one corpus file with a hard per-file timeout.
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

;; run-lexers-shell-roundtrip-tests : -> void?
;;   Execute the shell corpus test or skip clearly if unavailable.
(define (run-lexers-shell-roundtrip-tests)
  (cond
    [(not (directory-exists? corpus-root))
     (displayln
      (format "Skipping shell round-trip test; corpus not found at ~a"
              corpus-root))]
    [else
     (define corpus-files
       (filtered-corpus-files corpus-root))
     (check-true (pair? corpus-files)
                 (format "No shell files found under ~a"
                         corpus-root))
     (for ([path (in-list corpus-files)])
       (match (roundtrip-result path)
         ['ok
          (void)]
         [(list 'timeout timed-out-path)
          (error 'lexers-shell-roundtrip
                 "round-trip timed out for ~a after ~a seconds"
                 timed-out-path
                 per-file-timeout-seconds)]
         [(list 'exn failed-path message)
          (error 'lexers-shell-roundtrip
                 "~a\n~a"
                 failed-path
                 message)]
         [(list 'mismatch failed-path actual expected)
          (check-equal? actual
                        expected
                        (format "round-trip mismatch for ~a"
                                failed-path))]))]))

(module+ test
  (run-lexers-shell-roundtrip-tests))
