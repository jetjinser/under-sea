;;; Browser / computer-use backends for the Hermes agent.
;;;
;;; Integration note (audited against hermes-agent-integrations): Hermes does
;;; NOT consume the share/hermes-browser/*.json files below.  Its real browser
;;; selection is:
;;;   - local (default): agent-browser drives a Chromium found via
;;;     AGENT_BROWSER_EXECUTABLE_PATH, then system Chrome/Chromium, then the
;;;     Playwright cache (tools/browser_tool_install.py);
;;;   - Camofox: browser.cloud_provider = camofox + CAMOFOX_URL pointing at a
;;;     jo-inc/camofox-browser REST server (tools/browser_camofox.py);
;;;   - CDP override: BROWSER_CDP_URL / browser.cdp_url, which wins over all
;;;     (tools/browser_tool_cdp.py);
;;;   - cloud providers: plugins/browser/{browserbase,browser_use,firecrawl}.
;;; The JSON descriptors are kept only as install metadata; hermes-browser-runtime
;;; wires AGENT_BROWSER_EXECUTABLE_PATH for the local mode.
(define-module (under-sea packages hermes-browser-backends)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system trivial)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages chromium)
  #:use-module (gnu packages playwright)
  #:use-module (under-sea packages agent-browser)
  #:use-module (under-sea packages hermes))

(define-public hermes-browser-backend-playwright
  (package
    (name "hermes-browser-backend-playwright")
    (version (package-version node-playwright-core))
    (source #f)
    (build-system trivial-build-system)
    (inputs (list bash-minimal node-playwright-core ungoogled-chromium))
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let ((out (assoc-ref %outputs "out"))
                (pw (assoc-ref %build-inputs "node-playwright-core"))
                (bash (assoc-ref %build-inputs "bash-minimal"))
                (browser (assoc-ref %build-inputs "ungoogled-chromium")))
            ;; Provide the playwright-core Node module and record the
            ;; source-built browser the backend must launch.
            (mkdir-p (string-append out "/lib/node_modules"))
            (symlink (string-append pw "/lib/node_modules/playwright-core")
                     (string-append out "/lib/node_modules/playwright-core"))
            (mkdir-p (string-append out "/share/hermes-browser"))
            (call-with-output-file
                (string-append out "/share/hermes-browser/playwright.json")
              (lambda (port)
                (format port "{\"module\":\"playwright-core\",\"browser\":~s}~%"
                        (string-append browser "/bin/chromium"))))
            (mkdir-p (string-append out "/bin"))
            (let ((wrapper (string-append out "/bin/hermes-browser-playwright")))
              (call-with-output-file wrapper
                (lambda (port)
                  (format port "#!~a/bin/bash~%exec ~a/bin/playwright-core \"$@\"~%"
                          bash pw)))
              (chmod wrapper #o555))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://playwright.dev")
    (synopsis "Playwright browser backend for the Hermes agent")
    (description "This package exposes the Guix-packaged playwright-core Node
module together with the source-built ungoogled-chromium browser, and records
the browser path for the Hermes computer-use backend to launch.  It does not
download browsers at runtime.")
    (license license:asl2.0)))

;; Wire the source-built browser into the Hermes runtime so its local browser
;; mode (agent-browser) selects ungoogled-chromium instead of looking for a
;; system/Playwright Chromium.  The wrappers preserve the inner runtime
;; environment and only add the discovery variables.
(define-public hermes-browser-runtime
  (package
    (name "hermes-browser-runtime")
    (version (package-version hermes-agent-integrations))
    (source #f)
    (build-system trivial-build-system)
    (inputs (list bash-minimal hermes-agent-integrations
                  agent-browser ungoogled-chromium))
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let ((out (assoc-ref %outputs "out"))
                (hermes (assoc-ref %build-inputs "hermes-agent-integrations"))
                (ab (assoc-ref %build-inputs "agent-browser"))
                (bash (assoc-ref %build-inputs "bash-minimal"))
                (chrome (assoc-ref %build-inputs "ungoogled-chromium")))
            (mkdir-p (string-append out "/bin"))
            (for-each
             (lambda (name)
               (let ((wrapper (string-append out "/bin/" name)))
                 (call-with-output-file wrapper
                   (lambda (port)
                     (display
                      (string-append
                       "#!" bash "/bin/bash\n"
                       "export AGENT_BROWSER_EXECUTABLE_PATH=" chrome "/bin/chromium\n"
                       "export PATH=" ab "/bin:${PATH}\n"
                       "exec " hermes "/bin/" name " \"$@\"\n")
                      port)))
                 (chmod wrapper #o555)))
             '("hermes" "hermes-agent" "hermes-acp"))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/NousResearch/hermes-agent")
    (synopsis "Hermes runtime with the source-built browser wired in")
    (description "This package re-exposes the Hermes CLI with
@code{AGENT_BROWSER_EXECUTABLE_PATH} pointing at the source-built
ungoogled-chromium and @command{agent-browser} on PATH, so Hermes's local
browser mode selects the packaged browser without runtime downloads.")
    (license license:expat)))
