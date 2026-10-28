#lang racket/base

;;;
;;; Assembly CLI Tests
;;;
;;
;; Verify machine-readable modes, stderr explanations, and pager-independent
;; forced generic assembly rendering through the public command-line entry.

(require json
         rackunit
         racket/string
         "../main.rkt")

;; run-main : (listof string?) bytes? -> (values string? string?)
;;   Invoke the command entry point with captured standard ports.
(define (run-main arguments input)
  (define out
    (open-output-string))
  (define err
    (open-output-string))
  (parameterize ([current-command-line-arguments (list->vector arguments)]
                 [current-input-port (open-input-bytes input)]
                 [current-output-port out]
                 [current-error-port err])
    (main))
  (values (get-output-string out)
          (get-output-string err)))

(define-values (rendered explained)
  (run-main '("--type" "asm"
              "--explain-type"
              "--no-pager"
              "--color" "never")
            #"entry:\nmov a, b\n"))

(check-equal? rendered "entry:\nmov a, b\n")
(check-true (regexp-match? #px"assembly request: requested generic" explained))

(define-values (detection-json detection-stderr)
  (run-main '("--detect-only" "--json" "--detection-mode" "fixed-prefix" "--no-pager")
            #"\377\376l\0d\0a\0"))

(define detection
  (read-json (open-input-string detection-json)))

(check-equal? (hash-ref detection 'encoding) "utf-16le")
(check-equal? (hash-ref detection 'schema_version) 2)
(check-equal? (hash-ref (hash-ref detection 'probe) 'detection_mode)
              "fixed-prefix")
(check-equal? detection-stderr "")

;; Automatic inspection is available without forcing --type asm.  The shared
;; lexer controls whether the detected profile is qualified; here it retains
;; generic rendering while recording the ca65 hypothesis on stderr.
(define-values (automatic-rendered automatic-explained)
  (run-main '("--explain-type"
              "--no-pager"
              "--color" "never")
            #".setcpu \"6502\"\n.feature at_in_identifiers\n"))

(check-equal? automatic-rendered
              ".setcpu \"6502\"\n.feature at_in_identifiers\n")
(check-true (regexp-match? #px"assembly preview: dialect generic" automatic-explained))
(check-true (regexp-match? #px"candidate ca65/mos-6502" automatic-explained))

;; Target-dependent profiles receive their architecture explicitly rather than
;; relying on a filename or a source fragment to choose GNU syntax.
(define-values (gas-rendered gas-stderr)
  (run-main '("--type" "asm"
              "--dialect" "gas"
              "--arch" "x86"
              "--no-pager"
              "--color" "never")
            #".intel_syntax noprefix\n.code64\nmov rax, 1\n"))

(check-equal? gas-rendered ".intel_syntax noprefix\n.code64\nmov rax, 1\n")
(check-equal? gas-stderr "")

(define-values (token-jsonl token-stderr)
  (run-main '("--type" "asm"
              "--dump-tokens" "jsonl"
              "--no-pager")
            #"a\303("))

(define token-lines
  (filter (lambda (line)
            (not (string=? line "")))
          (string-split token-jsonl "\n")))

(check-equal? (length token-lines) 3)
(check-equal? (hash-ref (read-json (open-input-string (cadr token-lines)))
                        'raw_bytes_hex)
              "C3")
(check-equal? token-stderr "")
