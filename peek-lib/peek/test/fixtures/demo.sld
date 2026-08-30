;; Basic Scheme library preview fixture.
(define-library (peek demo)
  (export greet)
  (import (scheme base))
  (begin
    (define (greet name)
      (string-append "hello " name))))
