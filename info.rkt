#lang info

(define pkg-desc "Meta-package for the peek library and documentation.")
(define pkg-authors '(soegaard))
(define license 'MIT)

(define deps '("base"
               "peek-lib"
               "peek-doc"))

(define build-deps '("base"
                     "peek-lib"
                     "peek-doc"
                     
                     "lexers-lib"                     
                     "rackunit-lib"
                     "scribble-lib"
                     "parser-tools-lib"
                     "syntax-color-lib"

                     "lexers-doc"
                     "parser-tools-doc"
                     "racket-doc"                     
                     "syntax-color-doc"))
