;;; Whole-channel source hygiene scan.
;;;
;;; Two conservative checks over every module file:
;;;   1. unused imports — a (guix|srfi|ice-9|under-sea …) module whose ENTIRE
;;;      exported surface never appears in the file body;
;;;   2. dead private definitions — a top-level define that is neither
;;;      exported nor define-public and whose name occurs exactly once in
;;;      the file (the definition itself).
;;; Exits non-zero when anything is found.  Usage:
;;;   guix repl -L modules scripts/verify-hygiene.scm
(use-modules (ice-9 rdelim)
             (ice-9 ftw)
             (guix gexp)
             (srfi srfi-1))

(define exit-code 0)

(define (all-lines port)
  (let loop ((acc '()))
    (let ((l (read-line port)))
      (if (eof-object? l) (reverse acc) (loop (cons l acc))))))

(define (scm-files dir)
  (let ((entries (scandir dir)))
    (append
     (filter (lambda (f) (string-suffix? ".scm" f))
             (map (lambda (f) (string-append dir "/" f)) entries))
     (append-map
      (lambda (f)
        (if (member f '("." "..")) '()
            (let ((p (string-append dir "/" f)))
              (if (file-is-directory? p) (scm-files p) '()))))
      entries))))

(define (flatten-syms x)
  (cond ((null? x) '())
        ((pair? x) (append (flatten-syms (car x)) (flatten-syms (cdr x))))
        ((symbol? x) (list x))
        (else '())))

(define (module-imports clauses)
  (filter-map
   (lambda (c)
     (if (and (pair? c) (eq? (car c) '#:use-module)
              (pair? (cdr c)) (list? (cadr c))
              (not (memq '#:prefix (cddr c)))
              (not (memq '#:select (cddr c)))
              (not (memq '#:hide (cddr c))))
         (cadr c)
         #f))
   clauses))

(define (module-exports clauses)
  (let ((c (find (lambda (x)
                   (and (pair? x) (eq? (car x) '#:export)))
                 clauses)))
    (if c (flatten-syms (cdr c)) '())))

(define (rest-defines port)
  (let loop ((acc '()))
    (let ((d (read port)))
      (if (eof-object? d)
          (reverse acc)
          (loop
           (if (and (pair? d)
                    (memq (car d)
                          '(define define-public define* define*-public
                            define-syntax)))
               (cons (cons (car d)
                           (if (pair? (cadr d)) (car (cadr d)) (cadr d)))
                     acc)
               acc))))))

(define (word-used? body s)
  (let loop ((pos 0))
    (let ((found (string-contains body s pos)))
      (and found
           (let* ((before (if (zero? found) #\space
                              (string-ref body (1- found))))
                  (ai (+ found (string-length s)))
                  (after (if (>= ai (string-length body))
                             #\space (string-ref body ai))))
             (if (and (member before (list #\space #\( #\newline #\tab #\; #\"))
                      (member after (list #\space #\) #\newline #\tab)))
                 #t
                 (loop (1+ found))))))))

(define (module-unused-imports body imports)
  (filter
   (lambda (mod)
     (catch #t
       (lambda ()
         (let* ((iface (resolve-interface mod))
                (syms (hash-fold (lambda (n _ a) (cons n a))
                                 '() (module-obarray iface))))
           (and (pair? syms)
                (not (any (lambda (s)
                            (word-used? body (symbol->string s)))
                          syms)))))
       (lambda (key . args) #f)))
   imports))

(define (count-occurrences body s)
  (let loop ((pos 0) (n 0))
    (let ((f (string-contains body s pos)))
      (if f
          (loop (+ f (string-length s)) (1+ n))
          n))))

(define (check-file file)
  (catch #t
    (lambda ()
      (let* ((lines (call-with-input-file file all-lines))
             (body (string-join lines "\n"))
             (head (call-with-input-file file read))
             (clauses (cddr head))
             (imports (module-imports clauses))
             (exports (module-exports clauses))
             (defs (call-with-input-file file rest-defines))
             (unused (module-unused-imports body imports)))
        (unless (null? unused)
          (set! exit-code 1)
          (format #t "~a: unused imports: ~{~a~^, ~}~%" file unused))
        (let* ((pub (map cdr (filter (lambda (d)
                                       (or (eq? (car d) 'define*-public)
                                           (eq? (car d) 'define-public)))
                                     defs)))
               (names (map cdr defs))
               (dead (filter (lambda (d)
                               (and (not (memq d exports))
                                    (not (memq d pub))
                                    (= 1 (count-occurrences
                                          body (symbol->string d)))))
                             names)))
          (unless (null? dead)
            (set! exit-code 1)
            (format #t "~a: unreferenced private definitions: ~{~a~^, ~}~%"
                    file dead)))))
    (lambda (key . args)
      (set! exit-code 1)
      (format #t "~a: scan error: ~a~%" file key))))

(for-each check-file (scm-files "modules"))
(exit exit-code)
