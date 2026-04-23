#lang racket/base

; Greeting helper.
#;(+ 1 2)
(define (greet #:name [name "you"])
  (string-append "hi " name))

(greet #:name "peek")
