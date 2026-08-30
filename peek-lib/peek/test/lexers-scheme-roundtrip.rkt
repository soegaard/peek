#lang racket/base

;;;
;;; lexers Scheme Round-Trip Corpus Test
;;;
;;
;; Round-trip fidelity test for Scheme files copied from the local
;; `/tmp/lexers-scheme-corpus` snapshot.

;; run-lexers-scheme-roundtrip-tests : -> void?
;;   Verify that Scheme previews round-trip after ANSI stripping.

(require rackunit
         racket/file
         racket/list
         racket/match
         racket/path
         "../scheme.rkt")

;; Corpus snapshot root.
(define corpus-root
  (or (getenv "PEEK_SCHEME_CORPUS")
      "/tmp/lexers-scheme-corpus"))

;; Maximum seconds to spend on one file.
(define per-file-timeout-seconds
  120)

;; ANSI color stripping pattern.
(define ansi-pattern
  #px"\u001b\\[[0-9;]*m")

;; strip-ansi : string? -> string?
;;   Remove ANSI color escapes from preview output.
(define (strip-ansi text)
  (regexp-replace* ansi-pattern text ""))

;; scheme-path? : path-string? -> boolean?
;;   Recognize Scheme corpus files.
(define (scheme-path? path)
  (regexp-match? #px"(?i:\\.(?:scm|ss|sld|sps|sls))$"
                 (path->string path)))

;; collect-corpus-files : path? -> (listof path?)
;;   Collect Scheme corpus files from one source tree.
(define (collect-corpus-files root)
  (sort (for/list ([path (in-directory root)]
                   #:when (file-exists? path)
                   #:when (scheme-path? path))
          path)
        string<?
        #:key path->string))

;; corpus-file-dialect : path? -> symbol?
;;   Infer one lexer dialect from the top-level corpus directory.
(define (corpus-file-dialect path)
  (define-values (_ dialect-name _directory?)
    (split-path (path-only path)))
  (string->symbol (path->string dialect-name)))

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
              (render-scheme-preview original
                                     #:dialect (corpus-file-dialect path)))
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

;; run-lexers-scheme-roundtrip-tests : -> void?
;;   Execute the Scheme corpus test or skip clearly if unavailable.
(define (run-lexers-scheme-roundtrip-tests)
  (cond
    [(not (directory-exists? corpus-root))
     (displayln
      (format "Skipping Scheme round-trip test; corpus not found at ~a"
              corpus-root))]
    [else
     (define corpus-files
       (collect-corpus-files corpus-root))
     (check-true (pair? corpus-files)
                 (format "No Scheme files found under ~a"
                         corpus-root))
     (for ([path (in-list corpus-files)])
       (match (roundtrip-result path)
         ['ok
          (void)]
         [(list 'timeout timed-out-path)
          (error 'lexers-scheme-roundtrip
                 "round-trip timed out for ~a after ~a seconds"
                 timed-out-path
                 per-file-timeout-seconds)]
         [(list 'exn failed-path message)
          (error 'lexers-scheme-roundtrip
                 "~a\n~a"
                 failed-path
                 message)]
         [(list 'mismatch failed-path actual expected)
          (check-equal? actual
                        expected
                        (format "round-trip mismatch for ~a"
                                failed-path))]))]))

(module+ test
  (run-lexers-scheme-roundtrip-tests))
