;;; Verify planning/precompiled-exceptions.json: every listed recipe resolves,
;;; and every entry whose kind implies a shipped artifact has a fixed-output
;;; sha256 source.  Usage: guix repl -L "$PWD/modules" scripts/verify-exceptions.scm

(use-modules (ice-9 textual-ports)
             (json)
             (guix packages)
             (guix hash))

(define manifest
  (json-string->scm
   (call-with-input-file "planning/precompiled-exceptions.json" get-string-all)))

(define entries (vector->list (cdr (assoc "exceptions" manifest))))

(define (field entry key)
  (let ((pair (assoc key entry)))
    (and pair (cdr pair))))

(define (sha256-origin? source)
  (and (origin? source)
       (let ((h (origin-hash source)))
         (and (content-hash? h)
              (eq? 'sha256 (content-hash-algorithm h))))))

(define failures 0)
(define count 0)

(for-each
 (lambda (entry)
   (set! count (1+ count))
   (let* ((name (field entry "name"))
          (module (string->symbol (field entry "module")))
          (recipe (string->symbol (field entry "recipe")))
          (kind (field entry "kind"))
          (module-name `(under-sea packages ,module))
          (pkg (catch #t
                 (lambda ()
                   (module-ref (resolve-interface module-name) recipe))
                 (lambda (key . args) #f))))
     (cond
      ((not (package? pkg))
       (set! failures (1+ failures))
       (format (current-error-port) "FAIL ~a: recipe ~a not found in ~a~%"
               name recipe module-name))
      (else
       (let ((needs-source? (member kind '("prebuilt" "wheel" "closed" "bootstrap"))))
         (if (and needs-source? (not (sha256-origin? (package-source pkg))))
             (begin
               (set! failures (1+ failures))
               (format (current-error-port)
                       "FAIL ~a: no fixed-output sha256 source (kind ~a)~%" name kind))
             (format #t "ok   ~a [~a] ~a~%"
                     name kind
                     (if (sha256-origin? (package-source pkg)) "sha256-source" "no-source"))
             ))))))
 entries)

(format #t "verify-exceptions: ~a entries, ~a failure(s)~%" count failures)
(exit (if (zero? failures) 0 1))
