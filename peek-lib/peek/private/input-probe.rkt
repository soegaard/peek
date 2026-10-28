#lang racket/base

;;;
;;; Bounded Input Probe
;;;

;; Bounded, replayable prefix sampling for previewers that need representation
;; facts before they begin their ordinary streaming renderer.

;; input-probe?                       : any/c -> boolean?
;;   Recognize one bounded input probe result.
;; input-probe-sample                 : input-probe? -> immutable-bytes?
;;   Extract sampled bytes without consuming them from the replay port.
;; input-probe-replay-port            : input-probe? -> input-port?
;;   Extract a port that replays sampled bytes followed by unread input.
;; input-probe-stopping-reason        : input-probe? -> symbol?
;;   Extract why the bounded probe stopped.
;; input-probe-byte-count             : input-probe? -> exact-nonnegative-integer?
;;   Extract the number of sampled bytes.
;; input-probe-line-count             : input-probe? -> exact-nonnegative-integer?
;;   Extract the number of sampled physical lines.
;; probe-input-port                   : input-port? keyword-arguments -> input-probe?
;;   Read an available bounded prefix and retain a lossless replay port.

(provide (struct-out input-probe)
         probe-input-port)

(require racket/port)

;; A replayable byte prefix and the facts collected while sampling it.
(struct input-probe (sample replay-port stopping-reason byte-count line-count)
  #:transparent)

;; default-probe-byte-limit : exact-positive-integer?
;; Maximum prefix size considered by initial representation inspection.
(define default-probe-byte-limit
  32768)

;; default-probe-line-limit : exact-positive-integer?
;; Maximum physical lines considered by initial representation inspection.
(define default-probe-line-limit
  256)

;; default-probe-availability-timeout-ms : exact-positive-integer?
;; Time to wait for the next byte after a probe has started receiving input.
(define default-probe-availability-timeout-ms
  20)

;; supported-probe-modes : (listof symbol?)
;; Sampling schedules that preserve the same byte and line caps.
(define supported-probe-modes
  '(interactive fixed-prefix))

;; read-available-byte : input-port? -> (or/c exact-nonnegative-integer? 'unavailable eof-object?)
;;   Read one byte without blocking when no input is immediately ready.
(define (read-available-byte in)
  (define buffer
    (make-bytes 1))
  (define count
    (read-bytes-avail!* buffer in))
  (cond
    [(eof-object? count)
     count]
    [(zero? count)
     'unavailable]
    [else
     (bytes-ref buffer 0)]))

;; update-physical-line-count : exact-nonnegative-integer? boolean? exact-nonnegative-integer? -> (values exact-nonnegative-integer? boolean?)
;;   Count CR, LF, and CRLF as physical line boundaries without double-counting CRLF.
(define (update-physical-line-count line-count previous-carriage-return? byte)
  (cond
    [(= byte (char->integer #\return))
     (values (add1 line-count) #t)]
    [(= byte (char->integer #\newline))
     (values (if previous-carriage-return?
                 line-count
                 (add1 line-count))
             #f)]
    [else
     (values line-count #f)]))

;; milliseconds-remaining : real? -> real?
;;   Return a nonnegative duration suitable for `sync/timeout`.
(define (milliseconds-remaining deadline)
  (max 0
       (- deadline
          (current-inexact-milliseconds))))

;; wait-for-input : input-port? real? -> boolean?
;;   Wait no longer than the available probe budget for one readable byte.
(define (wait-for-input in remaining-ms)
  (and (positive? remaining-ms)
       (sync/timeout (/ remaining-ms 1000.0)
                     in)
       #t))

;; probe-input-port : input-port? ... -> input-probe?
;;   Read a bounded prefix, preserving every consumed byte for replay.
(define (probe-input-port in
                          #:byte-limit [byte-limit default-probe-byte-limit]
                          #:line-limit [line-limit default-probe-line-limit]
                          #:mode [mode 'interactive]
                          #:availability-timeout-ms
                          [availability-timeout-ms
                           default-probe-availability-timeout-ms])
  (unless (input-port? in)
    (raise-argument-error 'probe-input-port "input-port?" in))
  (unless (exact-positive-integer? byte-limit)
    (raise-argument-error 'probe-input-port "exact-positive-integer?" byte-limit))
  (unless (exact-positive-integer? line-limit)
    (raise-argument-error 'probe-input-port "exact-positive-integer?" line-limit))
  (unless (memq mode supported-probe-modes)
    (raise-argument-error 'probe-input-port
                          "(or/c 'interactive 'fixed-prefix)"
                          mode))
  (unless (exact-nonnegative-integer? availability-timeout-ms)
    (raise-argument-error 'probe-input-port
                          "exact-nonnegative-integer?"
                          availability-timeout-ms))
  (define sampled
    (open-output-bytes))
  (let loop ([byte-count 0]
             [line-count 0]
             [previous-carriage-return? #f]
             [deadline #f])
    (cond
      [(>= byte-count byte-limit)
       (define sample
         (bytes->immutable-bytes (get-output-bytes sampled)))
       (input-probe sample
                    (input-port-append #f (open-input-bytes sample) in)
                    'byte-limit
                    byte-count
                    line-count)]
      [(>= line-count line-limit)
       (define sample
         (bytes->immutable-bytes (get-output-bytes sampled)))
       (input-probe sample
                    (input-port-append #f (open-input-bytes sample) in)
                    'line-limit
                    byte-count
                    line-count)]
      [else
       (define next-byte
         (read-available-byte in))
       (cond
         [(eof-object? next-byte)
          (define sample
            (bytes->immutable-bytes (get-output-bytes sampled)))
          (input-probe sample
                       (input-port-append #f (open-input-bytes sample) in)
                       'eof
                       byte-count
                       line-count)]
         [(eq? next-byte 'unavailable)
          (cond
            [(eq? mode 'fixed-prefix)
             ;; Reproducible callers intentionally wait for EOF or one of the
             ;; explicit caps instead of letting producer timing shorten the
             ;; sample. Interactive callers retain the short availability cap.
             (define blocking-byte
               (read-byte in))
             (cond
               [(eof-object? blocking-byte)
                (define sample
                  (bytes->immutable-bytes (get-output-bytes sampled)))
                (input-probe sample
                             (input-port-append #f (open-input-bytes sample) in)
                             'eof
                             byte-count
                             line-count)]
               [else
                (write-byte blocking-byte sampled)
                (define-values (next-line-count next-previous-carriage-return?)
                  (update-physical-line-count line-count
                                              previous-carriage-return?
                                              blocking-byte))
                (loop (add1 byte-count)
                      next-line-count
                      next-previous-carriage-return?
                      deadline)])]
            [(not deadline)
             (define sample
               (bytes->immutable-bytes (get-output-bytes sampled)))
             (input-probe sample
                          (input-port-append #f (open-input-bytes sample) in)
                          'unavailable
                          byte-count
                          line-count)]
            [(wait-for-input in (milliseconds-remaining deadline))
             (loop byte-count
                   line-count
                   previous-carriage-return?
                   deadline)]
            [else
             (define sample
               (bytes->immutable-bytes (get-output-bytes sampled)))
             (input-probe sample
                          (input-port-append #f (open-input-bytes sample) in)
                          'unavailable
                          byte-count
                          line-count)])]
         [else
          (write-byte next-byte sampled)
          (define-values (next-line-count next-previous-carriage-return?)
            (update-physical-line-count line-count
                                        previous-carriage-return?
                                        next-byte))
          (loop (add1 byte-count)
                next-line-count
                next-previous-carriage-return?
                (or deadline
                    (+ (current-inexact-milliseconds)
                       availability-timeout-ms)))])])))

(module+ test
  (require rackunit)

  (define full-probe
    (probe-input-port (open-input-bytes #"one\r\ntwo\rthree\n")
                      #:availability-timeout-ms 0))
  (define line-probe
    (probe-input-port (open-input-bytes #"one\r\ntwo\rthree\n")
                      #:line-limit 2
                      #:availability-timeout-ms 0))
  (define-values (pipe-in pipe-out)
    (make-pipe))
  (void (write-bytes #"mov" pipe-out))
  (flush-output pipe-out)
  (define stalled-probe
    (probe-input-port pipe-in #:availability-timeout-ms 0))

  (check-equal? (input-probe-sample full-probe)
                #"one\r\ntwo\rthree\n")
  (check-equal? (input-probe-line-count full-probe) 3)
  (check-equal? (port->bytes (input-probe-replay-port full-probe))
                #"one\r\ntwo\rthree\n")
  (check-equal? (input-probe-sample line-probe)
                #"one\r\ntwo\r")
  (check-equal? (input-probe-stopping-reason line-probe)
                'line-limit)
  (check-equal? (input-probe-sample stalled-probe)
                #"mov")
  (check-equal? (input-probe-stopping-reason stalled-probe)
                'unavailable)
  (close-output-port pipe-out))
