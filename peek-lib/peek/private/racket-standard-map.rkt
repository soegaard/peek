#lang racket/base

;; The bundled Racket standard map was generated from the local standard
;; `racket` language namespace using namespace inspection.

(require racket/list
         racket/match
         racket/runtime-path
         racket/string
         racket/set)

(provide racket-standard-entry?
         racket-standard-map-entries
         racket-standard-form?
         racket-standard-formish?
         racket-standard-builtin?
         racket-standard-token-tags)

(define-runtime-path racket-standard-map-path "racket-standard-map.rktd")

(define (racket-standard-entry? v)
  (match v
    [(list kind token)
     (and (memq kind '(form builtin))
          (string? token)
          (not (string=? "" (string-trim token))))]
    [_ #f]))

(define (read-default-entries)
  (define v (call-with-input-file racket-standard-map-path read))
  (unless (and (list? v) (andmap racket-standard-entry? v))
    (raise-arguments-error 'read-default-entries
                           "invalid Racket standard map data"
                           "path" (path->string racket-standard-map-path)
                           "value" v))
  v)

(define racket-standard-map-entries
  (read-default-entries))

(define forms
  (for/set ([e (in-list racket-standard-map-entries)]
            #:when (eq? (first e) 'form))
    (second e)))

(define builtins
  (for/set ([e (in-list racket-standard-map-entries)]
            #:when (eq? (first e) 'builtin))
    (second e)))

(define (racket-standard-form? token)
  (and (string? token)
       (set-member? forms (string-trim token))))

(define (racket-standard-formish? token)
  (define t (and (string? token) (string-trim token)))
  (and t
       (not (string=? t ""))
       (or (racket-standard-form? t)
           (string-prefix? t "define-")
           (string-prefix? t "define/")
           (string-prefix? t "let-")
           (string-prefix? t "let/")
           (string-prefix? t "for/")
           (string-prefix? t "for*/"))))

(define (racket-standard-builtin? token)
  (and (string? token)
       (set-member? builtins (string-trim token))))

;; racket-standard-token-tags : string? -> (listof symbol?)
;;   Attach standard-vocabulary tags for one candidate Racket identifier.
(define (racket-standard-token-tags token)
  (cond
    [(racket-standard-form? token)
     '(racket-standard-form)]
    [(racket-standard-builtin? token)
     '(racket-standard-builtin)]
    [(racket-standard-formish? token)
     '(racket-form-like)]
    [else
     '()]))

(module+ test
  (require rackunit)
  (check-true (pair? racket-standard-map-entries))
  (check-true (andmap racket-standard-entry? racket-standard-map-entries))
  (check-true (racket-standard-form? "define"))
  (check-true (racket-standard-form? "for/fold"))
  (check-true (racket-standard-formish? "define/contract"))
  (check-true (racket-standard-formish? "define-flow"))
  (check-true (racket-standard-formish? "let-flow"))
  (check-true (racket-standard-formish? "let/custom"))
  (check-true (racket-standard-formish? "for/fold"))
  (check-true (racket-standard-formish? "for/custom"))
  (check-true (racket-standard-builtin? "string-length"))
  (check-true (racket-standard-builtin? "hash-update"))
  (check-equal? (racket-standard-token-tags "define")
                '(racket-standard-form))
  (check-equal? (racket-standard-token-tags "hash-update")
                '(racket-standard-builtin))
  (check-equal? (racket-standard-token-tags "define-flow")
                '(racket-form-like))
  (check-equal? (racket-standard-token-tags "let-flow")
                '(racket-form-like))
  (check-false (racket-standard-form? "definitely-not-racket"))
  (check-false (racket-standard-formish? "hash-update"))
  (check-false (racket-standard-builtin? "definitely-not-racket")))
