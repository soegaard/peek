#lang info

(define collection 'multi)

(define pkg-desc "Implementation (no documentation) part of \"peek\".")

(define deps       '("base"
                     "parser-tools-lib"
                     "lexers-lib"
                     "rackunit-lib"))

(define racket-launcher-names '("peek"))
(define racket-launcher-libraries '("peek/main.rkt"))

(define compile-omit-paths '("peek/test/fixtures"))
(define test-omit-paths    '("peek/test/fixtures"))

(define license 'MIT)
