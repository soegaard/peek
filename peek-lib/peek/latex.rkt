#lang racket/base

;;;
;;; LaTeX Preview
;;;
;;
;; LaTeX terminal preview rendering built on `lexers/latex`.

;; render-latex-preview      : string? -> string?
;;   Render LaTeX for terminal preview.
;; render-latex-preview-port : input-port? output-port? -> void?
;;   Render LaTeX from a port for terminal preview.

(provide
 ;; render-latex-preview      : string? -> string?
 ;;   Render LaTeX for terminal preview.
 render-latex-preview
 ;; render-latex-preview-port : input-port? output-port? -> void?
 ;;   Render LaTeX from a port for terminal preview.
 render-latex-preview-port)

(require "tex.rkt")
