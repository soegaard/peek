#lang racket/base

;;;
;;; Peek Launcher
;;;
;;
;; Launcher entry point for the `peek` package.

;; main : -> void?
;;   Run the peek command-line interface.

(provide
 ;; main : -> void?
 ;;   Run the peek command-line interface.
 main)

(require "../peek-lib/peek/main.rkt")

(module+ main
  (main))
