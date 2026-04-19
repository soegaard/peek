#lang info

(define collection 'multi)

(define deps '("base" "scribble-lib" "racket-doc" "peek-lib" "scribble-tools"))
(define build-deps '())
(define scribblings '(("peek.scrbl" () (library))))

(define license 'MIT)
