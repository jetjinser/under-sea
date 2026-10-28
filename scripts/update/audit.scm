#!/usr/bin/env guile
!#
(use-modules (common)
             (ice-9 match)
             (ice-9 format)
             (json))

(define (main args)
  (let* ((json? (member "--json" args))
         (no-docs? (member "--no-docs" args))
         (report (audit-report #:check-docs? (not no-docs?)))
         (errors (assoc-ref report 'errors)))
    (if json?
        (display (scm->json-string report))
        (begin
          (format #t "manifest=~a exemptions=~a inventory=~a~%"
                  (assoc-ref report 'manifest)
                  (assoc-ref report 'exemptions)
                  (assoc-ref report 'inventory))
          (for-each (lambda (error) (format #t "FAIL ~a~%" error)) errors)))
    (exit (if (null? errors) 0 1))))

(main (cdr (command-line)))
