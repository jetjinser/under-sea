;;; Repository-local gexp helpers.
;;;
;;; `under-sea-script' expands to a plain-file holding the contents of a
;;; script from the repository's scripts/ directory.  `under-sea-repo-file'
;;; is the general form: it takes a path relative to the repository root.
;;; Both read the referenced file at macro expansion (compile) time, so they
;;; are robust to how the module was later loaded (absolute or relative -L,
;;; any working directory): the content is resolved while the source tree is
;;; present and baked into the compilation result.
(define-module (under-sea gexp)
  #:use-module (guix gexp)
  #:use-module (ice-9 textual-ports)
  #:export (under-sea-script
            under-sea-repo-file))

;; The repository root, anchored on this helper module's own source file as
;; found on %load-path (works with absolute and relative -L alike, from any
;; working directory).
(define %under-sea-root
  (dirname (dirname (dirname
                     (canonicalize-path
                      (or (search-path %load-path "under-sea/gexp.scm")
                          (error "under-sea gexp: source not found on %load-path")))))))

;; Collapse "." and ".." segments so caller-relative paths (../../planning/X)
;; resolve against the repository root correctly.
(define (under-sea-normalize path)
  (let* ((parts (string-split path #\/))
         (folded
          (let loop ((rest parts) (acc '()))
            (cond ((null? rest)
                   (reverse acc))
                  ((string=? (car rest) "..")
                   (if (null? acc)
                       (loop (cdr rest) (cons ".." acc))
                       (loop (cdr rest) (cdr acc))))
                  ((string=? (car rest) ".")
                   (loop (cdr rest) acc))
                  (else (loop (cdr rest) (cons (car rest) acc)))))))
    (string-join folded "/")))

(define-syntax under-sea-script
  (lambda (s)
    (syntax-case s ()
      ((_ name)
       (let* ((name-str (syntax->datum #'name))
              (content (call-with-input-file
                           (string-append %under-sea-root "/scripts/" name-str)
                         get-string-all)))
         (with-syntax ((file (datum->syntax #'name name-str))
                       (data (datum->syntax #'name content)))
           #'(plain-file file data)))))))

(define-syntax under-sea-repo-file
  (lambda (s)
    (syntax-case s ()
      ((_ rel)
       (let* ((rel-str (syntax->datum #'rel))
              (content (call-with-input-file
                           (under-sea-normalize
                            (string-append %under-sea-root "/" rel-str))
                         get-string-all)))
         (with-syntax ((file (datum->syntax #'rel (basename rel-str)))
                       (data (datum->syntax #'rel content)))
           #'(plain-file file data)))))))
