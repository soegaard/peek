#lang racket/base

;;;
;;; SQL Preview
;;;
;;
;; SQL-specific terminal preview rendering built on `lexers/sql`.

;; render-sql-preview      : string? [symbol?] -> string?
;;   Render SQL source for terminal preview.
;; render-sql-preview-port : input-port? [output-port?] [symbol?] -> void?
;;   Render SQL source from a port for terminal preview.

(provide
 ;; render-sql-preview : string? [symbol?] -> string?
 ;;   Render SQL source for terminal preview.
 render-sql-preview
 ;; render-sql-preview-port : input-port? [output-port?] [symbol?] -> void?
 ;;   Render SQL source from a port for terminal preview.
 render-sql-preview-port)

(require lexers/sql
         racket/port
         "common-style.rkt")

;; sql-derived-token-category : sql-derived-token? -> symbol?
;;   Extract the coarse category from one derived SQL token.
(define (sql-derived-token-category token)
  (vector-ref (struct->vector token) 1))

;; sql-token-style : sql-derived-token? -> string?
;;   Choose the ANSI style for one derived SQL token.
(define (sql-token-style token)
  (sql-like-style (sql-derived-token-category token)
                  (sql-derived-token-tags token)))

;; render-sql-preview : string? [symbol?] -> string?
;;   Render SQL source for terminal preview.
(define (render-sql-preview source
                            [dialect 'generic])
  (apply string-append
         (for/list ([token (in-list (sql-string->derived-tokens source
                                                                #:dialect dialect))])
           (colorize-text (sql-token-style token)
                          (sql-derived-token-text token)))))

;; render-sql-preview-port : input-port? [output-port?] [symbol?] -> void?
;;   Render SQL source from a port for terminal preview.
(define (render-sql-preview-port in
                                 [out (current-output-port)]
                                 [dialect 'generic])
  (port-count-lines! in)
  (define lexer
    (make-sql-derived-lexer #:dialect dialect))
  (let loop ()
    (define token
      (lexer in))
    (unless (eq? token 'eof)
      (display (colorize-text (sql-token-style token)
                              (sql-derived-token-text token))
               out)
      (loop))))

(module+ test
  (require rackunit)

  (define (strip-ansi text)
    (regexp-replace* #px"\u001b\\[[0-9;]*m" text ""))

  (define generic-sample
    (string-append
     "-- shared query\n"
     "SELECT id, name\n"
     "FROM people\n"
     "WHERE id = 42;\n"))

  (define sqlite-sample
    (string-append
     "SELECT [group], `name`\n"
     "FROM \"items\"\n"
     "WHERE id = ?1;\n"))

  (define postgres-sample
    (string-append
     "SELECT $1, $$hello$$\n"
     "FROM accounts\n"
     "WHERE note ILIKE '%ok%';\n"))

  (define mysql-sample
    (string-append
     "# comment\n"
     "SELECT _utf8'hej', `name`\n"
     "FROM users\n"
     "WHERE id = ?;\n"))

  (check-equal?
   (strip-ansi (render-sql-preview generic-sample))
   generic-sample)

  (check-equal?
   (strip-ansi (render-sql-preview sqlite-sample
                                   'sqlite))
   sqlite-sample)

  (check-equal?
   (strip-ansi (render-sql-preview postgres-sample
                                   'postgres))
   postgres-sample)

  (check-equal?
   (strip-ansi (render-sql-preview mysql-sample
                                   'mysql))
   mysql-sample)

  (check-true
   (regexp-match? #px"\u001b\\[" (render-sql-preview postgres-sample
                                                      'postgres)))

  (check-equal?
   (let ([out (open-output-string)])
     (render-sql-preview-port (open-input-string mysql-sample)
                              out
                              'mysql)
     (strip-ansi (get-output-string out)))
   mysql-sample))
