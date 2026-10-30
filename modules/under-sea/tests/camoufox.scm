;;; Guest VM smoke for the Hermes Camoufox controller and paired browser.
(define-module (under-sea tests camoufox)
  #:use-module (gnu tests)
  #:use-module (gnu system)
  #:use-module (gnu system vm)
  #:use-module (guix gexp)
  #:use-module (under-sea packages hermes-camoufox)
  #:use-module (under-sea packages qemu-cpu)
  #:export (%test-under-sea-camoufox))

(define (run-camoufox-test)
  (define os
    (marionette-operating-system
     (operating-system
       (inherit (simple-operating-system))
       (packages (cons* hermes-agent-camoufox
                        camoufox-browser-for-hermes
                        hermes-browser-backend-camoufox
                        %base-packages)))
     #:imported-modules '((gnu services herd)
                          (guix combinators))))
  (define vm
    (virtual-machine (operating-system os)
                     (memory-size 4096)
                     ;; NumPy's source-built wheel targets x86_64-v2; the
                     ;; default qemu64 CPU does not expose its SSE features.
                     (qemu qemu-sse42)))
  (define smoke-script (local-file "../../../scripts/camoufox-smoke.py"))
  (define test
    (with-imported-modules '((gnu build marionette)
                             (guix build utils))
      #~(begin
          (use-modules (gnu build marionette)
                       (guix build utils)
                       (ice-9 rdelim)
                       (srfi srfi-13)
                       (srfi srfi-64))

          (define marionette (make-marionette (list #$vm)))
          (test-runner-current (system-test-runner #$output))
          (test-begin "under-sea-camoufox")

          (test-assert "controller, paired Firefox and backend are installed"
            (marionette-eval
             '(and (file-exists? #$(file-append hermes-agent-camoufox
                                                "/bin/hermes-python"))
                   (file-exists? #$(file-append camoufox-browser-for-hermes
                                                "/bin/camoufox"))
                   (file-exists? #$(file-append
                                    hermes-browser-backend-camoufox
                                    "/bin/hermes-camoufox"))
                   (file-exists? #$(file-append
                                    camoufox-browser-for-hermes
                                    "/lib/camoufox/version.json")))
             marionette))

          (test-equal "controller imports and backend CLI help work offline"
            0
            (marionette-eval
             '(begin
                (let ((status
                       (system* "timeout" "30"
                                #$(file-append hermes-agent-camoufox
                                               "/bin/hermes-python")
                                "-c" "import camoufox, maxminddb")))
                  (and (zero? status)
                       (system* "timeout" "30"
                                #$(file-append hermes-browser-backend-camoufox
                                               "/bin/hermes-camoufox")
                                "--help"))))
             marionette))

          (test-assert "controller launches configured Firefox and opens a local page"
            (marionette-eval
             '(begin
                (use-modules (ice-9 rdelim))
                (let* ((cache-root "/tmp/camoufox-cache-root")
                       (install (string-append cache-root "/camoufox"))
                       (version-dir
                        (string-append install
                                       "/browsers/official/156.0.1-beta.36"))
                       (model-source
                        #$(file-append hermes-agent-camoufox
                                       "/lib/python3.12/site-packages/fpgen/data"))
                       (model-target "/tmp/camoufox-fpgen"))
                  (setenv "XDG_CACHE_HOME" cache-root)
                  (unless (zero? (system* "mkdir" "-p"
                                          (string-append install
                                                         "/browsers/official")))
                    (error "could not create Camoufox browser cache"))
                  (unless (zero? (system* "ln" "-s"
                                          #$(file-append
                                             camoufox-browser-for-hermes
                                             "/lib/camoufox")
                                          version-dir))
                    (error "could not expose the Guix-pinned browser in cache"))
                  (call-with-output-file (string-append install "/config.json")
                    (lambda (port)
                      (display
                       "{\"active_version\":\"browsers/official/156.0.1-beta.36\"}"
                       port)))
                  (unless (zero? (system* "mkdir" "-p" model-target))
                    (error "could not create fpgen model directory"))
                  (unless (zero? (system* "cp" "-r"
                                          (string-append model-source "/.")
                                          model-target))
                    (error "could not stage fpgen model data"))
                  (for-each
                   (lambda (name)
                     (let ((path (string-append model-target "/" name)))
                       (chmod path #o644)
                       (utime path 4102444800 4102444800)))
                   '("fingerprint-network.json.zst" "values.dat.zst"
                     "values.json.zst" ".pinned-model")))
                (setenv "CAMOUFOX_EXECUTABLE_PATH"
                        #$(file-append camoufox-browser-for-hermes
                                       "/lib/camoufox/camoufox"))
                (setenv "CAMOUFOX_FPGEN_DATA" "/tmp/camoufox-fpgen")
                ;; Use the runtime search path from the browser's own wrapper;
                ;; the backend wrapper exports the same GTK and GCC libraries.
                (setenv
                 "LD_LIBRARY_PATH"
                 (call-with-input-file
                     #$(file-append camoufox-browser-for-hermes
                                    "/bin/camoufox")
                   (lambda (port)
                     (read-line port)
                     (let ((line (read-line port))
                           (prefix "export LD_LIBRARY_PATH="))
                       (unless (string-prefix? prefix line)
                         (error "browser wrapper has no runtime library path"))
                       (substring line (string-length prefix))))))
                (let* ((log "/tmp/camoufox-smoke.log")
                       (command
                        (string-append "timeout 20 "
                                       #$(file-append hermes-agent-camoufox
                                                      "/bin/hermes-python")
                                       " " #$smoke-script
                                       " >" log " 2>&1"))
                       (status (system* "sh" "-c" command)))
                  (unless (zero? status)
                    (system* "cat" log))
                  (and (zero? status)
                       (file-exists? "/tmp/camoufox-smoke.png")
                       (> (stat:size (stat "/tmp/camoufox-smoke.png")) 0))))
             marionette))

          (test-end "under-sea-camoufox"))))
  (system-test
   (name "under-sea-camoufox")
   (description "Boot Camoufox and verify controller-to-browser launch in a guest VM.")
   (value (gexp->derivation "under-sea-camoufox" test))))

(define %test-under-sea-camoufox (run-camoufox-test))
