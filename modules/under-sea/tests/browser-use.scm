;;; Guest VM CDP smoke for the Hermes browser-use runtime and source Chromium.
(define-module (under-sea tests browser-use)
  #:use-module (gnu packages chromium)
  #:use-module (gnu tests)
  #:use-module (gnu system)
  #:use-module (gnu system vm)
  #:use-module (guix gexp)
  #:use-module (under-sea packages hermes-browser-use)
  #:export (%test-under-sea-browser-use))

(define (run-browser-use-test)
  (define os
    (marionette-operating-system
     (operating-system
       (inherit (simple-operating-system))
       (packages (cons* hermes-agent-browser-use
                        hermes-browser-backend-browser-use
                        ungoogled-chromium
                        %base-packages)))
     #:imported-modules '((gnu services herd)
                          (guix combinators))))
  (define vm
    (virtual-machine (operating-system os)
                     (memory-size 4096)))
  (define smoke-script (local-file "../../../scripts/browser-use-cdp-smoke.py"))
  (define test
    (with-imported-modules '((gnu build marionette)
                             (guix build utils))
      #~(begin
          (use-modules (gnu build marionette)
                       (guix build utils)
                       (srfi srfi-64))

          (define marionette (make-marionette (list #$vm)))
          (test-runner-current (system-test-runner #$output))
          (test-begin "under-sea-browser-use")

          (test-assert "browser-use backend and source Chromium are installed"
            (marionette-eval
             '(and (file-exists? #$(file-append hermes-agent-browser-use
                                                "/bin/hermes-python"))
                   (file-exists? #$(file-append ungoogled-chromium
                                                "/bin/chromium"))
                   (file-exists? #$(file-append
                                    hermes-browser-backend-browser-use
                                    "/share/hermes-browser/browser-use.json"))
                   (file-exists? #$(file-append
                                    hermes-browser-backend-browser-use
                                    "/bin/hermes-browser-use")))
             marionette))

          (test-equal "browser-use CLI help runs without network services"
            0
            (marionette-eval
             '(system* #$(file-append hermes-browser-backend-browser-use
                                      "/bin/hermes-browser-use")
                       "--help")
             marionette))

          (test-equal "browser-use runtime drives a local page over CDP"
            0
            (marionette-eval
             '(begin
                (copy-file #$smoke-script "/tmp/browser-use-cdp-smoke.py")
                (setenv "CHROME_PATH"
                        #$(file-append ungoogled-chromium "/bin/chromium"))
                (setenv "TMPDIR" "/tmp")
                (system* #$(file-append hermes-agent-browser-use
                                       "/bin/hermes-python")
                         "/tmp/browser-use-cdp-smoke.py"))
             marionette))

          (test-end "under-sea-browser-use"))))
  (system-test
   (name "under-sea-browser-use")
   (description "Boot browser-use and source Chromium, then verify CDP locally.")
   (value (gexp->derivation "under-sea-browser-use" test))))

(define %test-under-sea-browser-use (run-browser-use-test))
