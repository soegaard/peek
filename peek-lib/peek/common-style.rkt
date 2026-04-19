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
;; javascript-like-style -- Style JavaScript-like embedded tokens.
;; shell-like-style      -- Style shell-like embedded tokens.
;; rhombus-like-style    -- Style Rhombus-like embedded tokens.
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
 ;; javascript-like-style Style JavaScript-like embedded tokens.
 javascript-like-style
 ;; shell-like-style Style shell-like embedded tokens.
 shell-like-style
 ;; rhombus-like-style Style Rhombus-like embedded tokens.
 rhombus-like-style
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
         (member 'at-rule-name tags))
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
         (eq? category 'operator)
         (eq? category 'delimiter))
     ansi-delimiter]
    [(eq? category 'literal)
     ansi-literal]
    [(eq? category 'identifier)
     ansi-identifier]
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
    [(or (memq 'shell-punctuation tags)
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
