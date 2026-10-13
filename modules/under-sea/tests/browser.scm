;;; In-guest browser end-to-end test: boot a VM with the playwright backend and
;;; the source-built ungoogled-chromium, drive a real navigation from the guest
;;; and assert page.evaluate("() => document.title").

(define-module (under-sea tests browser)
  #:use-module (gnu packages chromium)
  #:use-module (gnu packages node)
  #:use-module (gnu packages xorg)
  #:use-module (gnu tests)
  #:use-module (gnu system)
  #:use-module (gnu system vm)
  #:use-module (guix gexp)
  #:use-module (under-sea packages hermes-browser-backends)
  #:export (%test-under-sea-browser))

;; A playwright-core script that launches chromium, navigates to a data: page
;; and reads document.title.
(define %browser-e2e-js
  (plain-file "browser-e2e.js"
              "\
const { chromium } = require('playwright-core');
(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.CHROME_PATH,
    headless: false,
    args: ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage'],
  });
  const page = await browser.newPage();
  await page.setContent('<title>browser-e2e</title><h1>hello</h1>');
  const title = await page.evaluate(() => document.title);
  console.log('BROWSER-E2E-TITLE:' + title);
  await browser.close();
  if (title !== 'browser-e2e') { console.error('unexpected title', title); process.exit(1); }
})().catch((e) => { console.error(e); process.exit(1); });
"))

(define (run-browser-test)
  (define os
    (marionette-operating-system
     (operating-system
       (inherit (simple-operating-system))
       (packages (cons* node xvfb-run %base-packages)))
     #:imported-modules '((gnu services herd)
                          (guix combinators))))
  (define vm
    (virtual-machine (operating-system os)
                     (memory-size 4096)))
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

          (test-runner-current (system-test-runner #$output))
          (test-begin "under-sea-browser")

          (test-assert "chromium and the playwright backend are available"
            (marionette-eval
             '(and (file-exists? #$(file-append ungoogled-chromium "/bin/chromium"))
                   (file-exists?
                    #$(file-append hermes-browser-backend-playwright
                                   "/share/hermes-browser/playwright.json")))
             marionette))

          (test-equal "playwright drives a navigation and reads document.title"
            'ok
            (marionette-eval
             '(begin
                (use-modules (ice-9 textual-ports) (guix build utils))
                (copy-file #$%browser-e2e-js "/tmp/browser-e2e.js")
                (setenv "CHROME_PATH"
                        #$(file-append ungoogled-chromium "/bin/chromium"))
                (setenv "NODE_PATH"
                        #$(file-append hermes-browser-backend-playwright
                                       "/lib/node_modules"))
                (let* ((status
                        (system* "sh" "-c"
                                 (string-append
                                  #$(file-append xvfb-run "/bin/xvfb-run")
                                  " -a "
                                  #$(file-append node "/bin/node")
                                  " /tmp/browser-e2e.js"
                                  " > /tmp/browser-e2e.out 2>&1")))
                       (out (call-with-input-file "/tmp/browser-e2e.out"
                              get-string-all)))
                  (if (and (zero? status)
                           (string-contains out "BROWSER-E2E-TITLE:browser-e2e"))
                      'ok
                      (list 'failed status out))))
             marionette))

          (test-end "under-sea-browser"))))
  (system-test
   (name "under-sea-browser")
   (description "Boot a VM with chromium + playwright-core and navigate.")
   (value (gexp->derivation "under-sea-browser" test))))

(define %test-under-sea-browser (run-browser-test))
