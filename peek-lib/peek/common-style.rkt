#lang racket/base

;;;
;;; Common Preview Styles
;;;
;;
;; Shared ANSI color helpers and file-type style mappings used by multiple
;; preview renderers.

;; ansi-reset      -- Reset ANSI styling.
;; ansi-comment    -- Comment color.
;; ansi-keyword    -- Keyword color.
;; ansi-identifier -- Identifier color.
;; ansi-literal    -- Literal color.
;; ansi-delimiter  -- Delimiter color.
;; ansi-malformed  -- Error color.
;; colorize-text   -- Apply ANSI styling while preserving newlines.
;; css-like-style  -- Style CSS-like embedded tokens.
;; c-like-style          -- Style C-like embedded tokens.
;; cpp-like-style        -- Style C++-like embedded tokens.
;; objc-like-style       -- Style Objective-C-like embedded tokens.
;; makefile-like-style   -- Style Makefile-like embedded tokens.
;; javascript-like-style -- Style JavaScript-like embedded tokens.
;; java-like-style       -- Style Java-like embedded tokens.
;; json-like-style       -- Style JSON-like embedded tokens.
;; plist-like-style      -- Style plist-like embedded tokens.
;; tex-like-style        -- Style TeX/LaTeX embedded tokens.
;; delimited-like-style  -- Style CSV/TSV-like embedded tokens.
;; yaml-like-style       -- Style YAML-like embedded tokens.
;; python-like-style     -- Style Python-like embedded tokens.
;; pascal-like-style     -- Style Pascal-like embedded tokens.
;; swift-like-style      -- Style Swift-like embedded tokens.
;; rust-like-style       -- Style Rust-like embedded tokens.
;; shell-like-style      -- Style shell-like embedded tokens.
;; go-like-style         -- Style Go-like embedded tokens.
;; rhombus-like-style    -- Style Rhombus-like embedded tokens.
;; haskell-like-style    -- Style Haskell-like embedded tokens.
;; wat-like-style        -- Style WAT-like embedded tokens.
;; racket-like-style     -- Style Racket-like embedded tokens.
;; scribble-like-style   -- Style Scribble-like embedded tokens.
;; html-like-style       -- Style HTML-like embedded tokens.

(provide
 ;; ansi-reset      Reset ANSI styling.
 ansi-reset
 ;; ansi-comment    Comment color.
 ansi-comment
 ;; ansi-keyword    Keyword color.
 ansi-keyword
 ;; ansi-identifier Identifier color.
 ansi-identifier
 ;; ansi-literal    Literal color.
 ansi-literal
 ;; ansi-delimiter  Delimiter color.
 ansi-delimiter
 ;; ansi-malformed  Error color.
 ansi-malformed
 ;; colorize-text   Apply ANSI styling while preserving newlines.
 colorize-text
 ;; css-like-style  Style CSS-like embedded tokens.
 css-like-style
 ;; c-like-style Style C-like embedded tokens.
 c-like-style
 ;; cpp-like-style Style C++-like embedded tokens.
 cpp-like-style
 ;; objc-like-style Style Objective-C-like embedded tokens.
 objc-like-style
 ;; makefile-like-style Style Makefile-like embedded tokens.
 makefile-like-style
 ;; javascript-like-style Style JavaScript-like embedded tokens.
 javascript-like-style
 ;; java-like-style Style Java-like embedded tokens.
 java-like-style
 ;; json-like-style       Style JSON-like embedded tokens.
 json-like-style
 ;; plist-like-style      Style plist-like embedded tokens.
 plist-like-style
 ;; tex-like-style        Style TeX/LaTeX embedded tokens.
 tex-like-style
 ;; delimited-like-style Style CSV/TSV-like embedded tokens.
 delimited-like-style
 ;; yaml-like-style Style YAML-like embedded tokens.
 yaml-like-style
 ;; python-like-style Style Python-like embedded tokens.
 python-like-style
 ;; pascal-like-style Style Pascal-like embedded tokens.
 pascal-like-style
 ;; swift-like-style Style Swift-like embedded tokens.
 swift-like-style
 ;; rust-like-style Style Rust-like embedded tokens.
 rust-like-style
 ;; shell-like-style Style shell-like embedded tokens.
 shell-like-style
 ;; go-like-style Style Go-like embedded tokens.
 go-like-style
 ;; rhombus-like-style Style Rhombus-like embedded tokens.
 rhombus-like-style
 ;; haskell-like-style Style Haskell-like embedded tokens.
 haskell-like-style
 ;; wat-like-style Style WAT-like embedded tokens.
 wat-like-style
 ;; racket-like-style Style Racket-like embedded tokens.
 racket-like-style
 ;; scribble-like-style Style Scribble-like embedded tokens.
 scribble-like-style
 ;; html-like-style Style HTML-like embedded tokens.
 html-like-style)

(require racket/string)

;; ANSI color constants.
(define (ansi . codes)
  (string-append "\033[" (string-join (map number->string codes) ";") "m"))

(define ansi-reset      (ansi 0))
(define ansi-comment    (ansi 38 2 106 153 85))
(define ansi-keyword    (ansi 38 2 86 156 214))
(define ansi-identifier (ansi 38 2 156 220 254))
(define ansi-literal    (ansi 38 2 206 145 120))
(define ansi-delimiter  (ansi 38 2 212 212 212))
(define ansi-malformed  (ansi 38 2 244 71 71))

;; colorize-text : string? string? -> string?
;;   Apply ANSI styling while preserving coloring across newlines.
(define (colorize-text code text)
  (cond
    [(or (string=? code "") (string=? text "")) text]
    [else
     (string-append code
                    (string-join (string-split text "\n" #:trim? #f)
                                 (string-append ansi-reset "\n" code))
                    ansi-reset)]))

;; css-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for CSS-like roles.
(define (css-like-style category tags)
  (cond
    [(or (member 'selector-token tags)
         (member 'at-rule-name tags)
         (member 'function-name tags))
     ansi-keyword]
    [(or (member 'property-name tags)
         (member 'custom-property-name tags))
     ansi-identifier]
    [(or (member 'declaration-value-token tags)
         (member 'color-literal tags)
         (member 'color-function tags)
         (member 'gradient-function tags)
         (member 'string-literal tags)
         (member 'numeric-literal tags)
         (member 'length-dimension tags))
     ansi-literal]
    [(eq? category 'delimiter)
     ansi-delimiter]
    [(eq? category 'unknown)
     ansi-malformed]
    [(eq? category 'literal)
     ansi-literal]
    [(eq? category 'identifier)
     ansi-identifier]
    [else
     ""]))

;; c-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for C-like roles.
(define (c-like-style category tags)
  (cond
    [(or (memq 'malformed-token tags)
         (memq 'c-error tags)
         (eq? category 'unknown)
         (eq? category 'malformed))
     ansi-malformed]
    [(or (eq? category 'comment)
         (memq 'comment tags))
     ansi-comment]
    [(or (memq 'c-preprocessor-directive tags)
         (eq? category 'keyword))
     ansi-keyword]
    [(or (memq 'c-header-name tags)
         (memq 'c-string-literal tags)
         (memq 'c-char-literal tags)
         (eq? category 'literal))
     ansi-literal]
    [(or (memq 'c-identifier tags)
         (eq? category 'identifier))
     ansi-identifier]
    [(or (memq 'c-line-splice tags)
         (memq 'c-delimiter tags)
         (eq? category 'delimiter)
         (eq? category 'operator))
     ansi-delimiter]
    [else
     ""]))

;; cpp-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for C++-like roles.
(define (cpp-like-style category tags)
  (cond
    [(or (memq 'cpp-error tags)
         (eq? category 'unknown)
         (eq? category 'malformed))
     ansi-malformed]
    [(or (eq? category 'comment)
         (memq 'comment tags)
         (memq 'cpp-comment tags))
     ansi-comment]
    [(or (memq 'cpp-preprocessor-directive tags)
         (memq 'cpp-keyword tags)
         (eq? category 'keyword))
     ansi-keyword]
    [(or (memq 'cpp-header-name tags)
         (memq 'cpp-string-literal tags)
         (memq 'cpp-char-literal tags)
         (memq 'cpp-numeric-literal tags)
         (eq? category 'literal))
     ansi-literal]
    [(or (memq 'cpp-identifier tags)
         (eq? category 'identifier))
     ansi-identifier]
    [(or (memq 'cpp-line-splice tags)
         (memq 'cpp-operator tags)
         (memq 'cpp-delimiter tags)
         (eq? category 'operator)
         (eq? category 'delimiter))
     ansi-delimiter]
    [else
     ""]))

;; objc-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for Objective-C-like roles.
(define (objc-like-style category tags)
  (cond
    [(or (memq 'objc-error tags)
         (memq 'malformed-token tags)
         (eq? category 'unknown)
         (eq? category 'malformed))
     ansi-malformed]
    [(or (eq? category 'comment)
         (memq 'comment tags)
         (memq 'objc-comment tags))
     ansi-comment]
    [(or (memq 'objc-keyword tags)
         (memq 'objc-at-keyword tags)
         (memq 'objc-preprocessor-directive tags)
         (eq? category 'keyword))
     ansi-keyword]
    [(or (memq 'objc-header-name tags)
         (memq 'objc-string-literal tags)
         (memq 'objc-char-literal tags)
         (memq 'objc-numeric-literal tags)
         (eq? category 'literal))
     ansi-literal]
    [(or (memq 'objc-identifier tags)
         (eq? category 'identifier))
     ansi-identifier]
    [(or (memq 'objc-literal-introducer tags)
         (memq 'objc-line-splice tags)
         (memq 'objc-operator tags)
         (memq 'objc-delimiter tags)
         (eq? category 'operator)
         (eq? category 'delimiter))
     ansi-delimiter]
    [else
     ""]))

;; makefile-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for Makefile-like roles.
(define (makefile-like-style category tags)
  (cond
    [(or (memq 'makefile-error tags)
         (memq 'malformed-token tags)
         (eq? category 'unknown)
         (eq? category 'malformed))
     ansi-malformed]
    [(or (eq? category 'comment)
         (memq 'comment tags)
         (memq 'makefile-comment tags))
     ansi-comment]
    [(or (memq 'makefile-directive tags)
         (eq? category 'keyword))
     ansi-keyword]
    [(or (memq 'makefile-variable tags)
         (memq 'makefile-rule-target tags)
         (memq 'makefile-paren-variable-reference tags)
         (memq 'makefile-brace-variable-reference tags)
         (memq 'makefile-variable-reference tags)
         (eq? category 'identifier))
     ansi-identifier]
    [(or (memq 'makefile-recipe tags)
         (memq 'embedded-shell tags)
         (memq 'shell-keyword tags)
         (memq 'shell-builtin tags)
         (memq 'shell-variable tags)
         (memq 'shell-word tags)
         (memq 'shell-assignment tags)
         (memq 'shell-string-literal tags)
         (memq 'shell-ansi-string-literal tags)
         (memq 'shell-command-substitution tags)
         (memq 'shell-option tags)
         (memq 'shell-numeric-literal tags)
         (memq 'shell-pipeline-operator tags)
         (memq 'shell-logical-operator tags)
         (memq 'shell-redirection-operator tags)
         (memq 'shell-heredoc-operator tags)
         (memq 'shell-punctuation tags))
     (shell-like-style category tags)]
    [(or (memq 'makefile-assignment-operator tags)
         (memq 'makefile-rule-delimiter tags)
         (memq 'makefile-recipe-separator tags)
         (memq 'makefile-order-only-delimiter tags)
         (eq? category 'operator)
         (eq? category 'delimiter))
     ansi-delimiter]
    [(or (eq? category 'literal)
         (memq 'makefile-ignored tags))
     ansi-literal]
    [else
     ""]))

;; javascript-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for JavaScript-like roles.
(define (javascript-like-style category tags)
  (cond
    [(or (memq 'keyword tags)
         (memq 'static-keyword-usage tags)
         (memq 'jsx-tag-name tags)
         (memq 'jsx-closing-tag-name tags))
     ansi-keyword]
    [(or (memq 'declaration-name tags)
         (memq 'parameter-name tags)
         (memq 'property-name tags)
         (memq 'method-name tags)
         (memq 'private-name tags)
         (memq 'object-key tags)
         (memq 'jsx-attribute-name tags))
     ansi-identifier]
    [(memq 'jsx-text tags)
     ""]
    [(or (memq 'string-literal tags)
         (memq 'numeric-literal tags)
         (memq 'regex-literal tags)
         (memq 'template-literal tags)
         (memq 'template-chunk tags))
     ansi-literal]
    [(or (memq 'jsx-interpolation-boundary tags)
         (memq 'jsx-fragment-boundary tags)
         (memq 'template-interpolation-boundary tags)
         (eq? category 'operator)
         (eq? category 'delimiter))
     ansi-delimiter]
    [(eq? category 'literal)
     ansi-literal]
    [(eq? category 'identifier)
     ansi-identifier]
    [else
     ""]))

;; java-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for Java-like roles.
(define (java-like-style category tags)
  (cond
    [(or (memq 'malformed-token tags)
         (memq 'java-error tags)
         (eq? category 'unknown)
         (eq? category 'malformed))
     ansi-malformed]
    [(or (eq? category 'comment)
         (memq 'comment tags)
         (memq 'java-comment tags)
         (memq 'java-line-comment tags)
         (memq 'java-block-comment tags)
         (memq 'java-doc-comment tags))
     ansi-comment]
    [(or (memq 'java-keyword tags)
         (memq 'java-annotation-name tags)
         (eq? category 'keyword))
     ansi-keyword]
    [(or (memq 'java-string-literal tags)
         (memq 'java-text-block tags)
         (memq 'java-char-literal tags)
         (memq 'java-numeric-literal tags)
         (memq 'java-boolean-literal tags)
         (memq 'java-true-literal tags)
         (memq 'java-false-literal tags)
         (memq 'java-null-literal tags)
         (eq? category 'literal))
     ansi-literal]
    [(or (memq 'java-identifier tags)
         (eq? category 'identifier))
     ansi-identifier]
    [(or (memq 'java-annotation-marker tags)
         (memq 'java-delimiter tags)
         (memq 'java-operator tags)
         (eq? category 'operator)
         (eq? category 'delimiter))
     ansi-delimiter]
    [else
     ""]))

;; json-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for JSON-like roles.
(define (json-like-style category tags)
  (cond
    [(or (memq 'malformed-token tags)
         (memq 'json-error tags)
         (eq? category 'unknown)
         (eq? category 'malformed))
     ansi-malformed]
    [(or (memq 'json-object-key tags)
         (eq? category 'identifier))
     ansi-identifier]
    [(or (memq 'json-string tags)
         (memq 'json-number tags)
         (memq 'json-true tags)
         (memq 'json-false tags)
         (memq 'json-null tags)
         (eq? category 'literal))
     ansi-literal]
    [(or (memq 'json-keyword tags)
         (eq? category 'keyword))
     ansi-keyword]
    [(or (memq 'json-object-start tags)
         (memq 'json-object-end tags)
         (memq 'json-array-start tags)
         (memq 'json-array-end tags)
         (memq 'json-comma tags)
         (memq 'json-colon tags)
         (eq? category 'delimiter)
         (eq? category 'operator))
     ansi-delimiter]
    [else
     ""]))

;; plist-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for plist-like XML roles.
(define (plist-like-style category tags)
  (cond
    [(or (memq 'malformed-token tags)
         (memq 'plist-error tags)
         (eq? category 'unknown)
         (eq? category 'malformed))
     ansi-malformed]
    [(or (eq? category 'comment)
         (memq 'comment tags)
         (memq 'plist-comment tags))
     ansi-comment]
    [(or (memq 'plist-processing-instruction tags)
         (memq 'plist-doctype tags)
         (memq 'plist-tag-name tags)
         (memq 'plist-closing-tag-name tags)
         (eq? category 'keyword))
     ansi-keyword]
    [(or (memq 'plist-attribute-name tags)
         (eq? category 'identifier))
     ansi-identifier]
    [(or (memq 'plist-attribute-value tags)
         (memq 'plist-key-text tags)
         (memq 'plist-string-text tags)
         (memq 'plist-data-text tags)
         (memq 'plist-date-text tags)
         (memq 'plist-integer-text tags)
         (memq 'plist-real-text tags)
         (memq 'plist-entity tags)
         (memq 'plist-text tags)
         (eq? category 'literal))
     ansi-literal]
    [(or (eq? category 'operator)
         (eq? category 'delimiter))
     ansi-delimiter]
    [else
     ""]))

;; tex-like-style : (listof symbol?) -> string?
;;   Choose an ANSI style for TeX and LaTeX roles.
(define (tex-like-style tags)
  (cond
    [(or (memq 'malformed-token tags)
         (memq 'tex-error tags)
         (memq 'latex-error tags))
     ansi-malformed]
    [(or (memq 'tex-comment tags)
         (memq 'comment tags))
     ansi-comment]
    [(or (memq 'tex-control-word tags)
         (memq 'latex-command tags)
         (memq 'latex-environment-command tags)
         (memq 'tex-accent-command tags)
         (memq 'tex-spacing-command tags)
         (memq 'tex-paragraph-command tags)
         (memq 'tex-italic-correction tags)
         (memq 'latex-line-break-command tags))
     ansi-keyword]
    [(or (memq 'latex-environment-name tags)
         (memq 'tex-parameter-reference tags)
         (memq 'tex-parameter-escape tags))
     ansi-identifier]
    [(or (memq 'latex-verbatim-literal tags))
     ansi-literal]
    [(or (memq 'tex-control-symbol tags)
         (memq 'tex-math-shift tags)
         (memq 'tex-display-math-shift tags)
         (memq 'tex-inline-math-shift tags)
         (memq 'tex-group-delimiter tags)
         (memq 'tex-optional-delimiter tags)
         (memq 'tex-special-character tags)
         (memq 'tex-alignment-tab tags)
         (memq 'tex-subscript-mark tags)
         (memq 'tex-superscript-mark tags)
         (memq 'tex-unbreakable-space tags)
         (memq 'tex-control-space tags)
         (memq 'tex-parameter-marker tags))
     ansi-delimiter]
    [else
     ""]))

;; delimited-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for CSV/TSV-like roles.
(define (delimited-like-style category tags)
  (cond
    [(or (memq 'malformed-token tags)
         (memq 'delimited-error tags)
         (eq? category 'unknown)
         (eq? category 'malformed))
     ansi-malformed]
    [(or (memq 'comment tags)
         (eq? category 'comment))
     ansi-comment]
    [(or (memq 'delimited-field-name tags)
         (memq 'delimited-header tags)
         (eq? category 'identifier))
     ansi-identifier]
    [(or (memq 'delimited-quoted-field tags)
         (memq 'delimited-unquoted-field tags)
         (memq 'delimited-empty-field tags)
         (memq 'delimited-bare-field tags)
         (memq 'delimited-field-value tags)
         (eq? category 'literal))
     ansi-literal]
    [(or (memq 'delimited-separator tags)
         (memq 'delimited-record-separator tags)
         (memq 'delimited-quote tags)
         (eq? category 'delimiter)
         (eq? category 'operator))
     ansi-delimiter]
    [else
     ""]))

;; yaml-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for YAML-like roles.
(define (yaml-like-style category tags)
  (cond
    [(or (memq 'malformed-token tags)
         (memq 'yaml-error tags)
         (eq? category 'unknown)
         (eq? category 'malformed))
     ansi-malformed]
    [(or (memq 'yaml-comment tags)
         (eq? category 'comment))
     ansi-comment]
    [(or (memq 'yaml-key-scalar tags)
         (eq? category 'identifier))
     ansi-identifier]
    [(or (memq 'yaml-anchor tags)
         (memq 'yaml-tag tags)
         (memq 'yaml-alias tags))
     ansi-identifier]
    [(or (memq 'yaml-string-literal tags)
         (memq 'yaml-plain-scalar tags)
         (memq 'yaml-block-scalar-content tags)
         (memq 'yaml-number tags)
         (memq 'yaml-boolean tags)
         (memq 'yaml-null tags)
         (eq? category 'literal))
     ansi-literal]
    [(or (memq 'yaml-directive tags)
         (eq? category 'keyword))
     ansi-keyword]
    [(or (memq 'yaml-document-marker tags)
         (memq 'yaml-value-indicator tags)
         (memq 'yaml-sequence-indicator tags)
         (memq 'yaml-flow-delimiter tags)
         (memq 'yaml-block-scalar-header tags)
         (eq? category 'delimiter)
         (eq? category 'operator))
     ansi-delimiter]
    [else
     ""]))

;; python-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for Python-like roles.
(define (python-like-style category tags)
  (cond
    [(or (memq 'malformed-token tags)
         (eq? category 'unknown)
         (eq? category 'malformed))
     ansi-malformed]
    [(or (eq? category 'comment)
         (memq 'comment tags)
         (memq 'python-comment tags))
     ansi-comment]
    [(or (memq 'python-keyword tags)
         (memq 'python-soft-keyword tags)
         (eq? category 'keyword))
     ansi-keyword]
    [(or (memq 'python-string-literal tags)
         (memq 'python-bytes-literal tags)
         (memq 'python-f-string-literal tags)
         (memq 'python-t-string-literal tags)
         (memq 'python-raw-string-literal tags)
         (memq 'python-numeric-literal tags)
         (eq? category 'literal))
     ansi-literal]
    [(or (memq 'python-identifier tags)
         (eq? category 'identifier))
     ansi-identifier]
    [(or (memq 'python-operator tags)
         (memq 'python-delimiter tags)
         (eq? category 'operator)
         (eq? category 'delimiter))
     ansi-delimiter]
    [else
     ""]))

;; pascal-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for Pascal-like roles.
(define (pascal-like-style category tags)
  (cond
    [(or (memq 'malformed-token tags)
         (memq 'pascal-error tags)
         (eq? category 'unknown)
         (eq? category 'malformed))
     ansi-malformed]
    [(or (eq? category 'comment)
         (memq 'comment tags)
         (memq 'pascal-comment tags))
     ansi-comment]
    [(or (memq 'pascal-keyword tags)
         (eq? category 'keyword))
     ansi-keyword]
    [(or (memq 'pascal-string-literal tags)
         (memq 'pascal-control-string tags)
         (memq 'pascal-numeric-literal tags)
         (eq? category 'literal))
     ansi-literal]
    [(or (memq 'pascal-identifier tags)
         (memq 'pascal-escaped-identifier tags)
         (eq? category 'identifier))
     ansi-identifier]
    [(or (memq 'pascal-operator tags)
         (memq 'pascal-delimiter tags)
         (eq? category 'operator)
         (eq? category 'delimiter))
     ansi-delimiter]
    [else
     ""]))

;; swift-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for Swift-like roles.
(define (swift-like-style category tags)
  (cond
    [(or (memq 'swift-error tags)
         (eq? category 'unknown)
         (eq? category 'malformed))
     ansi-malformed]
    [(or (eq? category 'comment)
         (memq 'comment tags)
         (memq 'swift-comment tags))
     ansi-comment]
    [(or (memq 'swift-keyword tags)
         (memq 'swift-attribute tags)
         (memq 'swift-pound-directive tags)
         (eq? category 'keyword))
     ansi-keyword]
    [(or (memq 'swift-string-literal tags)
         (memq 'swift-raw-string-literal tags)
         (memq 'swift-numeric-literal tags)
         (eq? category 'literal))
     ansi-literal]
    [(or (memq 'swift-identifier tags)
         (eq? category 'identifier))
     ansi-identifier]
    [(or (memq 'swift-operator tags)
         (memq 'swift-delimiter tags)
         (eq? category 'operator)
         (eq? category 'delimiter))
     ansi-delimiter]
    [else
     ""]))

;; rust-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for Rust-like roles.
(define (rust-like-style category tags)
  (cond
    [(or (memq 'malformed-token tags)
         (memq 'rust-error tags)
         (eq? category 'unknown)
         (eq? category 'malformed))
     ansi-malformed]
    [(or (eq? category 'comment)
         (memq 'comment tags)
         (memq 'rust-comment tags)
         (memq 'rust-doc-comment tags))
     ansi-comment]
    [(or (memq 'rust-keyword tags)
         (eq? category 'keyword))
     ansi-keyword]
    [(or (memq 'rust-string-literal tags)
         (memq 'rust-raw-string-literal tags)
         (memq 'rust-char-literal tags)
         (memq 'rust-byte-literal tags)
         (memq 'rust-byte-string-literal tags)
         (memq 'rust-c-string-literal tags)
         (memq 'rust-numeric-literal tags)
         (eq? category 'literal))
     ansi-literal]
    [(or (memq 'rust-identifier tags)
         (memq 'rust-raw-identifier tags)
         (memq 'rust-lifetime tags)
         (eq? category 'identifier))
     ansi-identifier]
    [(or (memq 'rust-punctuation tags)
         (memq 'rust-delimiter tags)
         (eq? category 'operator)
         (eq? category 'delimiter))
     ansi-delimiter]
    [else
     ""]))

;; shell-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for shell-like roles.
(define (shell-like-style category tags)
  (cond
    [(or (memq 'malformed-token tags)
         (eq? category 'unknown)
         (eq? category 'malformed))
     ansi-malformed]
    [(or (eq? category 'comment)
         (memq 'comment tags)
         (memq 'shell-comment tags))
     ansi-comment]
    [(or (memq 'shell-keyword tags)
         (memq 'shell-builtin tags)
         (eq? category 'keyword))
     ansi-keyword]
    [(or (memq 'shell-variable tags)
         (memq 'shell-word tags)
         (memq 'shell-assignment tags)
         (eq? category 'identifier))
     ansi-identifier]
    [(or (memq 'shell-string-literal tags)
         (memq 'shell-command-substitution tags)
         (memq 'shell-option tags)
         (memq 'shell-numeric-literal tags)
         (eq? category 'literal))
     ansi-literal]
    [(or (memq 'shell-pipeline-operator tags)
         (memq 'shell-logical-operator tags)
         (memq 'shell-redirection-operator tags)
         (memq 'shell-heredoc-operator tags)
         (memq 'shell-punctuation tags)
         (eq? category 'delimiter))
     ansi-delimiter]
    [else
     ""]))

;; go-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for Go-like roles.
(define (go-like-style category tags)
  (cond
    [(or (memq 'malformed-token tags)
         (memq 'go-error tags)
         (eq? category 'unknown)
         (eq? category 'malformed))
     ansi-malformed]
    [(or (eq? category 'comment)
         (memq 'comment tags)
         (memq 'go-comment tags)
         (memq 'go-line-comment tags)
         (memq 'go-general-comment tags))
     ansi-comment]
    [(or (memq 'go-keyword tags)
         (eq? category 'keyword))
     ansi-keyword]
    [(or (memq 'go-identifier tags)
         (eq? category 'identifier))
     ansi-identifier]
    [(or (memq 'go-string-literal tags)
         (memq 'go-raw-string-literal tags)
         (memq 'go-rune-literal tags)
         (memq 'go-numeric-literal tags)
         (memq 'go-imaginary-literal tags)
         (eq? category 'literal))
     ansi-literal]
    [(or (memq 'go-operator tags)
         (memq 'go-delimiter tags)
         (eq? category 'operator)
         (eq? category 'delimiter))
     ansi-delimiter]
    [else
     ""]))

;; haskell-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for Haskell-like roles.
(define (haskell-like-style category tags)
  (cond
    [(or (memq 'malformed-token tags)
         (memq 'haskell-error tags)
         (eq? category 'unknown)
         (eq? category 'malformed))
     ansi-malformed]
    [(or (eq? category 'comment)
         (memq 'comment tags)
         (memq 'haskell-comment tags)
         (memq 'haskell-line-comment tags)
         (memq 'haskell-nested-comment tags)
         (memq 'haskell-pragma tags))
     ansi-comment]
    [(or (memq 'haskell-keyword tags)
         (eq? category 'keyword))
     ansi-keyword]
    [(or (memq 'haskell-variable-identifier tags)
         (memq 'haskell-constructor-identifier tags)
         (eq? category 'identifier))
     ansi-identifier]
    [(or (memq 'haskell-string-literal tags)
         (memq 'haskell-char-literal tags)
         (memq 'haskell-numeric-literal tags)
         (eq? category 'literal))
     ansi-literal]
    [(or (memq 'haskell-variable-operator tags)
         (memq 'haskell-constructor-operator tags)
         (memq 'haskell-delimiter tags)
         (eq? category 'operator)
         (eq? category 'delimiter))
     ansi-delimiter]
    [else
     ""]))

;; rhombus-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for Rhombus-like roles.
(define (rhombus-like-style category tags)
  (cond
    [(or (memq 'malformed-token tags)
         (memq 'rhombus-error tags)
         (memq 'rhombus-fail tags)
         (eq? category 'unknown)
         (eq? category 'malformed))
     ansi-malformed]
    [(or (eq? category 'comment)
         (memq 'comment tags)
         (memq 'rhombus-comment tags))
     ansi-comment]
    [(or (memq 'rhombus-keyword tags)
         (memq 'rhombus-builtin tags)
         (eq? category 'keyword))
     ansi-keyword]
    [(or (memq 'rhombus-string tags)
         (memq 'rhombus-constant tags)
         (memq 'rhombus-literal tags)
         (eq? category 'literal))
     ansi-literal]
    [(or (memq 'rhombus-identifier tags)
         (eq? category 'identifier))
     ansi-identifier]
    [(or (memq 'rhombus-parenthesis tags)
         (memq 'rhombus-separator tags)
         (memq 'rhombus-opener tags)
         (memq 'rhombus-closer tags)
         (memq 'rhombus-operator tags)
         (memq 'rhombus-block-operator tags)
         (memq 'rhombus-comma-operator tags)
         (memq 'rhombus-at tags)
         (eq? category 'operator)
         (eq? category 'delimiter))
     ansi-delimiter]
    [else
     ""]))

;; wat-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for WAT-like roles.
(define (wat-like-style category tags)
  (cond
    [(or (memq 'wat-form tags)
         (memq 'wat-type tags)
         (memq 'wat-instruction tags)
         (eq? category 'keyword))
     ansi-keyword]
    [(or (memq 'wat-identifier tags)
         (eq? category 'identifier))
     ansi-identifier]
    [(or (memq 'wat-string-literal tags)
         (memq 'wat-numeric-literal tags)
         (eq? category 'literal))
     ansi-literal]
    [(or (eq? category 'comment)
         (memq 'comment tags))
     ansi-comment]
    [(eq? category 'delimiter)
     ansi-delimiter]
    [(or (memq 'malformed-token tags)
         (eq? category 'unknown))
     ansi-malformed]
    [else
     ""]))

;; racket-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for Racket-like roles.
(define (racket-like-style category tags)
  (cond
    [(or (memq 'racket-error tags)
         (eq? category 'unknown))
     ansi-malformed]
    [(or (eq? category 'comment)
         (memq 'racket-comment tags)
         (memq 'racket-sexp-comment tags)
         (memq 'racket-commented-out tags))
     ansi-comment]
    [(or (memq 'racket-usual-special-form tags)
         (memq 'racket-definition-form tags)
         (memq 'racket-binding-form tags)
         (memq 'racket-conditional-form tags))
     ansi-keyword]
    [(or (memq 'racket-string tags)
         (memq 'racket-constant tags)
         (memq 'racket-hash-colon-keyword tags)
         (eq? category 'literal))
     ansi-literal]
    [(or (memq 'racket-parenthesis tags)
         (memq 'racket-open tags)
         (memq 'racket-close tags)
         (memq 'racket-continue tags)
         (eq? category 'delimiter))
     ansi-delimiter]
    [(memq 'racket-no-color tags)
     ""]
    [(or (memq 'racket-symbol tags)
         (memq 'racket-datum tags)
         (eq? category 'identifier))
     ansi-identifier]
    [else
     ""]))

;; scribble-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for Scribble-like roles.
(define (scribble-like-style category tags)
  (cond
    [(or (memq 'scribble-error tags)
         (eq? category 'unknown))
     ansi-malformed]
    [(or (memq 'scribble-comment tags)
         (eq? category 'comment))
     ansi-comment]
    [(memq 'scribble-racket-escape tags)
     (racket-like-style category tags)]
    [(memq 'scribble-text tags)
     ""]
    [(memq 'scribble-command tags)
     ansi-keyword]
    [(or (memq 'scribble-command-char tags)
         (memq 'scribble-body-delimiter tags)
         (memq 'scribble-optional-delimiter tags)
         (memq 'scribble-parenthesis tags)
         (eq? category 'delimiter))
     ansi-delimiter]
    [(or (memq 'scribble-string tags)
         (memq 'scribble-constant tags)
         (eq? category 'literal))
     ansi-literal]
    [(or (memq 'scribble-symbol tags)
         (memq 'scribble-other tags)
         (eq? category 'identifier))
     ansi-identifier]
    [else
     ""]))

;; html-like-style : symbol? (listof symbol?) -> string?
;;   Choose an ANSI style for HTML-like roles.
(define (html-like-style category tags)
  (cond
    [(memq 'embedded-css tags)
     (css-like-style category tags)]
    [(memq 'embedded-javascript tags)
     (javascript-like-style category tags)]
    [(or (memq 'malformed-token tags)
         (eq? category 'unknown))
     ansi-malformed]
    [(or (eq? category 'comment)
         (memq 'comment tags))
     ansi-comment]
    [(or (memq 'html-tag-name tags)
         (memq 'html-closing-tag-name tags)
         (memq 'html-doctype tags)
         (eq? category 'keyword))
     ansi-keyword]
    [(memq 'html-attribute-name tags)
     ansi-identifier]
    [(or (memq 'html-attribute-value tags)
         (memq 'html-entity tags))
     ansi-literal]
    [(memq 'html-text tags)
     ""]
    [(or (eq? category 'operator)
         (eq? category 'delimiter))
     ansi-delimiter]
    [(eq? category 'literal)
     ansi-literal]
    [(eq? category 'identifier)
     ansi-identifier]
    [else
     ""]))

(module+ test
  (require rackunit)

  (check-equal? (css-like-style 'identifier
                                '(function-name))
                ansi-keyword)
  (check-equal? (css-like-style 'identifier
                                '(custom-property-name))
                ansi-identifier)
  (check-equal? (racket-like-style 'identifier
                                   '(racket-no-color))
                "")
  (check-equal? (racket-like-style 'identifier
                                   '(racket-symbol))
                ansi-identifier))
