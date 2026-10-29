#!/usr/bin/env guile
!#
(use-modules (common)
             (ice-9 format)
             (json)
             (srfi srfi-1))

(define path (string-append root "/planning/update-dependencies.json"))

(define (main args)
  (let* ((data (call-with-input-file path (lambda (p) (json->scm p))))
         (nodes (assoc-ref data "nodes"))
         (manifest (map car (manifest-packages)))
         (errors '()))
    (for-each
     (lambda (entry)
       (for-each
        (lambda (target)
          (unless (member target manifest)
            (set! errors (cons (format #f "~a -> unknown ~a" (car entry) target)
                               errors))))
        (vector->list (cdr entry))))
     nodes)
    (for-each (lambda (entry)
                (format #t "~a -> ~a~%" (car entry)
                        (string-join (vector->list (cdr entry)) ", ")))
              nodes)
    (for-each (lambda (error) (format #t "FAIL ~a~%" error)) errors)
    (exit (if (null? errors) 0 1))))

(main (cdr (command-line)))
