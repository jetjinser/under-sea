;;; Verify planning/precompiled-exceptions.json: every listed recipe resolves,
;;; and every entry whose kind implies a shipped artifact has a fixed-output
;;; sha256 source.  Also verify that every package whose description marks it
;;; a source-unavailable exception is listed in the manifest.
;;; Usage: guix repl -L "$PWD/modules" scripts/verify-exceptions.scm

(use-modules (ice-9 ftw)
             (ice-9 regex)
             (ice-9 textual-ports)
             (json)
             (guix packages)
             (guix hash)
             (srfi srfi-1)
             (srfi srfi-13))

(define package-root "modules/under-sea/packages")

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

(define (package-files)
  (map (lambda (name) (string-append package-root "/" name))
       (filter (lambda (name) (string-suffix? ".scm" name))
               (scandir package-root
                        (lambda (name) (not (member name '("." ".."))))))))

(define %define-public-rx
  (make-regexp "^\\(define-public[[:blank:]]+([a-z0-9-]+)" regexp/newline))

(define (file-definitions file)
  "Return (NAME . BLOCK) for each top-level define-public form in FILE."
  (let* ((text (call-with-input-file file get-string-all))
         (matches
          (let loop ((start 0) (acc '()))
            (let ((m (regexp-exec %define-public-rx text start)))
              (if m
                  (loop (match:end m) (cons m acc))
                  (reverse acc))))))
    (let loop ((rest matches) (acc '()))
      (if (null? rest)
          (reverse acc)
          (let* ((m (car rest))
                 (start (match:start m))
                 (end (if (null? (cdr rest))
                          (string-length text)
                          (match:start (cadr rest))))
                 (name (match:substring m 1))
                 (block (substring text start end)))
            (loop (cdr rest) (cons (cons name block) acc)))))))

(define %source-unavailable-rx
  (make-regexp "source-unavailable(/[a-z-]+)?[[:space:]]+exception"))

(define (description-mentions? block)
  (let* ((normalized (string-join (string-tokenize block) " "))
         (pos (string-contains normalized "(description")))
    (and pos
         (regexp-exec %source-unavailable-rx normalized pos))))

(define listed (map (lambda (entry) (field entry "recipe")) entries))

(define failures 0)
(define count 0)
(define detected 0)

;; Every package that describes itself as a source-unavailable exception must
;; appear in the manifest, or the manifest is silently incomplete.
(for-each
 (lambda (file)
   (for-each
    (lambda (definition)
      (let ((name (car definition)))
        (when (description-mentions? (cdr definition))
          (set! detected (1+ detected))
          (unless (member name listed)
            (set! failures (1+ failures))
            (format (current-error-port)
                    "FAIL ~a: unlisted source-unavailable package ~a~%"
                    file name)))))
    (file-definitions file)))
 (package-files))

(when (and (pair? listed) (zero? detected))
  (set! failures (1+ failures))
  (format (current-error-port)
          "FAIL no source-unavailable packages detected; the scanner may be broken~%"))

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

(format #t "verify-exceptions: ~a entries, ~a source-unavailable package(s), ~a failure(s)~%"
        count detected failures)
(exit (if (zero? failures) 0 1))
