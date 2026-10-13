;;; Hermes Electron desktop shell over the source-built dashboard export.
(define-module (under-sea packages hermes-electron)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages bash)
  #:use-module ((nongnu packages electron) #:select (electron))
  #:use-module (under-sea packages hermes-agent-browser-dashboard))

(define-public hermes-electron-desktop
  (package
    (name "hermes-electron-desktop")
    (version (package-version electron))
    (source #f)
    (build-system gnu-build-system)
    (inputs (list bash-minimal electron agent-browser-dashboard))
    (arguments
     (list
      #:substitutable? #f
      #:modules '((guix build gnu-build-system) (guix build utils))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'unpack)
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          (replace 'build
            (lambda* (#:key inputs #:allow-other-keys)
              (mkdir-p "app")
              (copy-recursively
               (string-append (assoc-ref inputs "agent-browser-dashboard")
                              "/share/agent-browser-dashboard")
               "app/dashboard")
              (copy-file #$(local-file "../../scripts/hermes-electron-main.js")
                         "app/main.js")
              (call-with-output-file "app/package.json"
                (lambda (port)
                  (format port "{\"name\":\"hermes-desktop\",\"version\":~s,\"main\":\"main.js\"}~%"
                          #$version)))))
          (replace 'install
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((share (string-append #$output "/share/hermes-electron"))
                    (bin (string-append #$output "/bin")))
                (mkdir-p share)
                (copy-recursively "app" share)
                (mkdir-p bin)
                (let ((wrapper (string-append bin "/hermes-desktop")))
                  (call-with-output-file wrapper
                    (lambda (port)
                      ;; Headless/CI displays have no usable GPU or user
                      ;; namespaces; keep Electron on software rendering.
                      (format port "#!~a/bin/bash~%exec ~a/bin/electron --no-sandbox --disable-gpu --disable-dev-shm-usage ~s \"$@\"~%"
                              (assoc-ref inputs "bash-minimal")
                              (assoc-ref inputs "electron")
                              (string-append share "/main.js"))))
                  (chmod wrapper #o555))))))))
    (supported-systems '("x86_64-linux"))
    (properties '((max-silent-time . 7200)))
    (home-page "https://github.com/NousResearch/hermes-agent")
    (synopsis "Hermes desktop shell (Electron) over the source-built dashboard")
    (description "This package wraps the source-built Hermes dashboard static
export in an Electron desktop shell: a loopback HTTP server serves the export
and a BrowserWindow displays it.  Electron is taken from the nongnu channel as
a prebuilt binary (its upstream is only distributed prebuilt); this is recorded
as a prebuilt/source-unavailable exception.")
    (license license:asl2.0)))
