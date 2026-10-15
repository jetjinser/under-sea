;;; camofox-browser (jo-inc): REST server wrapping Camoufox for Hermes.
(define-module (under-sea packages camofox-browser)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (under-sea gexp)
  #:use-module (guix utils)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system trivial)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages node)
  #:use-module (gnu packages playwright)
  #:use-module (gnu packages python)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages elf)
  #:use-module (under-sea packages camofox-node-lock)
  #:use-module (under-sea packages camofox-node-providers)
  #:use-module (under-sea packages hermes)
  #:use-module (under-sea packages hermes-camoufox))

(define-public camofox-browser-for-hermes
  (package
    (name "camofox-browser-for-hermes")
    (version "1.18.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://codeload.github.com/jo-inc/camofox-browser/tar.gz/refs/tags/v"
             version))
       (file-name (string-append name "-" version ".tar.gz"))
       (sha256
        (base16-string->bytevector
         "c511b0d80b0ed088caec171658198dd99aef6e889b07d101b23913a58bb33f5d"))))
    (build-system gnu-build-system)
    (native-inputs (list node python-minimal tar patchelf))
    (inputs (list bash-minimal node-playwright-core
                  node-better-sqlite3-for-hermes
                  impit-linux-x64-gnu-for-hermes
                  camoufox-browser-for-hermes))
    (arguments
     (list
      #:substitutable? #f
      #:modules '((guix build gnu-build-system) (guix build utils)
                  (ice-9 match) (srfi srfi-13))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'check)
          (replace 'build
            (lambda* (#:key inputs #:allow-other-keys)
              ;; Materialize the locked npm archives and replace native
              ;; payloads with source-built/prebuilt providers.
              (call-with-output-file "guix-archive-paths.tsv"
                (lambda (port)
                  (for-each
                   (match-lambda
                     ((path version source)
                      (format port "~a\t~a~%" path source)))
                   '#$%camofox-node-sources)))
              (call-with-output-file "guix-providers.json"
                (lambda (port)
                  (format port "{\"node_modules/playwright-core\":~s,\"node_modules/better-sqlite3\":~s,\"node_modules/impit-linux-x64-gnu\":~s}~%"
                          (string-append (assoc-ref inputs "node-playwright-core")
                                         "/lib/node_modules/playwright-core")
                          (string-append (assoc-ref inputs "node-better-sqlite3-for-hermes")
                                         "/lib/node_modules/better-sqlite3")
                          (string-append (assoc-ref inputs "impit-linux-x64-gnu-for-hermes")
                                         "/lib/node_modules/impit-linux-x64-gnu"))))
              (invoke "python3"
                      #$(under-sea-script "assemble-pi-node.py")
                      #$(under-sea-repo-file "planning/camofox-node-inventory.json")
                      (getcwd)
                      "--archive-paths" "guix-archive-paths.tsv"
                      "--providers" "guix-providers.json")))
          (replace 'install
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((prefix (string-append #$output "/lib/camofox-browser"))
                    (bin (string-append #$output "/bin")))
                (mkdir-p prefix)
                (copy-recursively "node_modules"
                                  (string-append prefix "/node_modules"))
                (for-each
                 (lambda (f)
                   (when (file-exists? f)
                     (copy-recursively f (string-append prefix "/" f))))
                 '("server.js" "package.json" "lib" "bin" "plugins" "workers" "mcp"))
                (mkdir-p bin)
                (let ((wrapper (string-append bin "/camofox-browser")))
                  (call-with-output-file wrapper
                    (lambda (port)
                      (display
                       (string-append
                        "#!" #$(file-append bash-minimal "/bin/bash") "\n"
                        "export CAMOFOX_URL=${CAMOFOX_URL:-http://127.0.0.1:9377}\n"
                        ;; camoufox-js reads properties.json beside the binary and
                        ;; the Firefox bundle needs the GTK3 stack at runtime.
                        "export CAMOUFOX_EXECUTABLE_PATH="
                        #$(file-append camoufox-browser-for-hermes "/lib/camoufox/camoufox") "\n"
                        "export LD_LIBRARY_PATH="
                        (string-join (list #$@camoufox-gtk-libs) ":")
                        "${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}\n"
                        "cd " prefix "\n"
                        "exec " #$(file-append node "/bin/node") " server.js \"$@\"\n")
                       port)))
                  (chmod wrapper #o555))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/jo-inc/camofox-browser")
    (synopsis "camofox-browser REST server for the Hermes camofox backend")
    (description "This package assembles camofox-browser's locked npm closure
from source (replacing playwright-core with the channel package and building
better-sqlite3/impit natively) and exposes a wrapper that serves its REST API
for Hermes's @code{browser.cloud_provider: camofox} mode.")
    (license license:expat)))

;; Re-expose the Hermes CLI with CAMOFOX_URL set (and camofox-browser on PATH)
;; so its browser tools route through the Camoufox REST server.
(define-public hermes-camofox-runtime
  (package
    (name "hermes-camofox-runtime")
    (version (package-version hermes-agent-integrations))
    (source #f)
    (build-system trivial-build-system)
    (inputs (list bash-minimal hermes-agent-integrations camofox-browser-for-hermes))
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let ((out (assoc-ref %outputs "out"))
                (hermes (assoc-ref %build-inputs "hermes-agent-integrations"))
                (cf (assoc-ref %build-inputs "camofox-browser-for-hermes"))
                (bash (assoc-ref %build-inputs "bash-minimal")))
            (mkdir-p (string-append out "/bin"))
            (for-each
             (lambda (name)
               (let ((wrapper (string-append out "/bin/" name)))
                 (call-with-output-file wrapper
                   (lambda (port)
                     (display
                      (string-append
                       "#!" bash "/bin/bash\n"
                       "export CAMOFOX_URL=${CAMOFOX_URL:-http://127.0.0.1:9377}\n"
                       "export PATH=" cf "/bin:${PATH}\n"
                       "exec " hermes "/bin/" name " \"$@\"\n")
                      port)))
                 (chmod wrapper #o555)))
             '("hermes" "hermes-agent" "hermes-acp"))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/jo-inc/camofox-browser")
    (synopsis "Hermes runtime wired to the camofox REST server")
    (description "This package re-exposes the Hermes CLI with @code{CAMOFOX_URL}
set and @command{camofox-browser} on PATH, activating Hermes's camofox browser
backend (Camoufox via the jo-inc REST server).")
    (license license:expat)))
