#lang info

(define pkg-desc "Meta-package for the lexers library and documentation.")
(define pkg-authors '(soegaard))
(define license 'MIT)

(define deps '("base"
               "peek-lib"
               "peek-doc"
               "parser-tools-lib"
               "syntax-color-lib"))

(define build-deps '("base"
                     "lexers-lib"                     
                     "rackunit-lib"
                     "scribble-lib"
                     "parser-tools-lib"
                     "syntax-color-lib"
                     "lexers-doc"
                     "parser-tools-doc"
                     "racket-doc"                     
                     "syntax-color-doc"))
