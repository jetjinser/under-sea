;;; System test for the under-sea Hermes gateway service.  It boots a real
;;; VM (QEMU, under the daemon) and drives it with a marionette REPL, so the
;;; gateway runs end to end as an unprivileged shepherd service.  No
;;; messaging credentials are configured: the test verifies the service
;;; lifecycle, the state directory and the gateway process itself.

(define-module (under-sea tests hermes)
  #:use-module (gnu tests)
  #:use-module (gnu system vm)
  #:use-module (guix gexp)
  #:use-module (under-sea system hermes)
  #:export (%test-under-sea-hermes))

(define (run-hermes-test)
  (define os
    (marionette-operating-system
     %under-sea-hermes-os
     #:imported-modules '((gnu services herd)
                          (guix combinators))))
  (define vm
    (virtual-machine (operating-system os)
                     (memory-size 2048)))
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
          (test-begin "under-sea-hermes")

          (test-begin "under-sea-hermes")

          (test-assert "hermes service can be started"
            (marionette-eval
             '(begin
                (use-modules (gnu services herd))
                (start-service 'hermes))
             marionette))

          (test-assert "state directory exists and is owned by hermes"
            (marionette-eval
             '(let* ((pw (getpwnam "hermes"))
                     (gr (getgrnam "hermes"))
                     (st (stat "/var/lib/hermes")))
                (and pw gr st
                     (= (stat:uid st) (passwd:uid pw))
                     (= (stat:gid st) (group:gid gr))))
             marionette))

          (test-assert "gateway runs as the hermes account"
            (let loop ((n 0))
              (if (marionette-eval
                   '(begin
                      (use-modules (ice-9 ftw) (srfi srfi-1))
                      (let ((uid (passwd:uid (getpwnam "hermes"))))
                        (any (lambda (pid)
                               (let ((cmdline (string-append "/proc/" pid "/cmdline")))
                                 (and (file-exists? cmdline)
                                      (call-with-input-file cmdline
                                        (lambda (port)
                                          (let ((s (get-string-all port)))
                                            (and (string? s)
                                                 (string-contains s "gateway")))))
                                      (= uid (stat:uid (stat (string-append "/proc/" pid)))))))
                             (scandir "/proc"
                                      (lambda (name)
                                        (char-numeric? (string-ref name 0)))))))
                   marionette)
                  #t
                  (if (>= n 60) #f (begin (usleep 500000) (loop (+ n 1)))))))

          (test-assert "diagnostics captured"
            (marionette-eval
             '(begin
                (use-modules (gnu services herd)
                             (ice-9 textual-ports)
                             (ice-9 format))
                (define (slurp f)
                  (false-if-exception
                   (call-with-input-file f get-string-all)))
                (format #t "HERMES-DIAG gateway-log: ~s~%"
                        (slurp "/var/log/hermes.log"))
                #t)
             marionette))

          (test-assert "gateway log file exists and is non-empty"
            (marionette-eval
             '(let ((st (false-if-exception (stat "/var/log/hermes.log"))))
                (and st (> (stat:size st) 0)))
             marionette))

          (test-end "under-sea-hermes"))))
  (system-test
   (name "under-sea-hermes")
   (description "Start the Hermes Agent gateway through its shepherd service
as the unprivileged hermes account and verify the lifecycle, the state
directory ownership and the gateway process.")
   (value (gexp->derivation "under-sea-hermes" test))))

(define %test-under-sea-hermes (run-hermes-test))
