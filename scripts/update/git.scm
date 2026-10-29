#!/usr/bin/env guile
!#
(use-modules (common)
             (ice-9 format)
             (ice-9 match)
             (ice-9 regex)
             (ice-9 textual-ports)
             (ice-9 ftw)
             (json))

(define (flag? args flag) (and (member flag args) #t))
(define (option args name default)
  (let loop ((rest args))
    (cond ((null? rest) default)
          ((string=? (car rest) name) (cadr rest))
          (else (loop (cdr rest))))))
(define (run-command . args)
  (let ((status (apply system* args)))
    (unless (zero? status) (error "command failed" args status))))
(define (scheme-string value) (format #f "~s" value))
(define (basename path) (car (last-pair (string-split path #\/))))
(define (subdirectories dir)
  (filter (lambda (name)
            (let ((st (stat (string-append dir "/" name))))
              (and (not (member name '("." "..")))
                   (eq? (stat:type st) 'directory))))
          (scandir dir)))
(define (read-version file regex)
  (let* ((text (call-with-input-file file get-string-all))
         (m (regexp-exec (make-regexp regex) text)))
    (unless m (error "version regex did not match" file))
    (match:substring m 1)))
(define (commit-version upstream commit)
  (string-append (or (assoc-ref upstream "version_prefix") "")
                 (substring commit 0
                            (or (assoc-ref upstream "version_length") 7))))
(define (source-text pkg commit digest)
  (let ((method (or (assoc-ref pkg "source_method") "url-fetch"))
        (version-symbol (assoc-ref pkg "version_symbol"))
        (commit-symbol (assoc-ref pkg "commit_symbol"))
        (source-symbol (assoc-ref pkg "source_symbol")))
    (if (string=? method "git-fetch")
        (string-append
         "(define-public " source-symbol "\n"
         "  (origin\n"
         "    (method git-fetch)\n"
         "    (uri (git-reference\n"
         "          (url " (scheme-string
                        (or (assoc-ref pkg "git_url")
                            (string-append "https://github.com/"
                                           (assoc-ref (assoc-ref pkg "upstream") "repo")))) ")\n"
         "          (commit " commit-symbol ")))\n"
         "    (file-name (git-file-name \"" (assoc-ref pkg "package")
         "\" " version-symbol "))\n"
         "    (sha256\n"
         "     (base32 " (scheme-string digest) "))))\n")
        (string-append
         "(define-public " source-symbol "\n"
         "  (origin\n"
         "    (method url-fetch)\n"
         "    (uri (string-append \"https://codeload.github.com/"
         (assoc-ref (assoc-ref pkg "upstream") "repo")
         "/tar.gz/\" " commit-symbol "))\n"
         "    (file-name (string-append \"" (assoc-ref pkg "package")
         "-\" " version-symbol " \".tar.gz\"))\n"
         "    (sha256\n"
         "     (base16-string->bytevector " (scheme-string digest) "))))\n"))))
(define (main args)
  (let* ((name (option args "--package" #f))
         (commit (option args "--commit" #f))
         (workdir (option args "--workdir" "/var/tmp/under-sea-update"))
         (apply? (flag? args "--apply"))
         (verify? (flag? args "--verify"))
         (json? (flag? args "--json"))
         (packages (manifest-packages))
         (pkg (and name (assoc-ref packages name))))
    (unless pkg (error "unknown package" name))
    (let* ((upstream (assoc-ref pkg "upstream"))
           (commit (or commit
                       (git-head (assoc-ref upstream "repo")
                                 (assoc-ref upstream "branch"))))
           (workdir (string-append workdir "/" name "-" commit))
           (url (string-append "https://codeload.github.com/"
                               (assoc-ref upstream "repo")
                               "/tar.gz/" commit))
           (tarball (string-append workdir "/" name "-" commit ".tar.gz")))
      (run-command "mkdir" "-p" workdir)
      (run-command "curl" "-fsSL" "--retry" "3" "--max-time" "600"
                   "-o" tarball url)
      (run-command "tar" "-xzf" tarball "-C" workdir)
      (let* ((srcdir (string-append workdir "/" (car (subdirectories workdir))))
             (version (if (assoc-ref upstream "version_file")
                          (read-version
                           (string-append srcdir "/" (assoc-ref upstream "version_file"))
                           (assoc-ref upstream "version_regex"))
                          (commit-version upstream commit)))
             (method (or (assoc-ref pkg "source_method") "url-fetch"))
             (digest (string-trim-both
                      (apply run/check-output
                             (append
                              (list "guix" "hash" "-H" "sha256"
                                    "-f" (if (string=? method "git-fetch")
                                             "nix-base32" "base16"))
                              (if (string=? method "git-fetch")
                                  (list "-r" srcdir)
                                  (list tarball))))))
             (text
              (string-append
               ";;; Generated by scripts/update/git.scm; do not edit.\n"
               "(define-module (under-sea packages " (assoc-ref pkg "pin_module") ")\n"
               "  #:use-module (guix packages)\n"
               "  #:use-module (guix download)\n"
               "  #:use-module (guix git-download)\n"
               "  #:use-module (guix base16)\n"
               "  #:use-module (guix base32)\n"
               "  #:export (" (assoc-ref pkg "version_symbol") " "
               (assoc-ref pkg "commit_symbol") " "
               (assoc-ref pkg "source_symbol") "))\n\n"
               "(define-public " (assoc-ref pkg "version_symbol") " "
               (scheme-string version) ")\n"
               "(define-public " (assoc-ref pkg "commit_symbol") " "
               (scheme-string commit) ")\n"
               (source-text pkg commit digest))))
        (call-with-output-file (string-append workdir "/" (assoc-ref pkg "pin_module") ".scm")
          (lambda (port) (display text port)))
        (when apply?
          (call-with-output-file (string-append root "/" (assoc-ref pkg "pin"))
            (lambda (port) (display text port))))
        (if json?
            (display (scm->json-string
                      `((package . ,name) (version . ,version)
                        (commit . ,commit) (applied . ,apply?))))
            (format #t "~a ~a -> ~a~%" name (if apply? "applied" "prepared") version))
        (when verify?
          (unless apply? (error "--verify requires --apply"))
          (run-command "guix" "time-machine" "-C" "channels.scm" "--"
                       "build" "-L" "modules" "--no-substitutes" "-e"
                       (string-append "(@ (under-sea packages "
                                      (assoc-ref pkg "module") ") "
                                      (assoc-ref pkg "package") ")")))))))

(main (cdr (command-line)))
