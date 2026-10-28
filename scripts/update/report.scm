#!/usr/bin/env guile
!#
(use-modules (common)
             (ice-9 match)
             (ice-9 format)
             (json))

(define (main args)
  (let* ((json? (member "--json" args))
         (report (coverage-report)))
    (if json?
        (display (scm->json-string
                  `((inventory . ,(assoc-ref report 'inventory))
                    (levels . ,(assoc-ref report 'levels)))))
        (begin
          (format #t "inventory=~a levels=~a~%"
                  (assoc-ref report 'inventory)
                  (assoc-ref report 'levels))
          (for-each
           (lambda (row)
             (format #t "~a ~a ~a/~a~%"
                     (assoc-ref row 'level)
                     (assoc-ref row 'source)
                     (assoc-ref row 'module)
                     (assoc-ref row 'package)))
           (assoc-ref report 'rows))))))

(main (cdr (command-line)))
