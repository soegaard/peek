#lang racket/base

;;;
;;; Assembly Token JSONL Round-Trip Tests
;;;
;;
;; Ensure JSON Lines inspection retains enough raw byte data to reconstruct the
;; exact source, including malformed UTF-8 and CRLF.

(require json
         rackunit
         racket/list
         racket/string
         "../asm.rkt")

;; hex-value : char? -> exact-nonnegative-integer?
;;   Decode one hexadecimal character from a token JSON record.
(define (hex-value ch)
  (cond
    [(char<=? #\0 ch #\9)
     (- (char->integer ch) (char->integer #\0))]
    [else
     (+ 10 (- (char->integer ch) (char->integer #\A)))]))

;; hex->bytes : string? -> bytes?
;;   Decode the inspection format's uppercase raw-byte encoding.
(define (hex->bytes text)
  (define out
    (open-output-bytes))
  (for ([index (in-range 0 (string-length text) 2)])
    (write-byte (+ (* 16 (hex-value (string-ref text index)))
                   (hex-value (string-ref text (add1 index))))
                out))
  (get-output-bytes out))

(define original
  #"entry:\r\na\303(\n")
(define jsonl
  (let ([out (open-output-string)])
    (write-asm-token-jsonl (open-input-bytes original) out)
    (get-output-string out)))
(define tokens
  (for/list ([line (in-list (string-split jsonl "\n" #:trim? #t))])
    (read-json (open-input-string line))))

(check-equal? (apply bytes-append
                     (for/list ([token (in-list tokens)])
                       (hex->bytes (hash-ref token 'raw_bytes_hex))))
              original)
(check-not-false
 (findf (lambda (token)
          (string=? (hash-ref token 'raw_bytes_hex) "C3"))
        tokens))
