#lang info

(define collection 'multi)

(define pkg-desc "Meta-package for the peek library and documentation.")
(define pkg-authors '(soegaard))
(define license 'MIT)

(define setup-collects '())
(define compile-omit-paths 'all)
(define test-omit-paths 'all)

(define deps '("base"
               "peek-lib"
               "peek-doc"
               "lexers-lib"
               "parser-tools-lib"
               "rackunit-lib"))

(define build-deps '("base"
                     "peek-lib"
                     "peek-doc"

                     "scribble-tools"
                     
                     "lexers-lib"                     
                     "rackunit-lib"
                     "scribble-lib"
                     "parser-tools-lib"
                     "syntax-color-lib"

                     "lexers-doc"
                     "parser-tools-doc"
                     "racket-doc"                     
                     "syntax-color-doc"))
