#lang racket/base

;;;
;;; Assembly Preview
;;;

;; Terminal rendering and inspection serialization for the byte-preserving
;; generic assembly stream supplied by `lexers/asm`.

;; render-asm-preview              : string? ... -> string?
;;   Render UTF-8 assembly source with safe terminal text and optional color.
;; render-asm-preview-port         : input-port? ... -> void?
;;   Stream-render byte-authoritative assembly source to an output port.
;; assembly-input-kind             : bytes? assembly-options? -> symbol?
;;   Classify a sampled input representation before source rendering.
;; assembly-resolution?            : any/c -> boolean?
;;   Recognize a bounded automatic-selection decision for one input prefix.
;; resolve-assembly-options        : bytes? assembly-options? ... -> assembly-resolution?
;;   Select a qualified profile or a conservative generic fallback for a prefix.
;; assembly-probe-plausibly-source? : assembly-resolution? -> boolean?
;;   Determine whether profile evidence admits automatic assembly-family routing.
;; assembly-detection-jsexpr       : input-probe? ... -> jsexpr?
;;   Convert bounded assembly inspection facts into a stable JSON value.
;; write-asm-token-jsonl           : input-port? ... -> void?
;;   Stream byte-preserving derived tokens as ANSI-free JSON lines.
;; write-assembly-explanation      : input-probe? ... -> void?
;;   Write a concise assembly selection explanation to a diagnostic port.

(provide render-asm-preview
         render-asm-preview-port
         assembly-input-kind
         (struct-out assembly-resolution)
         resolve-assembly-options
         assembly-probe-plausibly-source?
         assembly-detection-jsexpr
         write-asm-token-jsonl
         write-assembly-explanation)

(require json
         lexers/asm
         lexers/asm/detect
         racket/bytes
         racket/list
         racket/port
         racket/string
         "archive.rkt"
         "common-style.rkt"
         "private/assembly-options.rkt"
         "private/input-probe.rkt")

;; asm-token-style : asm-derived-token? -> string?
;;   Choose a semantic terminal style without treating unknown syntax as malformed.
(define (asm-token-style token)
  (define category
    (asm-derived-token-category token))
  (define tags
    (asm-derived-token-tags token))
  (cond
    [(memq 'asm-invalid-encoding tags)
     ansi-malformed]
    [(eq? category 'comment)
     ansi-comment]
    [(or (memq 'asm-instruction tags)
         (memq 'asm-directive tags)
         (memq 'asm-layout-statement-head tags))
     ansi-keyword]
    [(memq 'asm-register tags)
     ansi-builtin]
    [(eq? category 'literal)
     ansi-literal]
    [(memq 'asm-label-definition tags)
     ansi-identifier]
    [(eq? category 'identifier)
     ansi-identifier]
    [(or (eq? category 'operator)
         (eq? category 'delimiter))
     ansi-delimiter]
    [else
     ""]))

;; hex-digit : exact-nonnegative-integer? -> char?
;;   Convert one nibble to its uppercase hexadecimal representation.
(define (hex-digit value)
  (string-ref "0123456789ABCDEF" value))

;; byte->escape : exact-nonnegative-integer? -> string?
;;   Render one raw byte without allowing it to affect the terminal.
(define (byte->escape byte)
  (string #\\ #\x
          (hex-digit (quotient byte 16))
          (hex-digit (remainder byte 16))))

;; character->escape : char? -> string?
;;   Render a non-printing decoded character as an explicit Unicode escape.
(define (character->escape ch)
  (define code
    (char->integer ch))
  (cond
    [(<= code #xFF)
     (byte->escape code)]
    [else
     (format "\\u{~X}" code)]))

;; terminal-control-character? : char? -> boolean?
;;   Recognize decoded characters that must not be emitted as terminal controls.
(define (terminal-control-character? ch)
  (define code
    (char->integer ch))
  (or (< code #x20)
      (= code #x7F)
      (<= #x80 code #x9F)
      (= code #xFEFF)
      (<= #x202A code #x202E)
      (<= #x2066 code #x2069)))

;; Assembly terminal layout constants.
(define assembly-tab-stop
  8)

;; safe-asm-display-state : boolean? exact-nonnegative-integer? -> safe-asm-display-state?
;;   Track a deferred carriage return and the next terminal column.
(struct safe-asm-display-state (pending-carriage-return? column) #:mutable)

;; tab-padding : exact-nonnegative-integer? -> exact-positive-integer?
;;   Determine how many spaces advance one tab to the next assembly tab stop.
(define (tab-padding column)
  (- assembly-tab-stop
     (remainder column assembly-tab-stop)))

;; emit-visible-text : string? safe-asm-display-state? output-port? -> void?
;;   Write known single-column terminal text and advance the display column.
(define (emit-visible-text text state out)
  (display text out)
  (set-safe-asm-display-state-column!
   state
   (+ (safe-asm-display-state-column state)
      (string-length text))))

;; emit-assembly-tab : safe-asm-display-state? output-port? -> void?
;;   Render a source tab as spaces through the next fixed assembly tab stop.
(define (emit-assembly-tab state out)
  (define padding
    (tab-padding (safe-asm-display-state-column state)))
  (emit-visible-text (make-string padding #\space) state out))

;; emit-assembly-newline : safe-asm-display-state? output-port? -> void?
;;   Write one terminal line break and restart column tracking.
(define (emit-assembly-newline state out)
  (write-char #\newline out)
  (set-safe-asm-display-state-column! state 0))

;; emit-safe-non-carriage-return : char? safe-asm-display-state? output-port? -> void?
;;   Render one decoded character that is known not to be a carriage return.
(define (emit-safe-non-carriage-return ch state out)
  (cond
    [(char=? ch #\tab)
     (emit-assembly-tab state out)]
    [(char=? ch #\newline)
     (emit-assembly-newline state out)]
    [(terminal-control-character? ch)
     (emit-visible-text (character->escape ch) state out)]
    [else
     (write-char ch out)
     (set-safe-asm-display-state-column!
      state
      (add1 (safe-asm-display-state-column state)))]))

;; emit-safe-character : char? safe-asm-display-state? output-port? -> void?
;;   Defer carriage returns so CRLF stays one output newline.
(define (emit-safe-character ch state out)
  (cond
    [(char=? ch #\return)
     (set-safe-asm-display-state-pending-carriage-return?! state #t)]
    [else
     (emit-safe-non-carriage-return ch state out)]))

;; emit-safe-text : string? safe-asm-display-state? output-port? -> void?
;;   Write text safely, expanding tabs and treating CRLF as one line break.
(define (emit-safe-text text state out)
  (for ([ch (in-string text)])
    (cond
      [(safe-asm-display-state-pending-carriage-return? state)
       (set-safe-asm-display-state-pending-carriage-return?! state #f)
       (cond
         [(char=? ch #\newline)
          (emit-assembly-newline state out)]
         [else
          (emit-visible-text "\\x0D" state out)
          (emit-safe-character ch state out)])]
      [else
       (emit-safe-character ch state out)])))

;; flush-safe-asm-display : safe-asm-display-state? output-port? -> void?
;;   Emit a deferred lone carriage return at end of input.
(define (flush-safe-asm-display state out)
  (when (safe-asm-display-state-pending-carriage-return? state)
    (emit-visible-text "\\x0D" state out)
    (set-safe-asm-display-state-pending-carriage-return?! state #f)))

;; emit-safe-token : asm-derived-token? safe-asm-display-state? output-port? boolean? -> void?
;;   Render one token while preserving safety independently of color mode.
(define (emit-safe-token token state out color?)
  (cond
    [(asm-derived-token-has-tag? token 'asm-byte-order-mark)
     (void)]
    [(asm-derived-token-has-tag? token 'asm-invalid-encoding)
     (flush-safe-asm-display state out)
     (define escaped
       (apply string-append
              (for/list ([byte (in-bytes (asm-derived-token-raw-bytes token))])
                (byte->escape byte))))
     (define rendered
       (open-output-string))
     (emit-visible-text escaped state rendered)
     (define text
       (get-output-string rendered))
     (display (if color?
                  (colorize-text (asm-token-style token) text)
                  text)
              out)]
    [else
     (define rendered
       (open-output-string))
     (emit-safe-text (asm-derived-token-text token) state rendered)
     (define text
       (get-output-string rendered))
     (display (if color?
                  (colorize-text (asm-token-style token) text)
                  text)
              out)]))

;; checked-assembly-selection : assembly-options? -> (values symbol? (or/c symbol? #f))
;;   Reject unavailable profile-and-target selections without substitution.
(define (checked-assembly-selection options)
  (define selection
    (resolve-asm-selection #:dialect      (assembly-options-dialect options)
                           #:architecture (assembly-options-architecture options)))
  (cond
    [(asm-selection-effective selection)
     (values (asm-selection-effective selection)
             (assembly-options-architecture options))]
    [else
     (define diagnostics
       (asm-selection-diagnostics selection))
     (define message
       (cond
         [(pair? diagnostics)
          (asm-diagnostic-message (car diagnostics))]
         [else
          "The requested assembly profile is unavailable."]))
     (raise-user-error 'assembly message)]))

;; assembly-resolution : assembly-options? symbol? asm-probe? -> assembly-resolution?
;;   A selection resolved from a bounded source prefix. `origin` is explicit,
;;   automatic, or generic-fallback.
(struct assembly-resolution (options origin probe) #:transparent)

;; qualified-automatic-selection? : asm-auto-selection? -> boolean?
;;   Determine whether the shared lexer has approved a detected profile for use.
(define (qualified-automatic-selection? selection)
  (and (asm-auto-selection-automatic-enabled? selection)
       (asm-auto-selection-dialect selection)
       #t))

;; assembly-probe-plausibly-source? : assembly-resolution? -> boolean?
;;   Admit only high/probable, non-conflicting evidence to content arbitration.
(define (assembly-probe-plausibly-source? resolution)
  (define selection
    (asm-probe-selection (assembly-resolution-probe resolution)))
  (and (memq (asm-auto-selection-band selection) '(high probable))
       (asm-auto-selection-dialect selection)
       #t))

;; resolve-assembly-options : bytes? assembly-options? ... -> assembly-resolution?
;;   Use automatic selection only when the lexer calibration gate permits it.
(define (resolve-assembly-options sample
                                  options
                                  #:automatic? [automatic? #f])
  (define probe
    (probe-asm-bytes sample
                     #:limit (max 1 (bytes-length sample))))
  (cond
    [(not automatic?)
     (assembly-resolution options 'explicit probe)]
    [else
     (define selection
       (asm-probe-selection probe))
     (cond
       [(qualified-automatic-selection? selection)
        (assembly-resolution
         (make-assembly-options
          #:dialect      (asm-auto-selection-dialect selection)
          #:architecture (asm-auto-selection-architecture selection)
          #:encoding     (assembly-options-encoding options)
          #:detection-mode (assembly-options-detection-mode options))
         'automatic
         probe)]
       [else
        ;; The family can still be plausible enough to choose the neutral
        ;; generic renderer (for example, a strong ca65 `.inc` sample).  It
        ;; must not receive an unqualified dialect-specific lexer.
        (assembly-resolution
         (make-assembly-options #:dialect  'generic
                                #:encoding (assembly-options-encoding options)
                                #:detection-mode
                                (assembly-options-detection-mode options))
         'generic-fallback
         probe)])]))

;; render-asm-preview-port : input-port? ... -> void?
;;   Stream one byte-authoritative assembly source through the shared lexer.
(define (render-asm-preview-port in
                                 [out (current-output-port)]
                                 #:assembly [options (make-assembly-options)]
                                 #:color? [color? #t])
  (define-values (dialect architecture)
    (checked-assembly-selection options))
  (define lexer
    (make-asm-derived-lexer #:dialect      dialect
                            #:architecture architecture
                            #:encoding     (assembly-options-encoding options)))
  (define safe-state
    (safe-asm-display-state #f 0))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (emit-safe-token token safe-state out color?)
      ;; The assembly stream deliberately emits small fragments.  Flushing here
      ;; keeps a partial first source line visible on a stalled pipe.
      (flush-output out)
      (loop)))
  (flush-safe-asm-display safe-state out)
  (flush-output out))

;; render-asm-preview : string? ... -> string?
;;   Render a UTF-8 string through the same safe rendering state machine.
(define (render-asm-preview source
                            #:assembly [options (make-assembly-options)]
                            #:color? [color? #t])
  (unless (string? source)
    (raise-argument-error 'render-asm-preview "string?" source))
  (define out
    (open-output-string))
  (render-asm-preview-port (open-input-bytes (string->bytes/utf-8 source))
                           out
                           #:assembly options
                           #:color? color?)
  (get-output-string out))

;; likely-plain-binary-bytes? : bytes? -> boolean?
;;   Identify strong binary evidence without mistaking malformed text for binary input.
(define (likely-plain-binary-bytes? sample)
  (cond
    [(zero? (bytes-length sample))
     #f]
    [(for/or ([byte (in-bytes sample)])
       (zero? byte))
     #t]
    [else
     (define control-count
       (for/sum ([byte (in-bytes sample)]
                 #:when (or (< byte #x09)
                            (and (< #x0D byte)
                                 (< byte #x20))
                            (= byte #x7F)))
         1))
     (>= (/ control-count
            (max 1 (bytes-length sample)))
         1/5)]))

;; ar-archive-bytes? : bytes? -> boolean?
;;   Recognize the complete fixed signature of an ordinary Unix ar container.
(define (ar-archive-bytes? sample)
  (and (>= (bytes-length sample) 8)
       (bytes=? (subbytes sample 0 8)
                #"!<arch>\n")))

;; assembly-input-kind : bytes? assembly-options? -> symbol?
;;   Classify only representation boundaries before conservative source lexing.
(define (assembly-input-kind sample options)
  (define detection
    (detect-asm-bytes sample
                      #:dialect      (assembly-options-dialect options)
                      #:architecture (assembly-options-architecture options)
                      #:limit        (add1 (bytes-length sample))))
  (cond
    [(likely-archive-bytes? sample)
     'archive]
    [(ar-archive-bytes? sample)
     ;; `peek` has no ar tree reader.  Preserve its representation boundary by
     ;; treating it as binary instead of attempting to lex member headers.
     'binary]
    [(memq (asm-detection-encoding detection) '(utf-16le utf-16be))
     'source]
    [(likely-plain-binary-bytes? sample)
     'binary]
    [else
     'source]))

;; bytes->hex : bytes? -> string?
;;   Encode raw token bytes in stable JSON-safe hexadecimal text.
(define (bytes->hex source)
  (apply string-append
         (for/list ([byte (in-bytes source)])
           (string (hex-digit (quotient byte 16))
                   (hex-digit (remainder byte 16))))))

;; byte-span-jsexpr : (or/c asm-byte-span? #f) -> (or/c #f jsexpr?)
;;   Convert an optional raw-byte span into a JSON object.
(define (byte-span-jsexpr byte-span)
  (cond
    [byte-span
     (hasheq 'start (asm-byte-span-start byte-span)
             'end   (asm-byte-span-end byte-span))]
    [else
     #f]))

;; diagnostic-jsexpr : asm-diagnostic? -> jsexpr?
;;   Convert one lexer or selection diagnostic into stable JSON fields.
(define (diagnostic-jsexpr diagnostic)
  (hasheq 'code      (symbol->string (asm-diagnostic-code diagnostic))
          'severity  (symbol->string (asm-diagnostic-severity diagnostic))
          'message   (asm-diagnostic-message diagnostic)
          'byte_span (byte-span-jsexpr (asm-diagnostic-byte-span diagnostic))))

;; selection-jsexpr : asm-selection? -> jsexpr?
;;   Convert the shared selection record without adding renderer inference.
(define (selection-jsexpr selection)
  (hasheq 'requested
          (and (asm-selection-requested selection)
               (symbol->string (asm-selection-requested selection)))
          'effective
          (and (asm-selection-effective selection)
               (symbol->string (asm-selection-effective selection)))
          'origin
          (symbol->string (asm-selection-origin selection))
          'diagnostics
          (for/list ([diagnostic (in-list (asm-selection-diagnostics selection))])
            (diagnostic-jsexpr diagnostic))))

;; symbol-jsexpr : (or/c symbol? #f) -> (or/c string? #f)
;;   Encode an optional symbolic API value for a stable JSON record.
(define (symbol-jsexpr value)
  (and value
       (symbol->string value)))

;; content-evidence-jsexpr : asm-content-evidence? -> jsexpr?
;;   Preserve the scanner's evidence without duplicating its grammar in peek.
(define (content-evidence-jsexpr evidence)
  (hasheq 'rule_id      (symbol->string (asm-content-evidence-rule-id evidence))
          'feature_class (symbol->string (asm-content-evidence-feature-class evidence))
          'dimensions   (for/list ([dimension (in-list (asm-content-evidence-dimensions evidence))])
                          (symbol->string dimension))
          'contribution (asm-content-evidence-contribution evidence)
          'byte_span    (byte-span-jsexpr (asm-content-evidence-byte-span evidence))
          'context      (for/list ([item (in-list (asm-content-evidence-context evidence))])
                          (symbol->string item))))

;; conflict-jsexpr : asm-detection-conflict? -> jsexpr?
;;   Render one scanner-level rival interpretation conflict for inspection.
(define (conflict-jsexpr conflict)
  (hasheq 'rule_id      (symbol->string (asm-detection-conflict-rule-id conflict))
          'rival_dialect (symbol->string (asm-detection-conflict-rival-dialect conflict))
          'byte_span    (byte-span-jsexpr (asm-detection-conflict-byte-span conflict))
          'context      (for/list ([item (in-list (asm-detection-conflict-context conflict))])
                          (symbol->string item))))

;; candidate-jsexpr : asm-detection-candidate? -> jsexpr?
;;   Serialize one bounded dialect-and-architecture scoring result.
(define (candidate-jsexpr candidate)
  (hasheq 'dialect             (symbol-jsexpr (asm-detection-candidate-dialect candidate))
          'architecture        (symbol-jsexpr (asm-detection-candidate-architecture candidate))
          'dialect_score       (asm-detection-candidate-dialect-score candidate)
          'architecture_score  (asm-detection-candidate-architecture-score candidate)
          'score               (asm-detection-candidate-score candidate)
          'feature_classes
          (for/list ([feature-class (in-list (asm-detection-candidate-feature-classes candidate))])
            (symbol->string feature-class))
          'evidence
          (for/list ([evidence (in-list (asm-detection-candidate-evidence candidate))])
            (content-evidence-jsexpr evidence))
          'conflicts
          (for/list ([conflict (in-list (asm-detection-candidate-conflicts candidate))])
            (conflict-jsexpr conflict))))

;; automatic-selection-jsexpr : asm-auto-selection? -> jsexpr?
;;   Serialize the calibrated-selection gate and its inspectable conclusion.
(define (automatic-selection-jsexpr selection)
  (hasheq 'band              (symbol->string (asm-auto-selection-band selection))
          'dialect           (symbol-jsexpr (asm-auto-selection-dialect selection))
          'architecture      (symbol-jsexpr (asm-auto-selection-architecture selection))
          'score             (asm-auto-selection-score selection)
          'margin            (asm-auto-selection-margin selection)
          'automatic_enabled (asm-auto-selection-automatic-enabled? selection)
          'reason            (symbol->string (asm-auto-selection-reason selection))
          'compatible_candidates
          (for/list ([candidate (in-list (asm-auto-selection-compatible-candidates selection))])
            (candidate-jsexpr candidate))))

;; resolution-jsexpr : assembly-resolution? -> jsexpr?
;;   Report the exact lexer options that ordinary preview would use.
(define (resolution-jsexpr resolution)
  (define options
    (assembly-resolution-options resolution))
  (hasheq 'dialect      (symbol-jsexpr (assembly-options-dialect options))
          'architecture (symbol-jsexpr (assembly-options-architecture options))
          'encoding     (symbol->string (assembly-options-encoding options))
          'detection_mode
          (symbol->string (assembly-options-detection-mode options))
          'origin       (symbol->string (assembly-resolution-origin resolution))))

;; evidence-jsexpr : asm-evidence? -> jsexpr?
;;   Convert bounded representation evidence into stable JSON fields.
(define (evidence-jsexpr evidence)
  (hasheq 'dimension  (symbol->string (asm-evidence-dimension evidence))
          'value      (symbol->string (asm-evidence-value evidence))
          'origin     (symbol->string (asm-evidence-origin evidence))
          'confidence (symbol->string (asm-evidence-confidence evidence))
          'byte_span  (byte-span-jsexpr (asm-evidence-byte-span evidence))))

;; path-assembly-hint : (or/c path-string? #f) -> (or/c #f string?)
;;   Preserve the filename hint that admitted bounded assembly-family probing.
(define (path-assembly-hint maybe-path)
  (cond
    [(not maybe-path)
     #f]
    [else
     (define path-text
       (cond
         [(path? maybe-path)
          (path->string maybe-path)]
         [else
          maybe-path]))
     (cond
       [(regexp-match? #px"\\.asm$" path-text) ".asm"]
       [(regexp-match? #px"\\.s$" path-text)   ".s"]
       [(regexp-match? #px"\\.S$" path-text)   ".S"]
       [(regexp-match? #px"\\.sx$" path-text)  ".sx"]
       [(regexp-match? #px"\\.nasm$" path-text) ".nasm"]
       [(regexp-match? #px"\\.inc$" path-text) ".inc"]
       [(regexp-match? #px"\\.i$" path-text)   ".i"]
       [(regexp-match? #px"\\.a$" path-text)   ".a"]
       [else #f])]))

;; assembly-detection-jsexpr : input-probe? ... -> jsexpr?
;;   Describe bounded representation and automatic-profile evidence as JSON.
(define (assembly-detection-jsexpr probe
                                   #:path     [maybe-path #f]
                                   #:assembly [options (make-assembly-options)])
  (define sample
    (input-probe-sample probe))
  (define detection
    (detect-asm-bytes sample
                      #:dialect      (assembly-options-dialect options)
                      #:architecture (assembly-options-architecture options)
                      #:limit        (max 1 (input-probe-byte-count probe))))
  (define resolution
    (resolve-assembly-options sample
                              options
                              #:automatic? (not (assembly-options-dialect options))))
  (define automatic-probe
    (assembly-resolution-probe resolution))
  (hasheq 'schema_version 2
          'selection      (selection-jsexpr (asm-detection-selection detection))
          'resolved_selection (resolution-jsexpr resolution)
          'evidence       (for/list ([evidence (in-list (asm-detection-evidence detection))])
                            (evidence-jsexpr evidence))
          'diagnostics    (for/list ([diagnostic (in-list (asm-detection-diagnostics detection))])
                            (diagnostic-jsexpr diagnostic))
          'encoding       (symbol->string (asm-detection-encoding detection))
          'artifact_kind  (symbol->string (assembly-input-kind sample options))
          'path_hint      (path-assembly-hint maybe-path)
          'automatic      (automatic-selection-jsexpr (asm-probe-selection automatic-probe))
          'candidates     (for/list ([candidate (in-list (asm-probe-candidates automatic-probe))])
                            (candidate-jsexpr candidate))
          'content_evidence
          (for/list ([evidence (in-list (asm-probe-evidence automatic-probe))])
            (content-evidence-jsexpr evidence))
          'automatic_diagnostics
          (for/list ([diagnostic (in-list (asm-probe-diagnostics automatic-probe))])
            (diagnostic-jsexpr diagnostic))
          'probe          (hasheq 'sampled_bytes  (input-probe-byte-count probe)
                                   'sampled_lines  (input-probe-line-count probe)
                                   'detection_mode
                                   (symbol->string (assembly-options-detection-mode options))
                                   'stopping_reason
                                   (symbol->string (input-probe-stopping-reason probe)))))

;; token-jsexpr : asm-derived-token? -> jsexpr?
;;   Convert one source fragment into an ANSI-free JSON Lines record.
(define (token-jsexpr token)
  (define state
    (asm-derived-token-effective-state token))
  (hasheq 'schema_version 1
          'category       (symbol->string (asm-derived-token-category token))
          'text           (asm-derived-token-text token)
          'tags           (for/list ([tag (in-list (asm-derived-token-tags token))])
                            (symbol->string tag))
          'byte_span      (byte-span-jsexpr (asm-derived-token-byte-span token))
          'raw_bytes_hex  (bytes->hex (asm-derived-token-raw-bytes token))
          'continuation_id (asm-derived-token-continuation-id token)
          'effective_state
          (hasheq 'dialect (symbol->string (asm-effective-state-dialect state))
                  'encoding (symbol->string (asm-effective-state-encoding state))
                  'line_start (asm-effective-state-line-start? state))
          'diagnostics
          (for/list ([diagnostic (in-list (asm-derived-token-diagnostics token))])
            (diagnostic-jsexpr diagnostic))))

;; write-asm-token-jsonl : input-port? ... -> void?
;;   Stream every assembly-derived source fragment as one JSON line.
(define (write-asm-token-jsonl in
                               [out (current-output-port)]
                               #:assembly [options (make-assembly-options)])
  (define-values (dialect architecture)
    (checked-assembly-selection options))
  (define lexer
    (make-asm-derived-lexer #:dialect      dialect
                            #:architecture architecture
                            #:encoding     (assembly-options-encoding options)))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (write-json (token-jsexpr token) out)
      (newline out)
      (flush-output out)
      (loop))))

;; write-assembly-explanation : input-probe? ... -> void?
;;   Write bounded selection details to stderr without contaminating preview stdout.
(define (write-assembly-explanation probe
                                    [out (current-error-port)]
                                    #:path     [maybe-path #f]
                                    #:assembly [options (make-assembly-options)]
                                    #:automatic? [automatic? #f])
  (define sample
    (input-probe-sample probe))
  (define detection
    (detect-asm-bytes sample
                      #:dialect      (assembly-options-dialect options)
                      #:architecture (assembly-options-architecture options)
                      #:limit        (max 1 (input-probe-byte-count probe))))
  (define resolution
    (resolve-assembly-options sample options #:automatic? automatic?))
  (define selection
    (asm-detection-selection detection))
  (fprintf out
           "assembly request: requested ~a; effective ~a; origin ~a\n"
           (or (asm-selection-requested selection) 'none)
           (or (asm-selection-effective selection) 'none)
           (asm-selection-origin selection))
  (fprintf out
           "assembly preview: dialect ~a; architecture ~a; origin ~a\n"
           (assembly-options-dialect (assembly-resolution-options resolution))
           (or (assembly-options-architecture (assembly-resolution-options resolution))
               'none)
           (assembly-resolution-origin resolution))
  (fprintf out
           "assembly representation: ~a; encoding ~a; mode ~a; sampled ~a bytes / ~a lines; stopped ~a\n"
           (assembly-input-kind (input-probe-sample probe) options)
           (asm-detection-encoding detection)
           (assembly-options-detection-mode options)
           (input-probe-byte-count probe)
           (input-probe-line-count probe)
           (input-probe-stopping-reason probe))
  (for ([diagnostic (in-list (asm-detection-diagnostics detection))])
    (fprintf out
             "assembly ~a: ~a\n"
             (asm-diagnostic-severity diagnostic)
             (asm-diagnostic-message diagnostic)))
  (define path-hint
    (path-assembly-hint maybe-path))
  (when path-hint
    (fprintf out "assembly filename hint: ~a\n" path-hint))
  (define automatic-selection
    (asm-probe-selection (assembly-resolution-probe resolution)))
  (fprintf out
           "assembly automatic probe: ~a; candidate ~a/~a; score ~a; margin ~a; enabled ~a; ~a\n"
           (asm-auto-selection-band automatic-selection)
           (or (asm-auto-selection-dialect automatic-selection) 'none)
           (or (asm-auto-selection-architecture automatic-selection) 'none)
           (asm-auto-selection-score automatic-selection)
           (asm-auto-selection-margin automatic-selection)
           (asm-auto-selection-automatic-enabled? automatic-selection)
           (asm-auto-selection-reason automatic-selection))
  (flush-output out))

(module+ test
  (require rackunit)

  (define source
    "entry:\nmov a, b ; neutral generic punctuation\n")
  (define colored
    (render-asm-preview source))
  (define uncolored
    (render-asm-preview source #:color? #f))
  (define invalid-output
    (let ([out (open-output-string)])
      (render-asm-preview-port (open-input-bytes #"a\303(\r\n")
                               out
                               #:color? #f)
      (get-output-string out)))

  (check-true (regexp-match? #px"\u001b\\[" colored))
  (check-equal? uncolored source)
  (check-equal? invalid-output "a\\xC3(\n")
  (check-equal? (assembly-input-kind #"\377\376l\0d\0a\0"
                                    (make-assembly-options))
                'source)
  (check-equal? (assembly-input-kind #"\0\1\2"
                                    (make-assembly-options))
                'binary)
  (check-equal? (assembly-input-kind #"!<arch>\nmember"
                                    (make-assembly-options))
                'binary))
