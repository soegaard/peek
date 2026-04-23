#lang racket/base

;;;
;;; Binary Preview
;;;
;;
;; Hex-style preview rendering for binary input.

;; render-binary-preview : bytes? ... -> string?
;;   Render a byte string as a colorized hex or bit preview.
;; render-binary-preview-port : input-port? ... -> void?
;;   Render binary data from a port to an output port.
;; likely-binary-bytes? : bytes? -> boolean?
;;   Heuristically decide whether a byte string looks like binary data.

(provide
 ;; render-binary-preview : bytes? #:color? boolean? #:bits? boolean? -> string?
 ;;   Render a byte string as a colorized hex or bit preview.
 render-binary-preview
 ;; render-binary-preview-port : input-port? output-port? #:color? boolean? #:bits? boolean? -> void?
 ;;   Render binary data from a port to an output port.
 render-binary-preview-port
 ;; likely-binary-bytes? : bytes? -> boolean?
 ;;   Heuristically decide whether a byte string looks like binary data.
 likely-binary-bytes?)

(require racket/bytes
         racket/list
         racket/port
         racket/string
         "common-style.rkt")

;; ANSI color constants.
(define (ansi . codes)
  (string-append "\033[" (string-join (map number->string codes) ";") "m"))

(define ansi-reset      (ansi 0))
(define ansi-zero-byte  (ansi 38 2 126 126 126))
(define ansi-01-byte    (ansi 38 2 255 119 170))
(define ansi-10-byte    (ansi 38 2 255 102 102))
(define ansi-20-byte    (ansi 38 2 255 154  58))
(define ansi-30-byte    (ansi 38 2 255 180  43))
(define ansi-40-byte    (ansi 38 2 214 184  27))
(define ansi-50-byte    (ansi 38 2 151 206  75))
(define ansi-60-byte    (ansi 38 2  96 200  94))
(define ansi-70-byte    (ansi 38 2  72 198 131))
(define ansi-80-byte    (ansi 38 2  53 193 164))
(define ansi-90-byte    (ansi 38 2  47 181 195))
(define ansi-a0-byte    (ansi 38 2  74 182 232))
(define ansi-b0-byte    (ansi 38 2  90 163 255))
(define ansi-c0-byte    (ansi 38 2 107 147 255))
(define ansi-d0-byte    (ansi 38 2 141 121 255))
(define ansi-e0-byte    (ansi 38 2 177 105 255))
(define ansi-f0-byte    (ansi 38 2 255 105 194))
(define ansi-ff-byte    (ansi 38 2 245 245 245))
(define ansi-search-byte (ansi 38 2 255 255 255))

;; hex-row-width : exact-nonnegative-integer?
;;   Number of bytes shown on each hex preview row.
(define hex-row-width 16)

;; bits-row-width : exact-nonnegative-integer?
;;   Number of bytes shown on each bit preview row.
(define bits-row-width 6)

;; styled : boolean? string? string? -> string?
;;   Optionally wrap text in ANSI styling.
(define (styled color? style text)
  (if color?
      (string-append style text ansi-reset)
      text))

;; byte-style : exact-nonnegative-integer? -> string?
;;   Choose a color for one byte.
(define (byte-style b)
  (cond
    [(zero? b) ansi-zero-byte]
    [(<= 1 b 15) ansi-01-byte]
    [(<= 16 b 31) ansi-10-byte]
    [(<= 32 b 47) ansi-20-byte]
    [(<= 48 b 63) ansi-30-byte]
    [(<= 64 b 79) ansi-40-byte]
    [(<= 80 b 95) ansi-50-byte]
    [(<= 96 b 111) ansi-60-byte]
    [(<= 112 b 127) ansi-70-byte]
    [(<= 128 b 143) ansi-80-byte]
    [(<= 144 b 159) ansi-90-byte]
    [(<= 160 b 175) ansi-a0-byte]
    [(<= 176 b 191) ansi-b0-byte]
    [(<= 192 b 207) ansi-c0-byte]
    [(<= 208 b 223) ansi-d0-byte]
    [(<= 224 b 239) ansi-e0-byte]
    [(<= 240 b 254) ansi-f0-byte]
    [(= b 255) ansi-ff-byte]
    [else ansi-zero-byte]))

;; byte->hex2 : exact-nonnegative-integer? -> string?
;;   Format one byte as a two-digit uppercase hexadecimal string.
(define (byte->hex2 b)
  (define s
    (string-upcase (number->string b 16)))
  (string-append (if (= (string-length s) 1) "0" "")
                 s))

;; offset->hex8 : exact-nonnegative-integer? -> string?
;;   Format a byte offset as an eight-digit uppercase hexadecimal string.
(define (offset->hex8 offset)
  (define s
    (string-upcase (number->string offset 16)))
  (string-append (make-string (max 0 (- 8 (string-length s))) #\0)
                 s))

;; printable-byte? : exact-nonnegative-integer? -> boolean?
;;   Recognize a byte that should render as a visible ASCII character.
(define (printable-byte? b)
  (and (<= 32 b)
       (<= b 126)))

;; ascii-byte->string : exact-nonnegative-integer? -> string?
;;   Render one byte for the ASCII gutter.
(define (ascii-byte->string b)
  (if (printable-byte? b)
      (string (integer->char b))
      "."))

;; binary-control-byte? : exact-nonnegative-integer? -> boolean?
;;   Recognize bytes that are strongly non-textual.
(define (binary-control-byte? b)
  (or (< b 32)
      (= b 127)))

;; bytes-match-at? : bytes? bytes? exact-nonnegative-integer? -> boolean?
;;   Check whether a needle occurs in haystack at a given byte offset.
(define (bytes-match-at? haystack needle offset)
  (define needle-length
    (bytes-length needle))
  (and (<= (+ offset needle-length) (bytes-length haystack))
       (for/and ([i (in-range needle-length)])
         (= (bytes-ref haystack (+ offset i))
            (bytes-ref needle i)))))

;; search-mask : bytes? (listof bytes?) -> (or/c #f vector?)
;;   Mark the byte positions that participate in highlighted matches.
(define (search-mask bs needles)
  (cond
    [(null? needles)
     #f]
    [else
     (define haystack-length
       (bytes-length bs))
     (define mask
       (make-vector haystack-length #f))
     (for ([needle (in-list needles)])
       (define needle-length
         (bytes-length needle))
       (when (positive? needle-length)
         (for ([offset (in-range 0
                                 (max 0 (add1 (- haystack-length needle-length))))])
           (when (bytes-match-at? bs needle offset)
             (for ([i (in-range needle-length)])
               (vector-set! mask (+ offset i) #t))))))
     mask]))

;; likely-binary-bytes? : bytes? -> boolean?
;;   Decide whether bytes look more like binary data than text.
(define (likely-binary-bytes? bs)
  (cond
    [(zero? (bytes-length bs))
     #f]
    [(for/or ([b (in-bytes bs)])
       (zero? b))
     #t]
    [else
     (define sample
       (subbytes bs 0 (min (bytes-length bs) 4096)))
     (with-handlers ([exn:fail? (lambda (_) #t)])
       (let* ([decoded (bytes->string/utf-8 sample)]
              [control-bytes
               (for/sum ([b (in-bytes sample)]
                         #:when (binary-control-byte? b))
                 1)]
              [ratio
               (/ control-bytes
                  (max 1 (bytes-length sample)))])
         (and decoded
              (>= ratio 0.20))))]))

;; byte-cell/bits : exact-nonnegative-integer? -> string?
;;   Format one byte as an 8-bit binary string.
(define (byte-cell/bits b)
  (define s
    (string-upcase (number->string b 2)))
  (string-append (make-string (max 0 (- 8 (string-length s))) #\0)
                 s))

;; row-bytes : bytes? exact-nonnegative-integer? boolean? exact-nonnegative-integer? (exact-nonnegative-integer? -> string?) string? (or/c #f vector?) -> string?
;;   Render one row of bytes.
(define (row-bytes bs offset color? row-width byte->cell empty-cell highlight-mask)
  (define byte-count
    (bytes-length bs))
  (define hex-cells
    (for/list ([i (in-range row-width)])
      (cond
        [(< i byte-count)
         (define b (bytes-ref bs i))
         (define highlighted?
           (and highlight-mask
                (vector-ref highlight-mask (+ offset i))))
         (styled color?
                 (if highlighted? ansi-search-byte (byte-style b))
                 (byte->cell b))]
        [else
         empty-cell])))
  (define ascii-cells
    (for/list ([i (in-range row-width)])
      (cond
        [(< i byte-count)
         (define b (bytes-ref bs i))
         (define highlighted?
           (and highlight-mask
                (vector-ref highlight-mask i)))
         (styled color?
                 (if highlighted? ansi-search-byte (byte-style b))
                 (ascii-byte->string b))]
        [else
         " "])))
  (define hex-first
    (if (<= row-width 8)
        (string-join hex-cells " ")
        (string-join (take hex-cells 8) " ")))
  (define hex-second
    (if (<= row-width 8)
        ""
        (string-join (drop hex-cells 8) " ")))
  (define hex-part
    (string-append hex-first
                   (if (string=? hex-second "") "" "  ")
                   hex-second))
  (define ascii-text
    (apply string-append ascii-cells))
  (string-append (styled color? ansi-delimiter (offset->hex8 offset))
                 "  "
                 hex-part
                 "  |"
                 ascii-text
                 "|"))

;; render-binary-preview : bytes? #:color? boolean? #:bits? boolean? #:search-bytes (listof bytes?) -> string?
;;   Render bytes as a colorized hex or bit preview.
(define (render-binary-preview bs
                               #:color? [color? #t]
                               #:bits? [bits? #f]
                               #:search-bytes [search-bytes '()])
  (define len
    (bytes-length bs))
  (define row-width
    (if bits? bits-row-width hex-row-width))
  (define highlight-mask
    (search-mask bs search-bytes))
  (define rows
    (for/list ([start (in-range 0 len row-width)])
      (row-bytes (subbytes bs start (min len (+ start row-width)))
                 start
                 color?
                 row-width
                 (if bits? byte-cell/bits byte->hex2)
                 (if bits? "        " "  ")
                 highlight-mask)))
  (if (null? rows)
      ""
      (string-append (string-join rows "\n")
                     "\n")))

;; render-binary-preview-port : input-port? output-port? #:color? boolean? #:bits? boolean? #:search-bytes (listof bytes?) -> void?
;;   Render binary data from a port to an output port.
(define (render-binary-preview-port in
                                    [out (current-output-port)]
                                    #:color? [color? #t]
                                    #:bits? [bits? #f]
                                    #:search-bytes [search-bytes '()])
  (display (render-binary-preview (port->bytes in)
                                  #:color? color?
                                  #:bits? bits?
                                  #:search-bytes search-bytes)
           out))

(module+ test
  (require rackunit)

  (define ansi-pattern
    #px"\u001b\\[[0-9;]*m")

  (define (strip-ansi text)
    (regexp-replace* ansi-pattern text ""))

  (define sample
    (bytes 0 1 2 3 4 5 6 7
           8 9 10 11 12 13 14 15
           16 32 65 66 67 255))

  (check-true (likely-binary-bytes? sample))
  (check-false (likely-binary-bytes? (string->bytes/utf-8 "hello, peek\n")))
  (check-true (regexp-match? #px"00000000" (render-binary-preview sample)))
  (check-true (regexp-match? #px"00000010" (render-binary-preview sample)))
  (check-true (regexp-match? #px"00000001"
                             (strip-ansi (render-binary-preview sample #:bits? #t))))
  (check-true (regexp-match? #px"255;255;255"
                             (render-binary-preview sample
                                                    #:search-bytes (list (bytes 65 66 67)))))
  (check-true (regexp-match? #px"\\|\\. ABC\\. *\\|"
                             (strip-ansi (render-binary-preview sample))))
  (check-true (regexp-match? #px"00000000  00000000 00000001 00000010 00000011 00000100 00000101"
                             (strip-ansi (render-binary-preview sample #:bits? #t))))
  (check-equal? (render-binary-preview (string->bytes/utf-8 "abc")
                                       #:color? #f)
                "00000000  61 62 63                                          |abc             |\n"))
