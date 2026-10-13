;;; browser-use runtime for the Hermes agent (source-built PyPI closure).
(define-module (under-sea packages hermes-browser-use)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system trivial)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages chromium)
  #:use-module (under-sea packages hermes)
  #:use-module ((under-sea packages hermes-browser-lock) #:prefix browser:))

;; browser-use pins exact dependency versions, so it is built as an independent
;; source runtime rather than merged into the integrations runtime.
(define-public hermes-agent-browser-use
  (make-hermes-package "hermes-agent-browser-use"
                       browser:%hermes-python-sources
                       browser:%hermes-crate-sources #t '()
                       #:smoke? #t #:smoke-script? #f
                       #:smoke-modules '("browser_use")))

;; Expose browser-use (CDP driver) together with the source-built
;; ungoogled-chromium it must launch, following the playwright backend layout.
(define-public hermes-browser-backend-browser-use
  (package
    (name "hermes-browser-backend-browser-use")
    (version "0.13.11")
    (source #f)
    (build-system trivial-build-system)
    (inputs (list bash-minimal hermes-agent-browser-use ungoogled-chromium))
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let ((out (assoc-ref %outputs "out"))
                (rt (assoc-ref %build-inputs "hermes-agent-browser-use"))
                (bash (assoc-ref %build-inputs "bash-minimal"))
                (browser (assoc-ref %build-inputs "ungoogled-chromium")))
            (mkdir-p (string-append out "/share/hermes-browser"))
            (call-with-output-file
                (string-append out "/share/hermes-browser/browser-use.json")
              (lambda (port)
                (format port "{\"module\":\"browser_use\",\"browser\":~s,\"python\":~s,\"runtime\":~s}~%"
                        (string-append browser "/bin/chromium")
                        (string-append rt "/bin/hermes-python")
                        rt)))
            (mkdir-p (string-append out "/bin"))
            (let ((wrapper (string-append out "/bin/hermes-browser-use")))
              (call-with-output-file wrapper
                (lambda (port)
                  (format port "#!~a/bin/bash~%export CHROME_PATH=~a/bin/chromium~%export BROWSER_USE_BROWSER_PATH=~a/bin/chromium~%exec ~a/bin/hermes-python -c 'from browser_use.cli import main; main()' \"$@\"~%"
                          bash browser browser rt)))
              (chmod wrapper #o555))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/browser-use/browser-use")
    (synopsis "browser-use CDP browser backend for the Hermes agent")
    (description "This package builds the browser-use agent (and its exact
locked Python dependency closure) from source and pairs it with the
source-built ungoogled-chromium browser.  It records the browser path for the
Hermes computer-use backend and does not download browsers at runtime.")
    (license license:expat)))
