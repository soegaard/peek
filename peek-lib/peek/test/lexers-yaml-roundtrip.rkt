#lang racket/base

;;;
;;; lexers YAML Round-Trip Corpus Test
;;;
;;
;; Round-trip fidelity test for YAML files copied from the local
;; `/tmp/peek-yaml-corpus-large` snapshot.

(require rackunit
         racket/file
         racket/list
         racket/match
         racket/path
         (lib "peek/preview.rkt"))

;; Corpus snapshot root.
(define corpus-root
  (or (getenv "PEEK_YAML_CORPUS")
      "/tmp/peek-yaml-corpus-large"))

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

;; yaml-path? : path-string? -> boolean?
;;   Recognize YAML corpus files.
(define (yaml-path? path)
  (define text
    (path->string path))
  (regexp-match? #px"(?i:\\.(?:ya?ml))$" text))

;; collect-corpus-files : path? -> (listof path?)
;;   Collect YAML corpus files from one source tree.
(define (collect-corpus-files root)
  (sort (for/list ([path (in-directory root)]
                   #:when (file-exists? path)
                   #:when (yaml-path? path))
          path)
        string<?
        #:key path->string))

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

;; run-lexers-yaml-roundtrip-tests : -> void?
;;   Execute the YAML corpus test or skip clearly if unavailable.
(define (run-lexers-yaml-roundtrip-tests)
  (cond
    [(not (directory-exists? corpus-root))
     (displayln
      (format "Skipping YAML round-trip test; corpus not found at ~a"
              corpus-root))]
    [else
     (define corpus-files
       (collect-corpus-files corpus-root))
     (check-true (pair? corpus-files)
                 (format "No YAML files found under ~a"
                         corpus-root))
     (for ([path (in-list corpus-files)])
       (match (roundtrip-result path)
         ['ok
          (void)]
         [(list 'timeout timed-out-path)
          (error 'lexers-yaml-roundtrip
                 "round-trip timed out for ~a after ~a seconds"
                 timed-out-path
                 per-file-timeout-seconds)]
         [(list 'exn failed-path message)
          (error 'lexers-yaml-roundtrip
                 "~a\n~a"
                 failed-path
                 message)]
         [(list 'mismatch failed-path actual expected)
          (check-equal? actual
                        expected
                        (format "round-trip mismatch for ~a"
                                failed-path))]))]))

(module+ test
  (run-lexers-yaml-roundtrip-tests))
