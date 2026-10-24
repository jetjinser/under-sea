;;; Real-system smoke tests for the REA CLI.  REA is a CLI/MCP stdio program,
;;; so the test boots a minimal VM and exercises the installed command instead
;;; of starting a shepherd service.

(define-module (under-sea tests rea)
  #:use-module (gnu tests)
  #:use-module (gnu system)
  #:use-module (gnu system vm)
  #:use-module (guix gexp)
  #:use-module (under-sea system rea)
  #:export (%test-under-sea-rea))

(define (run-rea-test)
  (define os
    (marionette-operating-system
     %under-sea-rea-os
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
          (test-begin "under-sea-rea")

          (test-assert "rea --version runs"
            (marionette-eval
             '(zero? (system* "/run/current-system/profile/bin/rea"
                              "--version"))
             marionette))

          (test-assert "rea reports its version"
            (marionette-eval
             '(begin
                (use-modules (ice-9 popen)
                             (ice-9 textual-ports))
                (let* ((port (open-input-pipe
                              "/run/current-system/profile/bin/rea --version"))
                       (output (get-string-all port)))
                  (close-pipe port)
                  (string-contains output "6.7.0")))
             marionette))

          (test-assert "rea --help runs"
            (marionette-eval
             '(zero? (system* "/run/current-system/profile/bin/rea"
                              "--help"))
             marionette))

          (test-assert "rea MCP stdio server answers initialize"
            (marionette-eval
             '(begin
                (use-modules (ice-9 popen)
                             (ice-9 rdelim))
                (let* ((port (open-pipe* OPEN_BOTH
                                         "/run/current-system/profile/bin/rea"
                                         "--mcp"))
                       (request
                        (string-append
                         "{\"jsonrpc\":\"2.0\",\"id\":1,"
                         "\"method\":\"initialize\","
                         "\"params\":{\"protocolVersion\":\"2024-11-05\","
                         "\"capabilities\":{},"
                         "\"clientInfo\":{\"name\":\"test\",\"version\":\"1\"}}}\n")))
                  (display request port)
                  (force-output port)
                  (let ((line (read-line port)))
                    (close-pipe port)
                    (and line (string-contains line "\"serverInfo\"")))))
             marionette))

          ;; A static JavaScript analysis path that needs no external engine.
          (test-assert "rea analyzes a local JavaScript application"
            (marionette-eval
             '(begin
                (use-modules (guix build utils)
                             (ice-9 popen)
                             (ice-9 textual-ports))
                (mkdir-p "/tmp/rea-app")
                (call-with-output-file "/tmp/rea-app/package.json"
                  (lambda (port)
                    (display "{\"name\":\"test\",\"main\":\"index.js\"}\n"
                             port)))
                (call-with-output-file "/tmp/rea-app/index.js"
                  (lambda (port)
                    (display "const x = 1;\nconsole.log(x);\n" port)))
                (let* ((port (open-input-pipe
                              (string-append
                               "/run/current-system/profile/bin/rea "
                               "analyze-javascript-application /tmp/rea-app "
                               "--format json 2>/dev/null")))
                       (output (get-string-all port)))
                  (close-pipe port)
                  (and (string-contains output "rea-javascript-application")
                       (string-contains output "\"subject\""))))
             marionette))

          (test-end "under-sea-rea"))))
  (system-test
   (name "under-sea-rea")
   (description "Run the installed REA CLI in a minimal VM and verify its
version, help output, MCP stdio initialization and a static JavaScript
analysis.")
   (value (gexp->derivation "under-sea-rea" test))))

(define %test-under-sea-rea (run-rea-test))
