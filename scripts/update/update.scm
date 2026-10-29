#!/usr/bin/env guile
!#
(use-modules (common)
             (ice-9 format)
             (ice-9 match)
             (ice-9 popen)
             (ice-9 rdelim)
             (json)
             (srfi srfi-1))

(define (flag? args flag) (and (member flag args) #t))

(define (option args name default)
  (let loop ((rest args))
    (cond ((null? rest) default)
          ((string=? (car rest) name) (cadr rest))
          (else (loop (cdr rest))))))

(define (options args name)
  (let loop ((rest args) (acc '()))
    (cond ((null? rest) (reverse acc))
          ((string=? (car rest) name) (loop (cddr rest) (cons (cadr rest) acc)))
          (else (loop (cdr rest) acc)))))

(define (changed-package-files)
  (let* ((output (run/check-output "git" "status" "--porcelain"))
         (lines (filter (lambda (line) (not (string-null? line)))
                        (string-split output #\newline))))
    (filter (lambda (path) (string-prefix? "modules/under-sea/packages/" path))
            (map (lambda (line) (substring line 3)) lines))))

(define (run-command . args)
  (let ((status (apply system* args)))
    (unless (zero? status)
      (error "command failed" args status))))

(define (prepare-command name pkg level target workdir apply? verify?)
  (if (string=? level "L2")
      (append
       (list "guile" "--no-auto-compile" "-L"
             (string-append root "/scripts/update")
             "-s" (string-append root "/scripts/update/prepare.scm")
             "--package" name "--version" target "--workdir" workdir)
       (if apply? '("--apply") '())
       (if verify? '("--verify") '()))
      (append
       (list "python3" (string-append root "/scripts/update/run.py")
             "prepare" "--package" name "--version" target
             "--workdir" workdir)
       (if apply? '("--apply") '())
       (if verify? '("--verify") '()))))

(define (update-one name pkg version workdir apply? verify? vm? commit? force?)
  (let* ((detected (detect-package name pkg))
         (current (assoc-ref detected 'current))
         (target (or version (assoc-ref detected 'latest)))
         (level (assoc-ref pkg "autonomy")))
    (cond
     ((not target)
      `((package . ,name) (status . "error") (error . "no upstream version")))
     ((and (not force?) (string=? target current))
      `((package . ,name) (status . "current") (version . ,current)))
     ((member level '("L0" "L1"))
      `((package . ,name) (status . "skipped-level")
        (level . ,level) (version . ,current)))
     (else
      (let* ((pkgdir (string-append workdir "/" name "-" target))
             (cmd (prepare-command name pkg level target pkgdir apply? verify?)))
        (when apply?
          (apply run-command cmd))
        (let ((result `((package . ,name)
                        (current . ,current)
                        (target . ,target)
                        (level . ,level)
                        (adapter . ,(assoc-ref pkg "adapter"))
                        (status . ,(if apply? "applied" "dry-run")))))
          (when (and apply? commit?)
            (let ((files (changed-package-files)))
              (if (null? files)
                  (set! result (assoc-set! result 'status "no-change"))
                  (begin
                    (apply run-command (append (list "git" "add") files))
                    (run-command "git" "commit" "-S" "-m"
                                 (string-append name ": update to " target))
                    (set! result (assoc-set! result 'status "committed"))))))
          (when (and apply? verify? vm?)
            (run-command "python3"
                         (string-append root "/scripts/update/vm.py")
                         "--package" name)
            (set! result (assoc-set! result 'vm "passed")))
          result))))))

(define (main args)
  (let* ((all? (flag? args "--all"))
         (version (option args "--version" #f))
         (workdir (option args "--workdir" "/var/tmp/under-sea-update"))
         (apply? (flag? args "--apply"))
         (verify? (flag? args "--verify"))
         (vm? (flag? args "--vm"))
         (commit? (flag? args "--commit"))
         (force? (flag? args "--force"))
         (json? (flag? args "--json"))
         (selected (if all?
                       (map car (manifest-packages))
                       (options args "--package"))))
    (unless (pair? selected) (error "pass --all or --package NAME"))
    (when (and version (not (= (length selected) 1)))
      (error "--version requires exactly one package"))
    (when (and verify? (not apply?)) (error "--verify requires --apply"))
    (when (and vm? (not verify?)) (error "--vm requires --verify"))
    (when (and commit? (not verify?)) (error "--commit requires --verify"))
    (let ((packages (manifest-packages))
          (rows '()))
      (for-each
       (lambda (name)
         (let ((pkg (assoc-ref packages name)))
           (if pkg
               (set! rows (cons (update-one name pkg version workdir
                                            apply? verify? vm? commit? force?)
                                rows))
               (set! rows (cons `((package . ,name) (status . "error")
                                  (error . "not in manifest")) rows)))))
       selected)
      (set! rows (reverse rows))
      (if json?
          (display (scm->json-string (list->vector rows)))
          (for-each
           (lambda (row)
             (format #t "~a ~a ~a~%"
                     (assoc-ref row 'status)
                     (assoc-ref row 'package)
                     (or (assoc-ref row 'target) "")))
           rows)))))

(main (cdr (command-line)))
