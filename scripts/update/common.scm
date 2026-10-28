(define-module (common)
  #:use-module (json)
  #:use-module (ice-9 match)
  #:use-module (ice-9 optargs)
  #:use-module (ice-9 popen)
  #:use-module (ice-9 rdelim)
  #:use-module (ice-9 regex)
  #:use-module (ice-9 textual-ports)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-13)
  #:export (root manifest-path exemptions-path status-path
            read-json manifest-packages package-names package-ref
            current-version load-exemptions doc-expressions
            audit-report coverage-report run/check-output))

(define root
  (let ((here (dirname
               (or (current-filename)
                   (search-path %load-path "common.scm")
                   (error "common.scm not found on %load-path")))))
    (canonicalize-path (string-append here "/../.."))))

(define (path . parts)
  (string-append root "/" (string-join parts "/")))

(define manifest-path (path "planning/update-manifest.json"))
(define exemptions-path (path "planning/update-exemptions.json"))
(define status-path (path "STATUS.md"))

(define (read-json file)
  (call-with-input-file file (lambda (port) (json->scm port))))

(define (manifest-packages)
  (assoc-ref (read-json manifest-path) "packages"))

(define (package-names)
  (sort (map car (manifest-packages)) string<?))

(define (package-ref name)
  (assoc-ref (manifest-packages) name))

(define (read-text file)
  (call-with-input-file file get-string-all))

(define (current-version pkg)
  (let* ((file (path (assoc-ref pkg "pin")))
         (text (read-text file))
         (symbol (regexp-quote (assoc-ref pkg "version_symbol")))
         (rx (make-regexp
              (string-append "\\(define(?:-public)?\\s+" symbol
                             "\\s+\"([^\"]+)\"\\)")))
         (match (regexp-exec rx text)))
    (unless match
      (error "cannot find version" (assoc-ref pkg "version_symbol") file))
    (match:substring match 1)))

(define (load-exemptions)
  (let* ((data (read-json exemptions-path))
         (packages (assoc-ref data "packages")))
    (unless (equal? (assoc-ref data "schema") 1)
      (error "unsupported exemption schema"))
    (vector->list packages)))

(define (doc-expressions)
  (let ((text (read-text status-path))
        (rx (make-regexp
             "\\(@ \\(under-sea packages ([^)]+)\\) ([^)\\s]+)\\)")))
    (let loop ((start 0) (acc '()))
      (let ((m (regexp-exec rx text start)))
        (if m
            (loop (match:end m)
                  (cons (cons (match:substring m 1)
                              (match:substring m 2))
                        acc))
            (reverse acc))))))

(define (pair-key pkg)
  (cons (assoc-ref pkg "module") (assoc-ref pkg "package")))

(define* (audit-report #:key (check-docs? #t))
  (let* ((manifest (manifest-packages))
         (exemptions (load-exemptions))
         (manifest-keys (map (lambda (entry) (pair-key (cdr entry))) manifest))
         (exemption-keys (map pair-key exemptions))
         (inventory (delete-duplicates (append manifest-keys exemption-keys)))
         (errors '()))
    (for-each
     (lambda (key)
       (when (member key exemption-keys)
         (set! errors
               (cons (format #f "duplicate manifest/exemption: ~a/~a"
                             (car key) (cdr key))
                     errors))))
     manifest-keys)
    (when check-docs?
      (for-each
       (lambda (key)
         (unless (member key inventory)
           (set! errors
                 (cons (format #f "STATUS expression not classified: ~a/~a"
                               (car key) (cdr key))
                       errors))))
       (doc-expressions)))
    `((manifest . ,(length manifest))
      (exemptions . ,(length exemptions))
      (inventory . ,(length inventory))
      (errors . ,(reverse errors)))))

(define (coverage-report)
  (let* ((manifest (manifest-packages))
         (exemptions (load-exemptions))
         (rows (append
                (map (lambda (entry)
                       (let ((pkg (cdr entry)))
                         `((package . ,(car entry))
                           (module . ,(assoc-ref pkg "module"))
                           (level . ,(assoc-ref pkg "autonomy"))
                           (adapter . ,(assoc-ref pkg "adapter"))
                           (source . "manifest"))))
                     manifest)
                (map (lambda (pkg)
                       `((package . ,(assoc-ref pkg "package"))
                         (module . ,(assoc-ref pkg "module"))
                         (level . ,(assoc-ref pkg "level"))
                         (adapter . "exempt")
                         (source . "exemption")))
                     exemptions)))
         (levels (make-hash-table)))
    (for-each
     (lambda (row)
       (let* ((level (assoc-ref row 'level))
              (old (hash-ref levels level 0)))
         (hash-set! levels level (+ old 1))))
     rows)
    `((inventory . ,(length rows))
      (levels . ,(sort (hash-map->list cons levels)
                       (lambda (a b) (string<? (car a) (car b)))))
      (rows . ,(sort rows
                     (lambda (a b)
                       (let ((la (assoc-ref a 'level))
                             (lb (assoc-ref b 'level)))
                         (if (string=? la lb)
                             (string<? (assoc-ref a 'package)
                                       (assoc-ref b 'package))
                             (string<? la lb)))))))))

(define (run/check-output program args)
  (let* ((port (apply open-pipe* OPEN_READ program args))
         (output (get-string-all port))
         (status (close-pipe port)))
    (unless (zero? status)
      (error "command failed" program args status))
    output))
