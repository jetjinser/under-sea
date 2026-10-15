;;; agent-browser dashboard static export built with the source-built Next framework.
(define-module (under-sea packages hermes-agent-browser-dashboard)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (under-sea gexp)
  #:use-module (guix utils)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages node)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages bash)
  #:use-module (under-sea packages agent-browser-lock)
  #:use-module (under-sea packages hermes-agent-browser-node-lock)
  #:use-module (under-sea packages hermes-next-framework)
  #:use-module (under-sea packages hermes-next-native)
  #:use-module (under-sea packages hermes-node-native))

(define %agent-browser-dashboard-provider-layout
  (list
   (list "next@16.1.1"
         (file-append next-framework-for-hermes "/lib/node_modules/next"))
   (list "@next/swc-linux-x64-gnu@16.1.1"
         (file-append next-swc-for-hermes-browser
                      "/lib/node_modules/@next/swc-linux-x64-gnu"))
   (list "@tailwindcss/oxide-linux-x64-gnu@4.2.2"
         (file-append tailwind-oxide-for-hermes-422
                      "/lib/node_modules/@tailwindcss/oxide-linux-x64-gnu"))
   (list "lightningcss-linux-x64-gnu@1.32.0"
         (file-append lightningcss-for-hermes
                      "/lib/node_modules/lightningcss-linux-x64-gnu"))))

(define %agent-browser-dashboard-geist-font
  ;; The dashboard's layout uses Geist; vendor the variable font so the offline
  ;; build does not fetch from Google Fonts.
  (origin
    (method url-fetch)
    (uri "https://registry.npmjs.org/geist/-/geist-1.7.2.tgz")
    (file-name "geist-1.7.2.tgz")
    (sha256
     (base16-string->bytevector
      "88cbfaca51646078f3172802643691bb8fe2df15ca4c455b1b101e49b7d469a6"))))

(define-public agent-browser-dashboard
  (package
    (name "agent-browser-dashboard")
    (version %agent-browser-version)
    (source %agent-browser-source)
    (build-system gnu-build-system)
    (native-inputs (list node python-minimal python-pyyaml))
    (inputs (list next-framework-for-hermes
                  next-swc-for-hermes-browser
                  lightningcss-for-hermes
                  tailwind-oxide-for-hermes-422))
    (arguments
     (list
      #:substitutable? #f
      #:modules '((guix build gnu-build-system) (guix build utils) (ice-9 match))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          (add-after 'unpack 'vendor-geist-font
            (lambda _
              ;; next/font/google would fetch Geist at build time; vendor the
              ;; variable font and switch the layout to next/font/local.
              (let ((destination
                     (string-append (getcwd)
                                    "/packages/dashboard/src/app/geist")))
                (mkdir-p destination)
                (invoke "tar" "xf" #$%agent-browser-dashboard-geist-font
                        "-C" destination "--strip-components=4"
                        "package/dist/fonts/geist-sans/Geist-Variable.ttf")
                (invoke "python3"
                        #$(under-sea-repo-file "scripts/patch-agent-browser-dashboard-font.py")
                        "."))))
          (add-after 'vendor-geist-font 'provide-error-pages
            (lambda _
              ;; Next's built-in /_not-found and /_global-error prerender reads
              ;; request APIs (`pathname`/`params`) outside a request store
              ;; during `output: export`; provide app-level pages that do not.
              (let ((app (string-append (getcwd) "/packages/dashboard/src/app")))
                (call-with-output-file (string-append app "/not-found.tsx")
                  (lambda (port)
                    (display
                     (string-append
                      "import Link from \"next/link\";\n\n"
                      "export default function NotFound() {\n"
                      "  return (\n"
                      "    <div className=\"flex min-h-screen flex-col items-center justify-center gap-3 p-10\">\n"
                      "      <h1 className=\"text-2xl font-semibold\">404 - Not Found</h1>\n"
                      "      <p className=\"text-muted-foreground\">This page could not be found.</p>\n"
                      "      <Link className=\"underline\" href=\"/\">Go to dashboard</Link>\n"
                      "    </div>\n"
                      "  );\n"
                      "}\n")
                     port)))
                ;; Replace Next's built-in global-error, whose prerender uses the
                ;; client React context and fails under `output: export`.
                (call-with-output-file (string-append app "/global-error.tsx")
                  (lambda (port)
                    (display
                     (string-append
                      "\"use client\";\n\n"
                      "export default function GlobalError({\n"
                      "  reset,\n"
                      "}: {\n"
                      "  error: Error & { digest?: string };\n"
                      "  reset: () => void;\n"
                      "}) {\n"
                      "  return (\n"
                      "    <html lang=\"en\">\n"
                      "      <body>\n"
                      "        <div className=\"flex min-h-screen flex-col items-center justify-center gap-3 p-10\">\n"
                      "          <h2 className=\"text-xl font-semibold\">Something went wrong</h2>\n"
                      "          <button className=\"underline\" onClick={() => reset()}>\n"
                      "            Try again\n"
                      "          </button>\n"
                      "        </div>\n"
                      "      </body>\n"
                      "    </html>\n"
                      "  );\n"
                      "}\n")
                     port))))))
          (replace 'build
            (lambda _
              (setenv "NODE_ENV" "production")
              (setenv "NEXT_TELEMETRY_DISABLED" "1")
              (setenv "CI" "1")
              ;; Assemble the exact peer-aware dependency graph in-tree (rather
              ;; than linking it from the store) so the build tool accepts the
              ;; symlink layout while staying fully offline.
              (call-with-output-file "guix-archive-paths.tsv"
                (lambda (port)
                  (for-each
                   (match-lambda
                     ((identity source)
                      (format port "~a\t~a~%" identity source)))
                   '#$%agent-browser-dashboard-node-origins)))
              (call-with-output-file "guix-providers.json"
                (lambda (port)
                  (display "{" port)
                  (let ((first? #t))
                    (for-each
                     (lambda (entry)
                       (unless first? (display "," port))
                       (set! first? #f)
                       (format port "~s:~s" (car entry) (cadr entry)))
                     '#$%agent-browser-dashboard-provider-layout))
                  (display "}" port)))
              (invoke "python3"
                      #$(under-sea-script "assemble-agent-browser-node.py")
                      #$(under-sea-repo-file "planning/hermes-agent-browser-node-inventory.json")
                      #$(under-sea-repo-file "planning/hermes-agent-browser-node-archives.json")
                      "pnpm-lock.yaml"
                      (string-append (getcwd) "/node_modules")
                      "--providers" "guix-providers.json"
                      "--archive-paths" "guix-archive-paths.tsv"
                      ;; Name each package directory after the package so the
                      ;; build tool's import rewriting sees the expected path.
                      "--package-dir-name" "basename"
                      ;; Copy the source-built providers into the in-tree graph
                      ;; so the build tool never compiles files outside the
                      ;; project directory.
                      "--compose-provider" "next@16.1.1"
                      "--compose-provider" "@next/swc-linux-x64-gnu@16.1.1"
                      "--compose-provider" "@tailwindcss/oxide-linux-x64-gnu@4.2.2"
                      "--compose-provider" "lightningcss-linux-x64-gnu@1.32.0"
                      "--build-source-removals"
                      #$(under-sea-repo-file "planning/hermes-agent-browser-build-source-removals.json"))
              ;; Expose the source-built SWC binding at the workspace root so the
              ;; build never falls back to downloading @next/swc.
              (mkdir-p "node_modules/@next")
              (for-each
               (lambda (name)
                 (let ((source (string-append "node_modules/next/node_modules/@next/"
                                              name))
                       (destination (string-append "node_modules/@next/" name)))
                   (when (and (file-exists? source)
                              (not (file-exists? destination)))
                     (symlink (canonicalize-path source) destination))))
               '("swc" "swc-linux-x64-gnu"))
              (with-directory-excursion "packages/dashboard"
                ;; Run the in-tree composed `next` so its runtime resolves
                ;; react/react-dom from this application graph (the store
                ;; framework would resolve its own peers instead).
                (invoke "node"
                        (string-append (getcwd)
                                       "/../../node_modules/next/dist/bin/next")
                        "build"))))
          (replace 'install
            (lambda _
              (unless (file-exists? "packages/dashboard/out/index.html")
                (error "Dashboard export produced no out/index.html"))
              (copy-recursively "packages/dashboard/out"
                                (string-append #$output
                                               "/share/agent-browser-dashboard")))))))
    (supported-systems '("x86_64-linux"))
    (properties '((max-silent-time . 7200)))
    (home-page "https://github.com/vercel-labs/agent-browser")
    (synopsis "Source-built agent-browser dashboard static export")
    (description "This package builds the agent-browser dashboard's Next.js
application into a static export using the source-built Next framework and an
in-tree, offline, hash-pinned module graph.  It does not use a published dist.")
    (license license:asl2.0)))
