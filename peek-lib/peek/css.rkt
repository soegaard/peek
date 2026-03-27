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

;; css-length-rx : regexp?
;;   Recognize a simple CSS numeric length or duration token.
(define css-length-rx
  #px"^([+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+))(px|rem|em|%|vw|vh|vmin|vmax|pt|pc|cm|mm|in|q|ch|ex|s|ms)$")

;; property-token? : css-token? -> boolean?
;;   Determine whether a token names a CSS property.
(define (property-token? token)
  (or (member 'property-name        (css-token-tags token))
      (member 'custom-property-name (css-token-tags token))))

;; whitespace-width-after-newline : string? exact-nonnegative-integer? -> exact-nonnegative-integer?
;;   Measure whitespace width, resetting after the final newline.
(define (whitespace-width-after-newline text prefix-width)
  (define matches
    (regexp-match-positions #px"(?s:.*)\n" text))
  (cond
    [matches (- (string-length text) (cdar matches))]
    [else    (+ prefix-width (string-length text))]))

;; semicolon-part? : (listof css-token?) -> boolean?
;;   Determine whether a block part is a standalone semicolon separator.
(define (semicolon-part? part)
  (match part
    [(list token) (delimiter-token? token ";")]
    [_            #f]))

;; declaration-part? : (listof css-token?) -> boolean?
;;   Determine whether a block part contains a property declaration.
(define (declaration-part? part)
  (for/or ([token part])
    (property-token? token)))

;; comment-only-part? : (listof css-token?) -> boolean?
;;   Determine whether a block part is a comment section separator.
(define (comment-only-part? part)
  (and (for/or ([token part])
         (eq? (css-token-category token) 'comment))
       (not (declaration-part? part))))

;; split-block-parts : (listof css-token?) -> (listof (listof css-token?))
;;   Split a block into declaration-ish parts and semicolon separators.
(define (split-block-parts tokens)
  (let split ([rest tokens] [current '()] [parts '()])
    (cond
      [(null? rest)
       (reverse (if (null? current)
                    parts
                    (cons (reverse current) parts)))]
      [(delimiter-token? (car rest) ";")
       (split (cdr rest)
              '()
              (cons (list (car rest))
                    (cons (reverse current) parts)))]
      [else
       (split (cdr rest)
              (cons (car rest) current)
              parts)])))

;; scan-post-colon : (listof css-token?) exact-nonnegative-integer? -> list?
;;   Measure whitespace immediately after a colon.
(define (scan-post-colon tokens post-width)
  (match tokens
    [(cons token tail)
     (cond
       [(whitespace-token? token)
        (scan-post-colon tail
                         (whitespace-width-after-newline (css-token-text token)
                                                         post-width))]
       [else
        (list post-width tokens)])]
    [_ (list post-width tokens)]))

;; scan-after-property : (listof css-token?) exact-nonnegative-integer? -> (or/c list? #f)
;;   Scan from after the property name to the colon and following whitespace.
(define (scan-after-property tokens name-width)
  (match tokens
    ['() #f]
    [(cons token tail)
     (cond
       [(whitespace-token? token)
        (scan-after-property tail
                             (whitespace-width-after-newline (css-token-text token)
                                                             name-width))]
       [(delimiter-token? token ":")
        (define post+rest
          (scan-post-colon tail 0))
        (list (+ name-width 1)
              (first post+rest)
              (second post+rest))]
       [else
        #f])]))

;; measure-declaration-prefix : (listof css-token?) -> (or/c list? #f)
;;   Return (list prefix-width post-width rest) for a declaration part.
(define (measure-declaration-prefix decl)
  (let scan ([rest decl] [prefix-width 0])
    (match rest
      ['() #f]
      [(cons token tail)
       (cond
         [(whitespace-token? token)
          (scan tail
                (whitespace-width-after-newline (css-token-text token)
                                                prefix-width))]
         [(eq? (css-token-category token) 'comment)
          (scan tail 0)]
         [(property-token? token)
          (scan-after-property tail (string-length (css-token-text token)))]
         [else
          #f])])))

;; drop-post-colon-whitespace : (listof css-token?) -> (listof css-token?)
;;   Drop whitespace immediately after a property colon.
(define (drop-post-colon-whitespace tokens)
  (match tokens
    [(cons token tail)
     (cond
       [(whitespace-token? token)
        (drop-post-colon-whitespace tail)]
       [else
        tokens])]
    [_ tokens]))

;; whitespace-like-token : css-token? string? -> css-token?
;;   Copy a whitespace token or synthesize one from a nearby token.
(define (whitespace-like-token token text)
  (struct-copy css-token token
               [category 'whitespace]
               [text     text]
               [tags     '()]))

;; rebuild-declaration-spacing : (listof css-token?) exact-nonnegative-integer? exact-nonnegative-integer? -> (listof css-token?)
;;   Replace post-colon whitespace so declaration values align.
(define (rebuild-declaration-spacing decl prefix-width max-prefix)
  (define new-post-width
    (+ 1 (- max-prefix prefix-width)))
  (let rebuild ([rest decl] [prefix '()])
    (match rest
      ['() (reverse prefix)]
      [(cons token tail)
       (cond
         [(delimiter-token? token ":")
          (define new-space
            (whitespace-like-token token (make-string new-post-width #\space)))
          (append (reverse (cons token prefix))
                  (list new-space)
                  (drop-post-colon-whitespace tail))]
         [else
          (rebuild tail (cons token prefix))])])))

;; declaration-value-tokens : (listof css-token?) -> (or/c (listof css-token?) #f)
;;   Collect simple value tokens after the colon, or #f for complex values.
(define (declaration-value-tokens decl)
  (let loop ([rest decl] [after-colon? #f] [values '()])
    (cond
      [(null? rest)
       (and after-colon? (reverse values))]
      [else
       (define token
         (car rest))
       (cond
         [(not after-colon?)
          (loop (cdr rest)
                (delimiter-token? token ":")
                values)]
         [(or (whitespace-token? token)
              (eq? (css-token-category token) 'comment))
          (loop (cdr rest) #t values)]
         [(delimiter-token? token ";")
          (and after-colon? (reverse values))]
         [(eq? (css-token-category token) 'delimiter)
          #f]
         [else
          (loop (cdr rest) #t (cons token values))])])))

;; declaration-single-length : (listof css-token?) -> (or/c (cons string? string?) #f)
;;   Recognize a declaration whose value is a single CSS length token.
(define (declaration-single-length decl)
  (define values
    (declaration-value-tokens decl))
  (and values
       (= (length values) 1)
       (let ([match (regexp-match css-length-rx
                                  (css-token-text (car values)))])
         (and match
              (cons (list-ref match 1)
                    (list-ref match 2))))))

;; replace-first-value-token : (listof css-token?) string? string? -> (listof css-token?)
;;   Replace the first matching declaration-value token text.
(define (replace-first-value-token decl old-text new-text)
  (define replaced? #f)
  (for/list ([token decl])
    (cond
      [(and (not replaced?)
            (member 'declaration-value-token (css-token-tags token))
            (string=? (css-token-text token) old-text))
       (set! replaced? #t)
       (struct-copy css-token token [text new-text])]
      [else
       token])))

;; collect-unit-run : (listof (listof css-token?)) string? -> pair?
;;   Collect adjacent declaration parts sharing the same simple value unit.
(define (collect-unit-run parts unit)
  (let loop ([rest parts] [run '()])
    (cond
      [(null? rest)           (cons (reverse run) rest)]
      [(semicolon-part? (car rest))
       (loop (cdr rest) run)]
      [else
       (define info
         (declaration-single-length (car rest)))
       (cond
         [(and info (string=? (cdr info) unit))
          (loop (cdr rest) (cons (car rest) run))]
         [else
          (cons (reverse run) rest)])])))

;; pad-unit-run : (listof (listof css-token?)) -> (listof (listof css-token?))
;;   Right-align numeric parts within a same-unit run.
(define (pad-unit-run run)
  (define infos
    (map declaration-single-length run))
  (define max-width
    (apply max
           (map (lambda (info)
                  (string-length (car info)))
                infos)))
  (for/list ([decl run] [info infos])
    (define number-text
      (car info))
    (define unit-text
      (cdr info))
    (define padded
      (string-append (make-string (- max-width (string-length number-text))
                                  #\space)
                     number-text
                     unit-text))
    (replace-first-value-token decl
                               (string-append number-text unit-text)
                               padded)))

;; interleave-semicolons : (listof (listof css-token?)) -> (listof (listof css-token?))
;;   Reinsert semicolon parts between declaration parts.
(define (interleave-semicolons decls)
  (define sep
    (list (css-token 'delimiter ";" '() #f #f)))
  (let loop ([rest decls] [parts '()])
    (cond
      [(null? rest)       (reverse parts)]
      [(null? (cdr rest)) (reverse (cons (car rest) parts))]
      [else
       (loop (cdr rest)
             (cons sep (cons (car rest) parts)))])))

;; process-unit-run : (listof (listof css-token?)) (listof (listof css-token?)) -> (values (listof (listof css-token?)) (listof (listof css-token?)))
;;   Right-align one adjacent same-unit run when beneficial.
(define (process-unit-run rest acc)
  (define info
    (declaration-single-length (car rest)))
  (cond
    [(not info)
     (values (cdr rest) (cons (car rest) acc))]
    [else
     (define run+tail
       (collect-unit-run rest (cdr info)))
     (define run
       (car run+tail))
     (define tail
       (cdr run+tail))
     (cond
       [(< (length run) 2)
        (values (cdr rest) (cons (car rest) acc))]
       [else
        (values tail
                (append (reverse (interleave-semicolons (pad-unit-run run)))
                        acc))])]))

;; right-align-number-runs : (listof (listof css-token?)) -> (listof (listof css-token?))
;;   Right-align adjacent same-unit numeric declaration values.
(define (right-align-number-runs parts)
  (let loop ([rest parts] [acc '()])
    (cond
      [(null? rest) (reverse acc)]
      [(semicolon-part? (car rest))
       (loop (cdr rest) (cons (car rest) acc))]
      [else
       (define-values (rest* acc*)
         (process-unit-run rest acc))
       (loop rest* acc*)])))

;; align-declaration-group : (listof (listof css-token?)) -> (listof (listof css-token?))
;;   Colon-align and then numeric-align one declaration group.
(define (align-declaration-group parts)
  (define infos
    (map measure-declaration-prefix parts))
  (define max-prefix
    (for/fold ([current-max 0]) ([info infos])
      (cond
        [info (max current-max (first info))]
        [else current-max])))
  (define colon-aligned
    (for/list ([part parts] [info infos])
      (cond
        [info
         (rebuild-declaration-spacing part (first info) max-prefix)]
        [else
         part])))
  (right-align-number-runs colon-aligned))

;; align-block-parts : (listof css-token?) -> (listof css-token?)
;;   Align one simple declaration block while preserving separators.
(define (align-block-parts block)
  (define parts
    (split-block-parts block))
  (define aligned-parts
    (let group-loop ([rest parts] [current '()] [acc '()])
      (cond
        [(null? rest)
         (append acc (align-declaration-group (reverse current)))]
        [(comment-only-part? (car rest))
         (group-loop (cdr rest)
                     (list (car rest))
                     (append acc (align-declaration-group (reverse current))))]
        [else
         (group-loop (cdr rest)
                     (cons (car rest) current)
                     acc)])))
  (append-map values aligned-parts))

;; collect-brace-block : (listof css-token?) -> (values (listof css-token?) (or/c css-token? #f) (listof css-token?))
;;   Collect tokens through the matching close brace after an open brace.
(define (collect-brace-block tokens)
  (let loop ([rest tokens] [depth 1] [block '()])
    (cond
      [(null? rest)
       (values (reverse block) #f '())]
      [else
       (define token
         (car rest))
       (cond
         [(delimiter-token? token "{")
          (loop (cdr rest) (add1 depth) (cons token block))]
         [(delimiter-token? token "}")
          (cond
            [(= depth 1)
             (values (reverse block) token (cdr rest))]
            [else
             (loop (cdr rest) (sub1 depth) (cons token block))])]
         [else
          (loop (cdr rest) depth (cons token block))])])))

;; align-css-tokens : (listof css-token?) -> (listof css-token?)
;;   Align simple CSS declaration blocks without cross-rule alignment.
(define (align-css-tokens tokens)
  (let loop ([rest tokens] [acc '()])
    (cond
      [(null? rest)
       (reverse acc)]
      [(delimiter-token? (car rest) "{")
       (define open-token
         (car rest))
       (define-values (block close-token tail)
         (collect-brace-block (cdr rest)))
       (define aligned-block
         (let ([nested-aligned (align-css-tokens block)])
           (cond
             [(for/or ([token nested-aligned])
                (or (delimiter-token? token "{")
                    (delimiter-token? token "}")))
              nested-aligned]
             [else
              (align-block-parts nested-aligned)])))
       (define rebuilt
         (append (list open-token)
                 aligned-block
                 (if close-token
                     (list close-token)
                     '())))
       (loop tail
             (append (reverse rebuilt) acc))]
      [else
       (loop (cdr rest) (cons (car rest) acc))])))

;; render-css-preview : string? keyword-arguments -> string?
;;   Render CSS with ANSI coloring and optional CSS-specific enhancements.
(define (render-css-preview source
                            #:align?    [align? #f]
                            #:swatches? [swatches? #t])
  (define tokens
    (annotate-css-tokens source))
  (define effective-tokens
    (if align?
        (align-css-tokens tokens)
        tokens))
  (define insertions
    (build-swatch-plan effective-tokens swatches?))
  (apply string-append
         (for/list ([token effective-tokens] [index (in-naturals)])
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
     (regexp-match? #px"margin:\\s+8px;" plain)))
  (check-true
   (let* ([commented (render-css-preview (string-append ".a {\n"
                                                        "  color: #111111;\n"
                                                        "  /* section */\n"
                                                        "  border-color: #222222;\n"
                                                        "  color: #333333;\n"
                                                        "}\n")
                                         #:align? #t)]
          [plain (strip-ansi commented)])
     (and (regexp-match? #px"color:\\s+#111111(?:\\s+█)?;" plain)
          (regexp-match? #px"border-color:\\s+#222222(?:\\s+█)?;" plain)
          (regexp-match? #px"/\\* section \\*/" plain))))
  (check-true
   (let* ([nested (render-css-preview (string-append "@media screen {\n"
                                                     "  .a {\n"
                                                     "    color: red;\n"
                                                     "    margin: 8px;\n"
                                                     "  }\n"
                                                     "}\n")
                                      #:align? #t
                                      #:swatches? #f)]
          [plain (strip-ansi nested)])
     (regexp-match? #px"@media screen \\{\n  \\.a \\{\n    color:\\s+red;\n    margin:\\s+8px;\n  \\}\n\\}\n"
                    plain))))
