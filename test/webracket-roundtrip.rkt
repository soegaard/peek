#lang racket/base

;;;
;;; webracket Round-Trip Corpus Test
;;;
;;
;; Round-trip fidelity test for Racket-family files copied from the local
;; `../webracket` checkout into `/tmp`.

;; run-webracket-roundtrip-tests : -> void?
;;   Copy the local `webracket` Racket-family corpus to `/tmp` and verify that
;;   previewing with ANSI color and then stripping ANSI yields the exact
;;   original file contents.

(require rackunit
         racket/file
         racket/list
         racket/path
         racket/runtime-path
         (lib "peek/preview.rkt"))

(define-runtime-path peek-root "..")

;; Temporary corpus snapshot root.
(define temp-root
  (build-path "/tmp" "peek-webracket-roundtrip"))

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
;;   Recognize Racket-family corpus files.
(define (corpus-path? path)
  (define text
    (path->string path))
  (regexp-match? #px"(?i:\\.(?:rkt|ss|scm|rktd))$" text))

;; collect-corpus-files : path? -> (listof path?)
;;   Collect corpus files from one source tree.
(define (collect-corpus-files root)
  (sort (for/list ([path (in-directory root)]
                   #:when (file-exists? path)
                   #:when (corpus-path? path))
          path)
        string<?
        #:key path->string))

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
;;   Copy all Racket-family corpus files to `/tmp` and return copied paths.
(define (copied-corpus-files source-root temp-root)
  (when (directory-exists? temp-root)
    (delete-directory/files temp-root))
  (make-directory* temp-root)
  (for/list ([source-path (in-list (collect-corpus-files source-root))])
    (copy-corpus-file source-root temp-root source-path)))

;; assert-roundtrip-file : path? -> void?
;;   Check one copied corpus file for exact text round-trip after ANSI stripping.
(define (assert-roundtrip-file path)
  (define original
    (file->string path))
  (define rendered
    (with-handlers ([exn:fail?
                     (lambda (e)
                       (error 'webracket-roundtrip
                              "~a\n~a"
                              (path->string path)
                              (exn-message e)))])
      (preview-file path roundtrip-options)))
  (define stripped
    (strip-ansi rendered))
  (check-equal? stripped
                original
                (format "round-trip mismatch for ~a"
                        (path->string path))))

;; run-webracket-roundtrip-tests : -> void?
;;   Execute the copied-corpus round-trip test or skip clearly if unavailable.
(define (run-webracket-roundtrip-tests)
  (define source-root
    (simplify-path (build-path peek-root ".." "webracket")))
  (cond
    [(not (directory-exists? source-root))
     (displayln
      (format "Skipping webracket round-trip test; repo not found at ~a"
              (path->string source-root)))]
    [else
     (define copied-paths
       (copied-corpus-files source-root temp-root))
     (define racket-paths
       (filter (lambda (path)
                 (regexp-match? #px"(?i:\\.(?:rkt|ss|scm|rktd))$"
                                (path->string path)))
               copied-paths))
     (check-true (pair? racket-paths)
                 (format "No Racket-family files found under ~a"
                         (path->string source-root)))
     (for ([path (in-list copied-paths)])
       (assert-roundtrip-file path))]))

(module+ test
  (run-webracket-roundtrip-tests))
