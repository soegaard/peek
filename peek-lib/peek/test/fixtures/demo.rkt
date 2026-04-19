#lang racket/base

; Greeting helper.
#;(+ 1 2)
(define (greet #:name [name "you"])
  (define parts
    (list "hi " name))
  (apply string-append parts))

(module+ main
  (displayln (greet #:name "peek")))
