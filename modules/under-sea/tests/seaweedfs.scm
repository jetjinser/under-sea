;;; System test for the under-sea SeaweedFS service.  It boots a real VM
;;; (QEMU, under the daemon) and drives it with a marionette REPL, so the
;;; single-process `weed server' runs end to end as an unprivileged shepherd
;;; service.  Everything is local: no external network is used.

(define-module (under-sea tests seaweedfs)
  #:use-module (gnu tests)
  #:use-module (gnu system vm)
  #:use-module (guix gexp)
  #:use-module (under-sea system seaweedfs)
  #:export (%test-under-sea-seaweedfs))

(define (run-seaweedfs-test)
  (define os
    (marionette-operating-system
     %under-sea-seaweedfs-os
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
          (test-begin "under-sea-seaweedfs")

          (test-assert "seaweedfs service can be started"
            (marionette-eval
             '(begin
                (use-modules (gnu services herd))
                (start-service 'seaweedfs))
             marionette))

          (test-assert "data directory exists and is owned by seaweedfs"
            (marionette-eval
             '(let* ((pw (getpwnam "seaweedfs"))
                     (gr (getgrnam "seaweedfs"))
                     (st (stat "/var/lib/seaweedfs")))
                (and pw gr st
                     (= (stat:uid st) (passwd:uid pw))
                     (= (stat:gid st) (group:gid gr))))
             marionette))

          ;; Each port is bound on 127.0.0.1, so its /proc/net/tcp entry is
          ;; 0100007F:<uppercase hex port>.  Poll until all four listeners are
          ;; up, then report each one separately.
          (define listeners
            (marionette-eval
             '(begin
                (use-modules (ice-9 textual-ports))
                (define (file-contains? file needle)
                  (and (file-exists? file)
                       (call-with-input-file file
                         (lambda (port)
                           (string-contains (get-string-all port) needle)))))
                (define (port-listening? port)
                  (let ((needle
                         (string-append "0100007F:"
                                        (string-upcase
                                         (number->string port 16)))))
                    (or (file-contains? "/proc/net/tcp" needle)
                        (file-contains? "/proc/net/tcp6" needle))))
                (define (wait-for pred)
                  (let loop ((n 0))
                    (cond ((pred) #t)
                          ((>= n 60) #f)
                          (else (usleep 500000) (loop (+ n 1))))))
                (map (lambda (port) (wait-for (lambda () (port-listening? port))))
                     '(9333 8080 8888 8333)))
             marionette))

          (test-assert "master port 9333 is listening"
            (list-ref listeners 0))

          (test-assert "volume port 8080 is listening"
            (list-ref listeners 1))

          (test-assert "filer port 8888 is listening"
            (list-ref listeners 2))

          (test-assert "S3 port 8333 is listening"
            (list-ref listeners 3))

          ;; A real HTTP status line from the S3 gateway: GET / lists buckets
          ;; and answers 200 with an XML body.
          (define s3-response
            (marionette-eval
             '(begin
                (use-modules (ice-9 rdelim))
                (define (http-status port)
                  (catch #t
                    (lambda ()
                      (let ((s (socket AF_INET SOCK_STREAM 0)))
                        (connect s AF_INET INADDR_LOOPBACK port)
                        (display
                         "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
                         s)
                        (force-output s)
                        (let ((line (read-line s)))
                          (close-port s)
                          line)))
                    (lambda (key . args) #f)))
                (let loop ((n 0))
                  (let ((status (http-status 8333)))
                    (cond ((and status
                                (string-prefix? "HTTP/1.1 200" status))
                           status)
                          ((>= n 40) status)
                          (else (usleep 500000) (loop (+ n 1)))))))
             marionette))

          (test-assert "S3 gateway answers a minimal HTTP request"
            (and (string? s3-response)
                 (string-prefix? "HTTP/1.1 200" s3-response)))

          ;; Exercise the S3 data path, not just the status endpoint: create a
          ;; bucket, upload an object, read it back byte-for-byte, then delete
          ;; both.  The test OS installs curl for this.
          (test-assert "S3 bucket and object round-trip"
            (marionette-eval
             '(begin
                (use-modules (ice-9 popen)
                             (ice-9 textual-ports))
                (define curl "/run/current-system/profile/bin/curl")
                (define base "http://127.0.0.1:8333")
                (define (run . args)
                  (zero? (apply system* curl args)))
                (define (fetch url)
                  (let* ((port (open-input-pipe
                                (string-append curl " -fsS " url)))
                         (body (get-string-all port)))
                    (close-pipe port)
                    body))
                (and (run "-fsS" "-X" "PUT"
                          (string-append base "/under-sea-test"))
                     (run "-fsS" "-X" "PUT" "--data-binary"
                          "hello-seaweedfs"
                          (string-append base "/under-sea-test/hello.txt"))
                     (string=? (fetch (string-append
                                       base "/under-sea-test/hello.txt"))
                               "hello-seaweedfs")
                     (run "-fsS" "-X" "DELETE"
                          (string-append base "/under-sea-test/hello.txt"))
                     (run "-fsS" "-X" "DELETE"
                          (string-append base "/under-sea-test"))))
             marionette))

          ;; The administrative shell is a separate client binary entry point;
          ;; drive one non-interactive command through stdin.
          (test-assert "weed shell cluster.check succeeds"
            (marionette-eval
             '(begin
                (use-modules (ice-9 popen)
                             (ice-9 textual-ports))
                (let* ((port (open-input-pipe
                              (string-append
                               "printf 'cluster.check\\n' | "
                               "/run/current-system/profile/bin/weed shell "
                               "-master=127.0.0.1:9333 2>/dev/null")))
                       (output (get-string-all port)))
                  (close-pipe port)
                  (string-contains output "Topology")))
             marionette))

          (test-end "under-sea-seaweedfs"))))
  (system-test
   (name "under-sea-seaweedfs")
   (description "Start SeaweedFS through its shepherd service as the
unprivileged seaweedfs account and verify the master, volume, filer and S3
listeners, the data directory ownership and a minimal S3 HTTP response.")
   (value (gexp->derivation "under-sea-seaweedfs" test))))

(define %test-under-sea-seaweedfs (run-seaweedfs-test))
