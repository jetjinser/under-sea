;;; OpenCode v1/v2 coexistence and CLI smoke test.

(define-module (under-sea tests opencode)
  #:use-module (gnu tests)
  #:use-module (gnu system)
  #:use-module (gnu system vm)
  #:use-module (guix gexp)
  #:use-module (under-sea packages qemu-cpu)
  #:use-module (under-sea system opencode)
  #:export (%test-under-sea-opencode))

(define (run-opencode-test)
  (define os
    (marionette-operating-system
     %under-sea-opencode-os
     #:imported-modules '((gnu services herd)
                          (guix combinators))))
  (define vm
    (virtual-machine (operating-system os)
                     (memory-size 4096)
                     ;; The default qemu64 model lacks SSE4.2, which Bun's
                     ;; standalone binary requires.  This test-only wrapper
                     ;; appends -cpu max to the QEMU invocation.
                     (qemu qemu-sse42)))
  (define test
    (with-imported-modules '((gnu build marionette)
                             (guix build utils))
      #~(begin
          (use-modules (gnu build marionette)
                       (guix build utils)
                       (ice-9 textual-ports)
                       (srfi srfi-64))

          (define marionette
            (make-marionette (list #$vm)))

          ;; Bun's standalone binary requires SSE4.2.  The default QEMU CPU
          ;; model used by this test harness lacks it, so skip the runtime
          ;; assertions on such hosts instead of reporting a package failure.
          (define sse42?
            (marionette-eval
             '(begin
                (use-modules (ice-9 textual-ports))
                (call-with-input-file "/proc/cpuinfo"
                  (lambda (port)
                    (string-contains (get-string-all port) "sse4_2"))))
             marionette))

          (test-runner-current (system-test-runner #$output))
          (test-begin "under-sea-opencode")
          (test-skip (if sse42? 0 5))

          (test-assert "both launchers exist in the system profile"
            (marionette-eval
             '(and (file-exists? "/run/current-system/profile/bin/opencode-v1")
                   (file-exists? "/run/current-system/profile/bin/opencode-v2")
                   (file-exists? "/run/current-system/profile/bin/opencode2"))
             marionette))

          (test-assert "opencode-v1 reports 1.19.4"
            (marionette-eval
             '(begin
                (use-modules (ice-9 popen)
                             (ice-9 textual-ports))
                (let* ((port (open-input-pipe
                              "/run/current-system/profile/bin/opencode-v1 --version"))
                       (output (get-string-all port)))
                  (close-pipe port)
                  (string-contains output "1.19.4")))
             marionette))

          (test-assert "opencode-v2 reports 2.1.4"
            (marionette-eval
             '(begin
                (use-modules (ice-9 popen)
                             (ice-9 textual-ports))
                (let* ((port (open-input-pipe
                              "/run/current-system/profile/bin/opencode-v2 --version"))
                       (output (get-string-all port)))
                  (close-pipe port)
                  (string-contains output "2.1.4")))
             marionette))

          (test-assert "opencode-v1 --help runs"
            (marionette-eval
             '(zero? (system* "/run/current-system/profile/bin/opencode-v1"
                              "--help"))
             marionette))

          (test-assert "opencode-v2 --help runs"
            (marionette-eval
             '(zero? (system* "/run/current-system/profile/bin/opencode-v2"
                              "--help"))
             marionette))

          (test-end "under-sea-opencode"))))
  (system-test
   (name "under-sea-opencode")
   (description "Install both OpenCode variants in one system profile and
verify that the launchers coexist, report their versions and run --help.")
   (value (gexp->derivation "under-sea-opencode" test))))

(define %test-under-sea-opencode (run-opencode-test))
