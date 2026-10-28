#lang racket/base

;;;
;;; Assembly Streaming Tests
;;;
;;
;; Regression coverage for bounded probing and first output from a pipe that
;; remains open after a partial source token.

(require rackunit
         racket/string
         "../preview.rkt")

;; wait-for-output : output-port? string? -> boolean?
;;   Wait briefly for streaming output without requiring source EOF.
(define (wait-for-output out expected)
  (let loop ([remaining 100])
    (cond
      [(string-contains? (get-output-string out) expected)
       #t]
      [(zero? remaining)
       #f]
      [else
       (sleep 1/100)
       (loop (sub1 remaining))])))

(define-values (pipe-in pipe-out)
  (make-pipe))
(define output
  (open-output-string))
(define worker
  (thread
   (lambda ()
     (preview-port pipe-in
                   #f
                   (make-preview-options #:type 'asm
                                         #:color-mode 'never)
                   output))))

(void (write-bytes #"mov" pipe-out))
(flush-output pipe-out)

(check-true (wait-for-output output "mov"))

(close-output-port pipe-out)
(check-not-false (sync/timeout 1 (thread-dead-evt worker)))
(check-equal? (get-output-string output) "mov")
