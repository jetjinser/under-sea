;;; System test for the under-sea Seafile client service.  It boots a real VM
;;; (QEMU, under the daemon) and drives it with a marionette REPL, so the
;;; daemon runs end to end as an unprivileged shepherd service.  The test is
;;; offline: no Seafile server account is configured, and the daemon only
;;; needs its local RPC socket to come up.
(define-module (under-sea tests seafile)
  #:use-module (gnu tests)
  #:use-module (gnu system)
  #:use-module (gnu system vm)
  #:use-module (guix gexp)
  #:use-module (under-sea system seafile)
  #:export (%test-under-sea-seafile))

(define (run-seafile-test)
  (define os
    (marionette-operating-system
     %under-sea-seafile-os
     #:imported-modules '((gnu services herd)
                          (guix combinators))))
  (define vm
    (virtual-machine (operating-system os)))
  (define test
    (with-imported-modules '((gnu build marionette)
                             (guix build utils))
      #~(begin
          (use-modules (gnu build marionette)
                       (guix build utils)
                       (srfi srfi-64))

          (define marionette
            (make-marionette (list #$vm)))

          (test-runner-current (system-test-runner #$output))
          (test-begin "under-sea-seafile")

          (test-assert "seafile service can be started"
            (marionette-eval
             '(begin
                (use-modules (gnu services herd))
                (start-service 'seafile))
             marionette))

          (test-assert "daemon created its RPC socket"
            (let loop ((n 0))
              (if (marionette-eval
                   '(file-exists?
                     "/var/lib/seafile/data/seafile-data/seafile.sock")
                   marionette)
                  #t
                  (if (>= n 60)
                      #f
                      (begin (usleep 250000) (loop (+ n 1)))))))

          (test-assert "daemon runs as the seafile account"
            (let loop ((n 0))
              (if (marionette-eval
                   '(begin
                      (use-modules (ice-9 ftw) (srfi srfi-1)
                                   (ice-9 textual-ports))
                      ;; Read the real and effective UIDs from procfs rather
                      ;; than relying on /proc/PID ownership.
                      (define (proc-uids pid)
                        (let ((status (string-append "/proc/" pid "/status")))
                          (and (file-exists? status)
                               (call-with-input-file status
                                 (lambda (port)
                                   (let loop ((line (get-line port)))
                                     (cond ((eof-object? line) #f)
                                           ((string-prefix? "Uid:" line)
                                            (filter-map
                                             string->number
                                             (cdr (string-split line #\tab))))
                                           (else
                                            (loop (get-line port))))))))))
                      (let ((uid (passwd:uid (getpwnam "seafile"))))
                        (any (lambda (pid)
                               (let ((cmdline
                                      (string-append "/proc/" pid "/cmdline")))
                                 (and (file-exists? cmdline)
                                      (call-with-input-file cmdline
                                        (lambda (port)
                                          (let ((s (get-string-all port)))
                                            (and (string? s)
                                                 (string-contains s
                                                                  "seaf-daemon")))))
                                      (let ((uids (proc-uids pid)))
                                        (and uids (member uid uids))))))
                             (scandir "/proc"
                                      (lambda (name)
                                        (char-numeric? (string-ref name 0)))))))
                   marionette)
                  #t
                  (if (>= n 60)
                      #f
                      (begin (usleep 250000) (loop (+ n 1)))))))

          (test-assert "seaf-cli status succeeds against the running daemon"
            (let loop ((n 0))
              (if (marionette-eval
                   '(zero? (system*
                            "/run/current-system/profile/bin/seaf-cli"
                            "status" "-c" "/var/lib/seafile/conf"))
                   marionette)
                  #t
                  (if (>= n 40)
                      #f
                      (begin (usleep 250000) (loop (+ n 1)))))))

          (test-assert "state directory is owned by seafile"
            (marionette-eval
             '(let* ((pw (getpwnam "seafile"))
                     (gr (getgrnam "seafile"))
                     (st (stat "/var/lib/seafile")))
                (and pw gr st
                     (= (stat:uid st) (passwd:uid pw))
                     (= (stat:gid st) (group:gid gr))))
             marionette))

          (test-end "under-sea-seafile"))))
  (system-test
   (name "under-sea-seafile")
   (description "Start the Seafile sync client through its shepherd service
as the unprivileged seafile account and verify the RPC socket, the daemon
process, the CLI status command and the state directory ownership.")
   (value (gexp->derivation "under-sea-seafile" test))))

(define %test-under-sea-seafile (run-seafile-test))
