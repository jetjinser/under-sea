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
                    (levels . ,(assoc-ref report 'levels))
                    (independent_l2_plus . ,(assoc-ref report 'independent_l2_plus))
                    (dependent_l2_plus . ,(assoc-ref report 'dependent_l2_plus)))))
        (begin
          (format #t "inventory=~a levels=~a independent_l2_plus=~a dependent_l2_plus=~a~%"
                  (assoc-ref report 'inventory)
                  (assoc-ref report 'levels)
                  (assoc-ref report 'independent_l2_plus)
                  (assoc-ref report 'dependent_l2_plus))
          (for-each
           (lambda (row)
             (format #t "~a ~a ~a/~a~%"
                     (assoc-ref row 'level)
                     (assoc-ref row 'source)
                     (assoc-ref row 'module)
                     (assoc-ref row 'package)))
           (assoc-ref report 'rows))))))

(main (cdr (command-line)))
