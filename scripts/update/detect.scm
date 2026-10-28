#!/usr/bin/env guile
!#
(use-modules (common)
             (ice-9 format)
             (ice-9 match)
             (json))

(define (main args)
  (let* ((all? (member "--all" args))
         (json? (member "--json" args))
         (packages (manifest-packages))
         (selected
          (cond (all? (map car packages))
                (else
                 (let loop ((rest args) (acc '()))
                   (cond ((null? rest) (reverse acc))
                         ((string=? (car rest) "--package")
                          (loop (cddr rest) (cons (cadr rest) acc)))
                         (else (loop (cdr rest) acc))))))))
    (unless (pair? selected)
      (error "pass --all or --package NAME"))
    (let ((rows (map (lambda (name)
                       (let ((pkg (assoc-ref packages name)))
                         (unless pkg (error "unknown package" name))
                         (detect-package name pkg)))
                     selected)))
      (if json?
          (display (scm->json-string (list->vector rows)))
          (for-each
           (lambda (row)
             (format #t "~a ~a ~a -> ~a~%"
                     (assoc-ref row 'status)
                     (assoc-ref row 'package)
                     (assoc-ref row 'current)
                     (or (assoc-ref row 'latest) "?")))
           rows)))))

(main (cdr (command-line)))
