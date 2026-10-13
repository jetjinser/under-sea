(define-module (under-sea packages hermes-satori)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages node)
  #:use-module (under-sea packages hermes-satori-tools)
  #:use-module (under-sea packages hermes-satori-node-lock)
  #:use-module (under-sea packages hermes-source-map)
  #:use-module (under-sea packages hermes-yoga)
  #:use-module ((guix licenses) #:prefix license:))

(define %satori-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/vercel/satori/tar.gz/b54f510807b7f5b8503e02509a83dc3ede06d317")
    (file-name "satori-0.15.2-source.tar.gz")
    (sha256
     (base16-string->bytevector
      "99f9d4fd500da3d33f5ee6d0e767a1e38ecdfe0f9840d0b82fd9082b439db6fb"))))

(define-public satori-source-build-modules
  (package
    (name "satori-source-build-modules")
    (version "0.15.2")
    (source %satori-source)
    (build-system gnu-build-system)
    (native-inputs (list python-minimal python-pyyaml))
    (inputs (list esbuild-for-hermes-satori yoga-wasm-web-for-hermes-browser
                  source-map-074-for-hermes-browser source-map-08-for-hermes-browser))
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
                   '#$%satori-node-source-origins)))
              (call-with-output-file "guix-source-providers.json"
                (lambda (port)
                  (format port "{\"@esbuild/linux-x64@0.18.10\":\"~a\",\"yoga-wasm-web@0.3.3\":\"~a\",\"source-map@0.7.4\":\"~a\",\"source-map@0.8.0-beta.0\":\"~a\"}"
                          #$(file-append esbuild-for-hermes-satori "/lib/node_modules/@esbuild/linux-x64")
                          #$(file-append yoga-wasm-web-for-hermes-browser "/lib/node_modules/yoga-wasm-web")
                          #$(file-append source-map-074-for-hermes-browser "/lib/node_modules/source-map")
                          #$(file-append source-map-08-for-hermes-browser "/lib/node_modules/source-map"))))
              (invoke "python3" #$(local-file "../../../scripts/assemble-agent-browser-node.py")
                      #$(local-file "../../../planning/hermes-satori-node-inventory.json")
                      #$(local-file "../../../planning/hermes-satori-node-archives.json")
                      "pnpm-lock.yaml" (string-append #$output "/lib/node_modules")
                      "--providers" "guix-source-providers.json"
                      "--archive-paths" "guix-archive-paths.tsv"
                      "--build-source-removals"
                      #$(local-file "../../../planning/hermes-satori-build-source-removals.json"))))
          (replace 'install (lambda _ #t)))))
    (home-page "https://github.com/vercel/satori")
    (synopsis "Exact source inputs for Satori's production and declaration builds")
    (description "This package assembles Satori's authored peer-aware dependency
graph without executing install scripts.  Native and WASM implementations use
source-built providers.  React Native is a build-only declaration peer whose
audited Hermes SDK binaries are excluded; it is not a React Native runtime.")
    (license (list license:mpl2.0 license:expat license:bsd-3 license:asl2.0))))

(define-public satori-for-hermes-browser
  (package
    (name "satori-for-hermes-browser")
    (version "0.15.2")
    (source %satori-source)
    (build-system gnu-build-system)
    (native-inputs (list python-minimal node esbuild-for-hermes-satori))
    (inputs (list satori-source-build-modules))
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
              (invoke "python3" #$(local-file "../../../scripts/build-hermes-satori.py")
                      #$output "--node" #$(file-append node "/bin/node")
                      "--esbuild" #$(file-append esbuild-for-hermes-satori "/bin/esbuild")
                      "--modules" #$(file-append satori-source-build-modules "/lib/node_modules"))))
          (replace 'install (lambda _ #t)))))
    (home-page "https://github.com/vercel/satori")
    (synopsis "Source-built Satori with default and WASM ESM/CJS APIs")
    (description "This package compiles Satori's original TypeScript source,
default and externally initialized WASM variants, and declarations using its
authored tsup configuration and exact source-build dependency graph.  Its Yoga
backend is built from source.  The source-build runtime graph remains separate
from Next's published-runtime dependency graph, which requires final integration.")
    (license license:mpl2.0)))
