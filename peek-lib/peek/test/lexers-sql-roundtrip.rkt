#lang racket/base

;;;
;;; lexers SQL Round-Trip Corpus Test
;;;
;;
;; Round-trip fidelity test for SQL files copied from the local
;; `/tmp/lexers-sql-corpus` snapshot.

(require rackunit
         racket/file
         racket/list
         racket/match
         racket/path
         (lib "peek/preview.rkt"))

;; Corpus snapshot root.
(define corpus-root
  (or (getenv "PEEK_SQL_CORPUS")
      "/tmp/lexers-sql-corpus"))

;; Maximum seconds to spend on one file.
(define per-file-timeout-seconds
  120)

;; ANSI color stripping pattern.
(define ansi-pattern
  #px"\u001b\\[[0-9;]*m")

;; roundtrip-color-options : symbol? -> preview-options?
;;   Rendering options for one SQL dialect corpus bucket.
;;
;; Use color mode `never` here so source files that intentionally contain
;; terminal escape sequences are compared byte-for-byte after previewing.
(define (roundtrip-color-options dialect)
  (make-preview-options #:type dialect
                        #:color-mode 'never))

;; sql-path? : path-string? -> boolean?
;;   Recognize SQL corpus files.
(define (sql-path? path)
  (define text
    (path->string path))
  (regexp-match? #px"(?i:\\.sql)$" text))

;; collect-corpus-files : path? -> (listof path?)
;;   Collect SQL corpus files from one source tree.
(define (collect-corpus-files root)
  (sort (for/list ([path (in-directory root)]
                   #:when (file-exists? path)
                   #:when (sql-path? path))
          path)
        string<?
        #:key path->string))

;; bucket->dialect : string? -> symbol?
;;   Map one top-level SQL corpus bucket name to a peek file type.
(define (bucket->dialect bucket)
  (case (string->symbol bucket)
    [(core)     'sql]
    [(sqlite)   'sqlite]
    [(postgres) 'postgres]
    [(mysql)    'mysql]
    [else
     (error 'lexers-sql-roundtrip
            "unknown SQL corpus bucket: ~a"
            bucket)]))

;; path->dialect : path? -> symbol?
;;   Determine the SQL dialect from the top-level corpus bucket.
(define (path->dialect path)
  (define relative
    (find-relative-path corpus-root path))
  (define pieces
    (explode-path relative))
  (define first-piece
    (and (pair? pieces)
         (car pieces)))
  (unless (path? first-piece)
    (error 'lexers-sql-roundtrip
           "could not determine SQL corpus bucket for ~a"
           path))
  (bucket->dialect (path->string first-piece)))

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
              (preview-file path
                            (roundtrip-color-options (path->dialect path))))
            (if (string=? rendered original)
                'ok
                (list 'mismatch
                      (path->string path)
                      rendered
                      original))))))))
  (define result
    (sync/timeout per-file-timeout-seconds
                  (thread-dead-evt worker)))
  (custodian-shutdown-all cust)
  (cond
    [result (unbox result-box)]
    [else   (list 'timeout (path->string path))]))

;; run-lexers-sql-roundtrip-tests : -> void?
;;   Execute the SQL corpus test or skip clearly if unavailable.
(define (run-lexers-sql-roundtrip-tests)
  (cond
    [(not (directory-exists? corpus-root))
     (displayln
      (format "Skipping SQL round-trip test; corpus not found at ~a"
              corpus-root))]
    [else
     (define corpus-files
       (collect-corpus-files corpus-root))
     (check-true (pair? corpus-files)
                 (format "No SQL files found under ~a"
                         corpus-root))
     (for ([path (in-list corpus-files)])
       (match (roundtrip-result path)
         ['ok
          (void)]
         [(list 'timeout timed-out-path)
          (error 'lexers-sql-roundtrip
                 "round-trip timed out for ~a after ~a seconds"
                 timed-out-path
                 per-file-timeout-seconds)]
         [(list 'exn failed-path message)
          (error 'lexers-sql-roundtrip
                 "~a\n~a"
                 failed-path
                 message)]
         [(list 'mismatch failed-path actual expected)
          (check-equal? actual
                        expected
                        (format "round-trip mismatch for ~a"
                                failed-path))]))]))

(module+ test
  (run-lexers-sql-roundtrip-tests))
