;;; System test for the under-sea Autodesk Licensing Service.  It boots a real
;;; VM (QEMU, under the daemon) and drives it with a marionette REPL, so the
;;; service that was previously impossible to exercise without host root runs
;;; end to end as an unprivileged shepherd service.  A license is not required:
;;; the test only verifies the service's lifecycle.

(define-module (under-sea tests adsk-licensing)
  #:use-module (gnu tests)
  #:use-module (gnu system vm)
  #:use-module (guix gexp)
  #:use-module (under-sea system adsk-licensing)
  #:export (%test-under-sea-adsk-licensing))

(define (run-adsk-licensing-test)
  (define os
    (marionette-operating-system
     %under-sea-adsk-licensing-os
     #:imported-modules '((gnu services herd)
                          (guix combinators))))
  (define vm
    (virtual-machine (operating-system os)
                     (memory-size 1024)))
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
          (test-begin "under-sea-adsk-licensing")

          (test-assert "adsk-licensing service can be started"
            (marionette-eval
             '(begin
                (use-modules (gnu services herd))
                (start-service 'adsk-licensing))
             marionette))

          (test-assert "state directory exists and is owned by adsklic"
            (marionette-eval
             '(let* ((pw (getpwnam "adsklic"))
                     (gr (getgrnam "adsklic"))
                     (st (stat "/var/opt/Autodesk/AdskLicensingService")))
                (and pw gr st
                     (= (stat:uid st) (passwd:uid pw))
                     (= (stat:gid st) (group:gid gr))))
             marionette))

          (test-assert "AdskLicensingService runs as the adsklic account"
            (let loop ((n 0))
              (if (marionette-eval
                   '(begin
                      (use-modules (ice-9 ftw) (ice-9 textual-ports)
                                   (srfi srfi-1))
                      (let ((uid (passwd:uid (getpwnam "adsklic"))))
                        (any (lambda (pid)
                               (let ((cmdline (string-append "/proc/" pid "/cmdline")))
                                 (and (file-exists? cmdline)
                                      (call-with-input-file cmdline
                                        (lambda (port)
                                          (let ((s (get-string-all port)))
                                            (and (string? s)
                                                 (string-contains s "AdskLicensingService")))))
                                      (= uid (stat:uid (stat (string-append "/proc/" pid)))))))
                             (scandir "/proc"
                                      (lambda (name)
                                        (char-numeric? (string-ref name 0)))))))
                   marionette)
                  #t
                  (if (>= n 20) #f (begin (usleep 250000) (loop (+ n 1)))))))

          (test-end "under-sea-adsk-licensing"))))
  (system-test
   (name "under-sea-adsk-licensing")
   (description "Start the Autodesk Licensing Service through its shepherd
service as the unprivileged adsklic account and verify it runs.")
   (value (gexp->derivation "under-sea-adsk-licensing" test))))

(define %test-under-sea-adsk-licensing (run-adsk-licensing-test))
