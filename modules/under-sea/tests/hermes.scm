;;; System test for the under-sea Hermes gateway service.  It boots a real
;;; VM (QEMU, under the daemon) and drives it with a marionette REPL, so the
;;; gateway runs end to end as an unprivileged shepherd service.  No
;;; messaging credentials are configured: the test verifies the service
;;; lifecycle, the state directory and the gateway process itself.

(define-module (under-sea tests hermes)
  #:use-module (gnu tests)
  #:use-module (gnu system vm)
  #:use-module (guix gexp)
  #:use-module (under-sea gexp)
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
                ;; Foreground short-run of the mock server to capture its
                ;; startup error (the shepherd service dies silently).
                (let* ((py "/run/current-system/profile/bin/hermes-python")
                       (script "/run/current-system/profile/share/hermes-e2e/mock-openai-model.py")
                       (out (slurp "/tmp/mock-fg.log")))
                  (format #t "HERMES-DIAG mock-script exists: ~s~%"
                          (and (file-exists? script) #t))
                  (unless out
                    (system (string-append py " " script
                                           " >/tmp/mock-fg.log 2>&1 &"))
                    (sleep 2))
                  (format #t "HERMES-DIAG mock-fg-log: ~s~%"
                          (slurp "/tmp/mock-fg.log")))
                (format #t "HERMES-DIAG mock-log: ~s~%"
                        (slurp "/var/log/hermes-mock-model.log"))
                (let* ((cmdline (call-with-input-file "/proc/1/cmdline"
                                  get-string-all))
                       (conf (car (last (string-split cmdline #\space)))))
                  (format #t "HERMES-DIAG shepherd conf: ~s~%" conf)
                  (let ((s (slurp conf)))
                    (format #t "HERMES-DIAG conf has mock: ~s; size ~s~%"
                            (and s (string-contains s "hermes-mock-model"))
                            (and s (string-length s)))))
                #t)
             marionette))

          (test-assert "mock model service is running"
            (marionette-eval
             '(let ((sock (socket AF_INET SOCK_STREAM 0)))
                (catch #t
                  (lambda ()
                    (connect sock AF_INET 127.0.0.1 30000)
                    (close-port sock)
                    #t)
                  (const #f)))
             marionette))

          (test-assert "offline agent turn runs against the mock model"
            (marionette-eval
             '(begin
                (use-modules (ice-9 popen) (ice-9 textual-ports))
                (let* ((port (open-input-pipe
                              (string-append
                               "/run/current-system/profile/bin/hermes-python "
                               #$(under-sea-script "hermes-e2e-driver.py"))))
                       (output (get-string-all port)))
                  (close-pipe port)
                  (format #t "HERMES-E2E output: ~s~%" output)
                  (and (string-contains output "E2E OK")
                       (file-exists? "/tmp/hermes-e2e-marker"))))
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
