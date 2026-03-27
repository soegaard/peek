#lang racket/base

;;;
;;; CSS Preview
;;;
;;
;; CSS-specific terminal preview rendering built on lexers/css.

;; render-css-preview : string? keyword-arguments -> string?
;;   Render CSS with ANSI coloring and optional CSS-specific enhancements.

(provide
 ;; render-css-preview : string? #:align? boolean? #:swatches? boolean? -> string?
 ;;   Render CSS for terminal preview.
 render-css-preview)

(require lexers/css
         lexers/token
         parser-tools/lex
         racket/list
         racket/match
         racket/set
         racket/string)

(struct css-token (category text tags start end) #:transparent)
(struct css-decl (indent name before-colon after-colon value suffix comment?) #:transparent)
(struct swatch-insertion (kind data width) #:transparent)

;; ANSI color constants.
(define (ansi . codes)
  (string-append "\033[" (string-join (map number->string codes) ";") "m"))

(define ansi-reset          (ansi 0))
(define ansi-comment        (ansi 38 2 106 153 85))
(define ansi-keyword        (ansi 38 2 7 170 204))
(define ansi-identifier     (ansi 38 2 156 220 254))
(define ansi-literal        (ansi 38 2 206 145 120))
(define ansi-delimiter      (ansi 38 2 128 128 128))
(define ansi-malformed      (ansi 38 2 244 71 71))

;; css-token-key : css-token -> list?
;;   Build a key for joining projected and derived tokens.
(define (css-token-key token)
  (list (position-offset (css-token-start token))
        (position-offset (css-token-end token))
        (css-token-text token)))

;; derived-token-key : css-derived-token? -> list?
;;   Build a key for a derived CSS token.
(define (derived-token-key token)
  (list (position-offset (css-derived-token-start token))
        (position-offset (css-derived-token-end token))
        (css-derived-token-text token)))

;; annotate-css-tokens : string? -> (listof css-token?)
;;   Combine projected categories with derived CSS tags.
(define (annotate-css-tokens source)
  (define projected
    (css-string->tokens source #:profile 'coloring))
  (define derived
    (css-string->derived-tokens source))
  (define derived-tags-by-key
    (for/hash ([token derived])
      (values (derived-token-key token)
              (css-derived-token-tags token))))
  (for/list ([token projected]
             #:unless (lexer-token-eof? token))
    (define start (lexer-token-start token))
    (define end   (lexer-token-end token))
    (define text  (lexer-token-value token))
    (define base
      (css-token (lexer-token-name token)
                 text
                 '()
                 start
                 end))
    (define tags
      (hash-ref derived-tags-by-key (css-token-key base) '()))
    (struct-copy css-token base [tags tags])))

;; css-color-keywords : (setof string?)
;;   A small practical set of named CSS colors.
(define css-color-keywords
  (list->set '("black" "white" "gray" "grey" "silver"
               "red" "green" "blue" "yellow" "orange" "purple"
               "pink" "brown" "cyan" "magenta" "lime" "teal"
               "navy" "olive" "maroon" "aqua" "fuchsia")))

;; hex-color->rgb : string? -> (or/c (list byte? byte? byte?) #f)
;;   Convert a CSS hex color to RGB.
(define (hex-color->rgb text)
  (define cleaned
    (string-downcase (string-trim text "#")))
  (define expanded
    (cond
      [(= (string-length cleaned) 3)
       (apply string-append
              (for/list ([ch (in-string cleaned)])
                (string ch ch)))]
      [(= (string-length cleaned) 6)
       cleaned]
      [else
       #f]))
  (cond
    [(not expanded) #f]
    [else
     (list (string->number (substring expanded 0 2) 16)
           (string->number (substring expanded 2 4) 16)
           (string->number (substring expanded 4 6) 16))]))

;; clamp-byte : real? -> byte?
;;   Clamp a numeric channel to the terminal RGB range.
(define (clamp-byte value)
  (inexact->exact
   (round (min 255 (max 0 value)))))

;; parse-css-numbers : string? -> (listof number?)
;;   Extract CSS numeric arguments from a function call.
(define (parse-css-numbers text)
  (for/list ([match (in-list (regexp-match* #px"[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)%?" text))])
    (cond
      [(string-suffix? match "%")
       (/ (string->number (substring match 0 (sub1 (string-length match))))
          100.0)]
      [else
       (string->number match)])))

;; hue->rgb : real? real? real? -> (list real? real? real?)
;;   Convert a simple HSL color to RGB in 0-255 space.
(define (hue->rgb h s l)
  (define c
    (* (- 1 (abs (- (* 2 l) 1))) s))
  (define h*
    (/ h 60.0))
  (define x
    (* c (- 1 (abs (- (modulo h* 2) 1)))))
  (define-values (r1 g1 b1)
    (cond
      [(< h* 1) (values c x 0)]
      [(< h* 2) (values x c 0)]
      [(< h* 3) (values 0 c x)]
      [(< h* 4) (values 0 x c)]
      [(< h* 5) (values x 0 c)]
      [else     (values c 0 x)]))
  (define m
    (- l (/ c 2)))
  (list (* 255 (+ r1 m))
        (* 255 (+ g1 m))
        (* 255 (+ b1 m))))

;; css-color->rgb : string? -> (or/c (list byte? byte? byte?) #f)
;;   Convert a practical subset of CSS colors to RGB.
(define (css-color->rgb text)
  (define trimmed
    (string-trim text))
  (define down
    (string-downcase trimmed))
  (cond
    [(or (string=? down "transparent")
         (string=? down "currentcolor"))
     #f]
    [(set-member? css-color-keywords down)
     (case (string->symbol down)
       [(black)   '(0 0 0)]
       [(white)   '(255 255 255)]
       [(gray grey) '(128 128 128)]
       [(silver)  '(192 192 192)]
       [(red)     '(255 0 0)]
       [(green)   '(0 128 0)]
       [(blue)    '(0 0 255)]
       [(yellow)  '(255 255 0)]
       [(orange)  '(255 165 0)]
       [(purple)  '(128 0 128)]
       [(pink)    '(255 192 203)]
       [(brown)   '(165 42 42)]
       [(cyan aqua) '(0 255 255)]
       [(magenta fuchsia) '(255 0 255)]
       [(lime)    '(0 255 0)]
       [(teal)    '(0 128 128)]
       [(navy)    '(0 0 128)]
       [(olive)   '(128 128 0)]
       [(maroon)  '(128 0 0)]
       [else      #f])]
    [(regexp-match? #px"^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$" trimmed)
     (hex-color->rgb trimmed)]
    [(regexp-match? #px"^(?:rgb|rgba)\\(" down)
     (define nums
       (parse-css-numbers trimmed))
     (and (>= (length nums) 3)
          (list (clamp-byte (list-ref nums 0))
                (clamp-byte (list-ref nums 1))
                (clamp-byte (list-ref nums 2))))]
    [(regexp-match? #px"^(?:hsl|hsla)\\(" down)
     (define nums
       (parse-css-numbers trimmed))
     (and (>= (length nums) 3)
          (let* ([rgb (hue->rgb (list-ref nums 0)
                                (list-ref nums 1)
                                (list-ref nums 2))])
            (map clamp-byte rgb)))]
    [else
     #f]))

;; named-color-token? : css-token -> boolean?
;;   Recognize an identifier token that names a practical CSS color.
(define (named-color-token? token)
  (and (eq? (css-token-category token) 'identifier)
       (set-member? css-color-keywords
                    (string-downcase (css-token-text token)))))

;; colorize-text : string? string? -> string?
;;   Colorize text and preserve coloring across newlines.
(define (colorize-text code text)
  (cond
    [(or (string=? code "") (string=? text "")) text]
    [else
     (string-append code
                    (string-join (string-split text "\n" #:trim? #f)
                                 (string-append ansi-reset "\n" code))
                    ansi-reset)]))

;; token-style : css-token -> string?
;;   Choose an ANSI style for a normalized CSS token.
(define (token-style token)
  (define category
    (css-token-category token))
  (define tags
    (css-token-tags token))
  (cond
    [(eq? category 'comment) ansi-comment]
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
    [(eq? category 'delimiter) ansi-delimiter]
    [(eq? category 'unknown) ansi-malformed]
    [(eq? category 'literal) ansi-literal]
    [(eq? category 'identifier) ansi-identifier]
    [else ""]))

;; whitespace-token? : css-token -> boolean?
;;   Determine whether a token is whitespace.
(define (whitespace-token? token)
  (eq? (css-token-category token) 'whitespace))

;; delimiter-token? : css-token string? -> boolean?
;;   Determine whether a token is the given delimiter.
(define (delimiter-token? token text)
  (and (eq? (css-token-category token) 'delimiter)
       (string=? (css-token-text token) text)))

;; token-display-width : css-token -> exact-nonnegative-integer?
;;   Measure the visible width of a token's source text.
(define (token-display-width token)
  (string-length (css-token-text token)))

;; swatch-string : byte? byte? byte? -> string?
;;   Render one visible color swatch.
(define (swatch-string r g b)
  (string-append " "
                 (ansi 38 2 r g b)
                 "█"
                 ansi-reset))

;; gradient-swatch-string : (listof (list byte? byte? byte?)) -> string?
;;   Render one visible swatch cell per gradient stop.
(define (gradient-swatch-string colors)
  (string-append " "
                 (apply string-append
                        (for/list ([rgb colors])
                          (match rgb
                            [(list r g b)
                             (string-append (ansi 38 2 r g b) "█")]
                            [_ ""])))
                 ansi-reset))

;; swatch-width : swatch-insertion -> exact-nonnegative-integer?
;;   Measure the visible width of a swatch insertion.
(define (swatch-width insertion)
  (swatch-insertion-width insertion))

;; safe-color-string? : string? -> boolean?
;;   Recognize practical CSS strings safe to inspect as colors.
(define (safe-color-string? text)
  (and (regexp-match? #px"^[#(),.%+\\-/_a-zA-Z0-9\\s]+$" text)
       (not (regexp-match? #px";" text))))

;; skip-leading-whitespace : (listof css-token?) -> (listof css-token?)
;;   Skip leading whitespace tokens.
(define (skip-leading-whitespace tokens)
  (cond
    [(null? tokens)                     '()]
    [(whitespace-token? (car tokens))   (skip-leading-whitespace (cdr tokens))]
    [else                               tokens]))

;; consume-function-call : (listof css-token?) -> (values (listof css-token?) (listof css-token?) string?)
;;   Consume a function token followed by a balanced parenthesized body.
(define (consume-function-call tokens)
  (let loop ([rest  (cddr tokens)]
             [depth 1]
             [acc   (list (cadr tokens) (car tokens))])
    (cond
      [(null? rest)
       (values '() tokens "")]
      [else
       (define token
         (car rest))
       (define new-depth
         (cond
           [(delimiter-token? token "(") (add1 depth)]
           [(delimiter-token? token ")") (sub1 depth)]
           [else                         depth]))
       (define new-acc
         (cons token acc))
       (cond
         [(zero? new-depth)
          (define taken
            (reverse new-acc))
          (values taken
                  (cdr rest)
                  (apply string-append (map css-token-text taken)))]
         [else
          (loop (cdr rest) new-depth new-acc)])])))

;; call-start-token? : css-token (listof symbol?) -> boolean?
;;   Determine whether a token starts a tagged function call.
(define (call-start-token? token tags)
  (and (eq? (css-token-category token) 'literal)
       (for/or ([tag tags])
         (member tag (css-token-tags token)))))

;; gradient-stop-colors : (listof css-token?) -> (listof (list byte? byte? byte?))
;;   Collect renderable gradient stop colors from a function token sequence.
(define (gradient-stop-colors tokens)
  (let loop ([rest tokens] [colors '()])
    (cond
      [(null? rest)
       (reverse colors)]
      [(call-start-token? (car rest) '(color-function))
       (define-values (taken tail text)
         (consume-function-call rest))
       (define rgb
         (and (safe-color-string? text)
              (css-color->rgb text)))
       (loop tail (if rgb (cons rgb colors) colors))]
      [else
       (define token
         (car rest))
       (define rgb
         (cond
           [(member 'color-literal (css-token-tags token))
            (css-color->rgb (css-token-text token))]
           [(named-color-token? token)
            (css-color->rgb (css-token-text token))]
           [else
            #f]))
       (loop (cdr rest)
             (if rgb (cons rgb colors) colors))])))

;; collect-custom-property-colors : (listof css-token?) -> immutable-hash?
;;   Scan tokens for simple custom property color definitions.
(define (collect-custom-property-colors tokens)
  (let loop ([rest tokens] [table (hash)])
    (cond
      [(null? rest) table]
      [(and (pair? rest)
            (member 'custom-property-name (css-token-tags (car rest))))
       (define name
         (css-token-text (car rest)))
       (define after-name
         (skip-leading-whitespace (cdr rest)))
       (cond
         [(and (pair? after-name)
               (delimiter-token? (car after-name) ":"))
          (define-values (value-text tail)
            (collect-value-text (cdr after-name)))
          (define rgb
            (and (safe-color-string? value-text)
                 (css-color->rgb value-text)))
          (loop tail
                (if rgb
                    (hash-set table name rgb)
                    table))]
         [else
          (loop (cdr rest) table)])]
      [else
       (loop (cdr rest) table)])))

;; collect-value-text : (listof css-token?) -> (values string? (listof css-token?))
;;   Collect a declaration value up to a top-level semicolon or close brace.
(define (collect-value-text tokens)
  (let loop ([rest tokens] [depth 0] [acc '()])
    (cond
      [(null? rest)
       (values (string-trim (apply string-append (reverse acc))) '())]
      [else
       (define token
         (car rest))
       (cond
         [(and (zero? depth)
               (or (delimiter-token? token ";")
                   (delimiter-token? token "}")))
          (values (string-trim (apply string-append (reverse acc))) rest)]
         [(delimiter-token? token "(")
          (loop (cdr rest) (add1 depth) (cons (css-token-text token) acc))]
         [(delimiter-token? token ")")
          (loop (cdr rest) (max 0 (sub1 depth)) (cons (css-token-text token) acc))]
         [else
          (loop (cdr rest) depth (cons (css-token-text token) acc))])])))

;; detect-var-color : (listof css-token?) immutable-hash? -> (values (or/c swatch-insertion? #f) exact-nonnegative-integer?)
;;   Detect a simple var(--name) call and resolve it to a swatch.
(define (detect-var-color tokens table)
  (define-values (taken _tail _text)
    (consume-function-call tokens))
  (define custom-name
    (for/first ([token taken]
                #:when (member 'custom-property-name (css-token-tags token)))
      (css-token-text token)))
  (define rgb
    (and custom-name
         (hash-ref table custom-name #f)))
  (values (and rgb (swatch-insertion 'swatch rgb 2))
          (length taken)))

;; build-swatch-plan : (listof css-token?) boolean? -> hash?
;;   Plan swatch insertions keyed by token index.
(define (build-swatch-plan tokens swatches?)
  (cond
    [(not swatches?) (hash)]
    [else
     (define custom-property-colors
       (collect-custom-property-colors tokens))
     (let loop ([rest tokens] [index 0] [plan (hash)])
       (cond
         [(null? rest) plan]
         [(call-start-token? (car rest) '(gradient-function))
          (define-values (taken tail _text)
            (consume-function-call rest))
          (define colors
            (gradient-stop-colors taken))
          (define insertion
            (and (pair? colors)
                 (swatch-insertion 'gradient colors (+ 1 (length colors)))))
          (loop tail
                (+ index (length taken))
                (if insertion
                    (hash-set plan (+ index (sub1 (length taken))) insertion)
                    plan))]
         [(call-start-token? (car rest) '(color-function))
          (define-values (taken tail text)
            (consume-function-call rest))
          (define rgb
            (and (safe-color-string? text)
                 (css-color->rgb text)))
          (define insertion
            (and rgb (swatch-insertion 'swatch rgb 2)))
          (loop tail
                (+ index (length taken))
                (if insertion
                    (hash-set plan (+ index (sub1 (length taken))) insertion)
                    plan))]
         [(member 'color-literal (css-token-tags (car rest)))
          (define rgb
            (css-color->rgb (css-token-text (car rest))))
         (define insertion
            (and rgb (swatch-insertion 'swatch rgb 2)))
          (loop (cdr rest)
                (add1 index)
                (if insertion
                    (hash-set plan index insertion)
                    plan))]
         [(named-color-token? (car rest))
          (define rgb
            (css-color->rgb (css-token-text (car rest))))
          (define insertion
            (and rgb (swatch-insertion 'swatch rgb 2)))
          (loop (cdr rest)
                (add1 index)
                (if insertion
                    (hash-set plan index insertion)
                    plan))]
         [(and (eq? (css-token-category (car rest)) 'literal)
               (string-ci=? (css-token-text (car rest)) "var")
               (pair? (cdr rest))
               (delimiter-token? (cadr rest) "("))
          (define-values (insertion consumed)
            (detect-var-color rest custom-property-colors))
          (loop (drop rest consumed)
                (+ index consumed)
                (if insertion
                    (hash-set plan (+ index (sub1 consumed)) insertion)
                    plan))]
         [else
          (loop (cdr rest) (add1 index) plan)]))]))

;; insertion->text : swatch-insertion -> string?
;;   Render a planned swatch insertion.
(define (insertion->text insertion)
  (match insertion
    [(swatch-insertion 'swatch (list r g b) _)
     (swatch-string r g b)]
    [(swatch-insertion 'gradient colors _)
     (gradient-swatch-string colors)]
    [_
     ""]))

;; single-length-value : css-decl -> (or/c (cons string? string?) #f)
;;   Recognize a simple single CSS length value.
(define (single-length-value decl)
  (define trimmed
    (string-trim (css-decl-value decl)))
  (define match
    (regexp-match #px"^([+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+))(px|rem|em|%|vw|vh|vmin|vmax|pt|pc|cm|mm|in|q|ch|ex|s|ms)$"
                  trimmed))
  (and match
       (cons (list-ref match 1)
             (list-ref match 2))))

;; align-numeric-values : (listof css-decl?) -> (listof css-decl?)
;;   Right-align simple same-unit numeric values.
(define (align-numeric-values decls)
  (define groups
    (for/fold ([table (hash)]) ([decl decls] [index (in-naturals)])
      (define info
        (single-length-value decl))
      (cond
        [info
         (hash-update table
                      (cdr info)
                      (lambda (items) (cons (cons index info) items))
                      '())]
        [else
         table])))
  (for/fold ([updated decls]) ([(unit entries) (in-hash groups)])
    (define ordered
      (reverse entries))
    (cond
      [(< (length ordered) 2) updated]
      [else
       (define max-width
         (apply max
                (map (lambda (entry)
                       (string-length (car (cdr entry))))
                     ordered)))
       (for/fold ([current updated]) ([entry ordered])
         (define index
           (car entry))
         (define num
           (car (cdr entry)))
         (define padded
           (string-append (make-string (- max-width (string-length num)) #\space)
                          num
                          unit))
         (list-set current
                   index
                   (struct-copy css-decl (list-ref current index)
                                [value padded])))])))

;; parse-block-decls : string? -> (values string? (listof css-decl?) string?)
;;   Parse block contents into declarations while preserving surrounding text.
(define (parse-block-decls block-text)
  (define lines
    (string-split block-text "\n" #:trim? #f))
  (define trailing-newline?
    (and (pair? lines)
         (string=? (last lines) "")))
  (define real-lines
    (if trailing-newline? (drop-right lines 1) lines))
  (define decls
    (for/list ([line real-lines])
      (define match
        (regexp-match #px"^(\\s*)([^:;{}\\s][^:;{}]*?)(\\s*):(\\s*)([^;{}]*?)(\\s*;?\\s*)$"
                      line))
      (cond
        [match
         (css-decl (list-ref match 1)
                   (string-trim (list-ref match 2))
                   (list-ref match 3)
                   (list-ref match 4)
                   (string-trim (list-ref match 5))
                   (list-ref match 6)
                   #f)]
        [else
         (css-decl "" "" "" "" line "" #t)])))
  (values "" decls (if trailing-newline? "\n" "")))

;; align-block-text : string? -> string?
;;   Align one CSS declaration block.
(define (align-block-text block-text)
  (define-values (_prefix decls suffix)
    (parse-block-decls block-text))
  (define real-decls
    (filter (lambda (decl) (not (css-decl-comment? decl))) decls))
  (cond
    [(null? real-decls) block-text]
    [else
     (define max-name-width
       (apply max
              (map (lambda (decl) (string-length (css-decl-name decl)))
                   real-decls)))
     (define aligned-decls
       (align-numeric-values
        (for/list ([decl decls])
          (cond
            [(css-decl-comment? decl) decl]
            [else
             (struct-copy css-decl decl
                          [after-colon
                           (make-string (+ 1 (- max-name-width
                                                (string-length (css-decl-name decl))))
                                        #\space)])]))))
     (string-append
      (string-join
       (for/list ([decl aligned-decls])
         (cond
           [(css-decl-comment? decl)
            (css-decl-value decl)]
           [else
            (string-append (css-decl-indent decl)
                           (css-decl-name decl)
                           ":"
                           (css-decl-after-colon decl)
                           (css-decl-value decl)
                           (if (string=? (string-trim (css-decl-suffix decl)) "")
                               ";"
                               (css-decl-suffix decl)))]))
       "\n")
      suffix)]))

;; align-css-source : string? -> string?
;;   Align simple CSS blocks without attempting cross-rule alignment.
(define (align-css-source source)
  (regexp-replace* #px"\\{([^{}]*)\\}"
                   source
                   (lambda (whole block)
                     (string-append "{"
                                    (align-block-text block)
                                    "}"))))

;; render-css-preview : string? keyword-arguments -> string?
;;   Render CSS with ANSI coloring and optional CSS-specific enhancements.
(define (render-css-preview source
                            #:align?    [align? #f]
                            #:swatches? [swatches? #t])
  (define effective-source
    (if align? (align-css-source source) source))
  (define tokens
    (annotate-css-tokens effective-source))
  (define insertions
    (build-swatch-plan tokens swatches?))
  (apply string-append
         (for/list ([token tokens] [index (in-naturals)])
           (string-append
            (colorize-text (token-style token)
                           (css-token-text token))
            (cond
              [(hash-ref insertions index #f)
               => insertion->text]
              [else
               ""])))))

(module+ test
  (require rackunit)

  (define sample-css
    (string-append ".box {\n"
                   "  color: #ff0000;\n"
                   "  margin: 8px;\n"
                   "  background: linear-gradient(red, blue);\n"
                   "}\n"))

  (define no-swatch-css
    (render-css-preview sample-css
                        #:swatches? #f))
  (define swatch-css
    (render-css-preview sample-css))
  (define aligned-css
    (render-css-preview sample-css
                        #:align? #t))

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (check-true (regexp-match? #px"\u001b\\[" swatch-css))
  (check-true (regexp-match? #px"█" swatch-css))
  (check-false (regexp-match? #px"█" no-swatch-css))
  (check-true (regexp-match? #px"linear-gradient" swatch-css))
  (check-true
   (let ([plain (strip-ansi aligned-css)])
     (regexp-match? #px"color:\\s+#ff0000(?:\\s+█)?;" plain)))
  (check-true
   (let ([plain (strip-ansi aligned-css)])
     (regexp-match? #px"margin:\\s+8px;" plain))))
