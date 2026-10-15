;;; Next's authored dependency graph with matching source-built providers.
(define-module (under-sea packages hermes-next-node)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (under-sea gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (under-sea packages next-native-lock)
  #:use-module ((under-sea packages next-1608-native-lock) #:prefix bootstrap:)
  #:use-module (under-sea packages hermes-next-node-lock)
  #:use-module ((under-sea packages hermes-next-1608-node-lock) #:prefix bootstrap:)
  #:use-module (under-sea packages hermes-next-1608-task-node-lock)
  #:use-module (under-sea packages hermes-next-build-tools)
  #:use-module (under-sea packages hermes-next-image)
  #:use-module (under-sea packages hermes-next-swc-core)
  #:use-module (under-sea packages hermes-next-rspack)
  #:use-module (under-sea packages hermes-ncc)
  #:use-module (under-sea packages hermes-source-map)
  #:use-module (under-sea packages hermes-yoga)
  #:use-module (under-sea packages hermes-satori)
  #:use-module (under-sea packages hermes-vercel-og)
  #:use-module (under-sea packages hermes-browser-wasm))

(define %next-provider-layout
  (list
   (list "@esbuild/linux-x64@0.25.9"
         (file-append esbuild-for-hermes-next "/lib/node_modules/@esbuild/linux-x64"))
   (list "@swc/core-linux-x64-gnu@1.11.24"
         (file-append swc-core-binding-for-hermes-next "/lib/node_modules/@swc/core-linux-x64-gnu"))
   (list "@rspack/binding-linux-x64-gnu@1.6.7"
         (file-append rspack-binding-for-hermes-next "/lib/node_modules/@rspack/binding-linux-x64-gnu"))
   (list "@vercel/ncc@0.34.0"
         (file-append ncc-for-hermes-next "/lib/node_modules/@vercel/ncc"))
   (list "source-map@0.7.4"
         (file-append source-map-074-for-hermes-browser "/lib/node_modules/source-map"))
   (list "source-map@0.8.0-beta.0"
         (file-append source-map-08-for-hermes-browser "/lib/node_modules/source-map"))
   (list "sharp@0.34.4"
         (file-append sharp-binding-for-hermes-next "/lib/node_modules/sharp"))
   (list "ci-info@https://codeload.github.com/watson/ci-info/tar.gz/f43f6a1cefff47fb361c88cf4b943fdbcaafe540"
         (file-append ci-info-for-hermes-next "/lib/node_modules/ci-info"))))

(define (next-build-modules name version source origins providers inventory archives)
  (package
    (name name)
    (version version)
    (source source)
    (build-system gnu-build-system)
    (native-inputs (list python-minimal python-pyyaml))
    (arguments
     (list
      #:substitutable? #f
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          (replace 'build
            (lambda _
              (call-with-output-file "guix-archive-paths.tsv"
                (lambda (port)
                  (for-each
                   (lambda (entry) (format port "~a\t~a~%" (car entry) (cadr entry)))
                   '#$origins)))
              (call-with-output-file "guix-providers.json"
                (lambda (port)
                  (display "{" port)
                  (let ((first? #t))
                    (for-each
                     (lambda (entry)
                       (unless first? (display "," port))
                       (set! first? #f)
                       (format port "~s:~s" (car entry) (cadr entry)))
                     '#$providers))
                  (display "}" port)))
              (invoke "python3" #$(under-sea-script "assemble-agent-browser-node.py")
                      #$inventory
                      #$archives
                      "pnpm-lock.yaml" (string-append #$output "/lib/node_modules")
                      "--providers" "guix-providers.json"
                      "--archive-paths" "guix-archive-paths.tsv"
                      "--workspace-source" "."
                      "--compose-provider" "sharp@0.34.4"
                      "--optional-replacements"
                      #$(under-sea-repo-file "planning/hermes-next-sharp-optional-replacements.json")
                      "--build-source-removals"
                      #$(under-sea-repo-file "planning/hermes-next-build-source-removals.json"))))
          (replace 'install (lambda _ #t)))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/vercel/next.js")
    (synopsis "Locked source dependencies for building the complete Next framework")
    (description "This package assembles Next's authored registry and workspace
build graph without install scripts.  Matching SWC, Rspack, esbuild, ncc,
source-map WASM and Sharp implementations are supplied by source-built packages.
It is a build dependency layout, not a built Next framework or dashboard.")
    (license (list license:expat license:bsd-3 license:asl2.0))))

(define-public next-source-build-modules
  (next-build-modules "next-source-build-modules"
                      %next-native-version %next-native-source
                      %next-node-source-origins %next-provider-layout
                      (under-sea-repo-file "planning/hermes-next-build-node-inventory.json")
                      (under-sea-repo-file "planning/hermes-next-build-node-archives.json")))

(define-public next-1608-source-build-modules
  (next-build-modules
   "next-1608-source-build-modules"
   bootstrap:%next-native-version bootstrap:%next-native-source
   bootstrap:%next-node-source-origins
   (cons (list "@rspack/binding-linux-x64-gnu@1.6.0"
               (file-append rspack-binding-for-hermes-next-1608
                            "/lib/node_modules/@rspack/binding-linux-x64-gnu"))
         (filter (lambda (entry)
                   (not (string=? (car entry) "@rspack/binding-linux-x64-gnu@1.6.7")))
                 %next-provider-layout))
   (under-sea-repo-file "planning/hermes-next-1608-build-node-inventory.json")
   (under-sea-repo-file "planning/hermes-next-1608-build-node-archives.json")))

(define-public next-1608-task-source-build-modules
  (next-build-modules
   "next-1608-task-source-build-modules"
   bootstrap:%next-native-version bootstrap:%next-native-source
   %next-task-node-source-origins
   (append
    (list
     (list "@rspack/binding-linux-x64-gnu@1.6.0"
           (file-append rspack-binding-for-hermes-next-1608
                        "/lib/node_modules/@rspack/binding-linux-x64-gnu"))
     (list "@vercel/og@0.7.2"
           (file-append vercel-og-for-hermes-browser "/lib/node_modules/@vercel/og"))
     (list "satori@0.15.2"
           (file-append satori-for-hermes-browser "/lib/node_modules/satori"))
     (list "yoga-wasm-web@0.3.3"
           (file-append yoga-wasm-web-for-hermes-browser "/lib/node_modules/yoga-wasm-web"))
     (list "@resvg/resvg-wasm@2.4.0"
           (file-append resvg-wasm-for-hermes-browser "/lib/node_modules/@resvg/resvg-wasm")))
    (filter (lambda (entry)
              (not (string=? (car entry) "@rspack/binding-linux-x64-gnu@1.6.7")))
            %next-provider-layout))
   (under-sea-repo-file "planning/hermes-next-1608-task-node-inventory.json")
   (under-sea-repo-file "planning/hermes-next-1608-task-node-archives.json")))
