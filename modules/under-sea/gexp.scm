;;; Repository-local gexp helpers.
;;;
;;; `under-sea-script' expands to a plain-file holding the contents of a
;;; script from the repository's scripts/ directory, with the file read at
;;; macro expansion (compile) time.  Unlike `local-file' with a relative
;;; path, this is robust to how the module was loaded (absolute or relative
;;; -L, any working directory): the content is resolved while the source tree
;;; is present and baked into the compilation result.
(define-module (under-sea gexp)
  #:use-module (guix gexp)
  #:use-module (ice-9 textual-ports)
  #:export (under-sea-script))

(define-syntax under-sea-script
  (lambda (s)
    (syntax-case s ()
      ((_ name)
       (let* ((name-str (syntax->datum #'name))
              ;; The caller invokes builds from the repository root (the
              ;; Makefile does; a relative -L only resolves from there too),
              ;; so scripts/ is anchored to the expansion-time working
              ;; directory.
              (script (string-append (getcwd) "/scripts/" name-str))
              (absolute (false-if-exception (canonicalize-path script)))
              (content (call-with-input-file
                           (or absolute script)
                         get-string-all)))
         (with-syntax ((file (datum->syntax #'name name-str))
                       (data (datum->syntax #'name content)))
           #'(plain-file file data)))))))
