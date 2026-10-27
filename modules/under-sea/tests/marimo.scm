;;; System test for the under-sea marimo service.  It boots a real VM (QEMU,
;;; under the daemon) and drives it with a marionette REPL, so the service
;;; runs end to end as an unprivileged shepherd service.  The test is fully
;;; offline: it only talks to the guest's loopback interface.

(define-module (under-sea tests marimo)
  #:use-module (gnu tests)
  #:use-module (gnu system vm)
  #:use-module (guix gexp)
  #:use-module (under-sea system marimo)
  #:export (%test-under-sea-marimo
            %test-under-sea-marimo-auth))

(define (run-marimo-test)
  (define os
    (marionette-operating-system
     %under-sea-marimo-os
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
          (test-begin "under-sea-marimo")

          (test-assert "marimo service can be started"
            (marionette-eval
             '(begin
                (use-modules (gnu services herd))
                (start-service 'marimo))
             marionette))

          (test-assert "TCP port 2718 listens"
            (let loop ((n 0))
              (if (marionette-eval
                   ;; Guile's connect expects the IPv4 address as an exact
                   ;; integer; 2130706433 is 127.0.0.1.
                   '(let ((sock (socket AF_INET SOCK_STREAM 0)))
                      (catch #t
                        (lambda ()
                          (connect sock AF_INET 2130706433 2718)
                          (close-port sock)
                          #t)
                        (lambda args
                          (false-if-exception (close-port sock))
                          #f)))
                   marionette)
                  #t
                  (if (>= n 60) #f
                      (begin (usleep 500000) (loop (+ n 1)))))))

          ;; Return (code . body) for GET /, or #f if the server is not
          ;; accepting connections yet.
          (define (wait-for-http)
            (let loop ((n 0))
              (let ((result
                     (marionette-eval
                      '(begin
                         (use-modules (web client)
                                      (web response)
                                      (web uri))
                         (catch #t
                           (lambda ()
                             (call-with-values
                                 (lambda ()
                                   (http-get
                                    (string->uri
                                     "http://127.0.0.1:2718/")))
                               (lambda (response body)
                                 (cons (response-code response) body))))
                           (lambda args #f)))
                      marionette)))
                (if result
                    result
                    (if (>= n 60) #f
                        (begin (usleep 500000) (loop (+ n 1))))))))

          (test-assert "HTTP GET / returns status 200"
            (let ((result (wait-for-http)))
              (and result (= 200 (car result)))))

          (test-assert "served page contains the notebook marker"
            (let ((result (wait-for-http)))
              (and result
                   (string? (cdr result))
                   (string-contains (cdr result)
                                    "under-sea-notebook-marker"))))

          (test-assert "marimo export html executes the notebook"
            (marionette-eval
             `(begin
                (use-modules (ice-9 textual-ports))
                (define output "/tmp/marimo-export.html")
                (and (zero?
                      (system* "/run/current-system/profile/bin/marimo"
                               "export" "html"
                               ,#$%under-sea-marimo-notebook
                               "-o" output "-f"))
                     (file-exists? output)
                     (call-with-input-file output
                       (lambda (port)
                         (string-contains (get-string-all port)
                                          "under-sea-notebook-marker")))))
             marionette))

          (test-assert "working directory exists and is owned by marimo"
            (marionette-eval
             '(let* ((pw (getpwnam "marimo"))
                     (gr (getgrnam "marimo"))
                     (st (false-if-exception (stat "/var/lib/marimo"))))
                (and pw gr st
                     (= (stat:uid st) (passwd:uid pw))
                     (= (stat:gid st) (group:gid gr))))
             marionette))

          (test-end "under-sea-marimo"))))
  (system-test
   (name "under-sea-marimo")
   (description "Start the marimo notebook server through its shepherd
service as the unprivileged marimo account and verify the TCP listener, the
HTTP endpoint, the served notebook marker and the state directory ownership.")
   (value (gexp->derivation "under-sea-marimo" test))))

(define %test-under-sea-marimo (run-marimo-test))

;;; Token-authenticated variant.  The service receives only the path to the
;;; password file; the OS creates it outside the store.
(define (run-marimo-auth-test)
  (define os
    (marionette-operating-system
     %under-sea-marimo-auth-os
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
          (test-begin "under-sea-marimo-auth")

          (test-assert "token-protected marimo service can be started"
            (marionette-eval
             '(begin
                (use-modules (gnu services herd))
                (start-service 'marimo))
             marionette))

          (define (http-status auth?)
            (marionette-eval
             `(begin
                (use-modules (ice-9 popen)
                             (ice-9 textual-ports))
                (let* ((port (open-input-pipe
                              (string-append
                               "/run/current-system/profile/bin/curl"
                               " -s -o /dev/null -w '%{http_code}' "
                               ,(if auth?
                                    "-H 'Authorization: Bearer under-sea-secret' "
                                    "")
                               "http://127.0.0.1:2718/")))
                       (status (get-string-all port)))
                  (close-pipe port)
                  status))
             marionette))

          (define (wait-for-status auth?)
            (let loop ((n 0))
              (let ((status (http-status auth?)))
                (cond ((and (string? status)
                            (not (string=? status "000")))
                       status)
                      ((>= n 60) status)
                      (else (usleep 500000) (loop (+ n 1)))))))

          (test-assert "unauthenticated request is redirected or rejected"
            (let ((status (wait-for-status #f)))
              (and (string? status)
                   (member status '("303" "401" "403")))))

          (test-assert "bearer token is accepted"
            (let ((status (wait-for-status #t)))
              (string=? status "200")))

          (test-end "under-sea-marimo-auth"))))
  (system-test
   (name "under-sea-marimo-auth")
   (description "Start marimo with a token-password file and verify that an
unauthenticated request is redirected or rejected while a bearer token is
accepted.")
   (value (gexp->derivation "under-sea-marimo-auth" test))))

(define %test-under-sea-marimo-auth (run-marimo-auth-test))
