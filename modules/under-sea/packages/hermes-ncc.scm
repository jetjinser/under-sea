(define-module (under-sea packages hermes-ncc)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages node)
  #:use-module (under-sea packages hermes-ncc-node-lock)
  #:use-module (under-sea packages hermes-source-map))

(define %ncc-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/vercel/ncc/tar.gz/854b9aee5765ac21c72019739849324e04668457")
    (file-name "ncc-0.34.0-authored-source.tar.gz")
    (sha256
     (base16-string->bytevector
      "442337b9883caae4e01f03acae645d06ed7c0449f70eb30d974e05ef788af89d"))))

(define-public ncc-source-build-modules
  (package
    (name "ncc-source-build-modules")
    (version "0.34.0")
    (source %ncc-source)
    (build-system gnu-build-system)
    (native-inputs (list python-minimal python-pyyaml))
    (inputs (list source-map-073-for-hermes-ncc))
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
                   '#$%ncc-node-source-origins)))
              (call-with-output-file "guix-providers.json"
                (lambda (port)
                  (format port "{\"source-map@0.7.3\":\"~a\"}"
                          #$(file-append source-map-073-for-hermes-ncc "/lib/node_modules/source-map"))))
              (invoke "python3" #$(local-file "../../../scripts/assemble-agent-browser-node.py")
                      #$(local-file "../../../planning/hermes-next-ncc-node-inventory.json")
                      #$(local-file "../../../planning/hermes-next-ncc-node-archives.json")
                      "yarn.lock" (string-append #$output "/lib/node_modules")
                      "--providers" "guix-providers.json"
                      "--archive-paths" "guix-archive-paths.tsv"
                      "--lock-format" "yarn-v1" "--peer-bindings"
                      #$(local-file "../../../planning/hermes-ncc-peer-bindings.json"))))
          (replace 'install (lambda _ #t)))))
    (home-page "https://github.com/vercel/ncc")
    (synopsis "Authenticated authored build dependencies for ncc")
    (description "This package assembles ncc's original locked JavaScript
build dependencies and reviewed peer bindings without running install scripts.
Its source-map WASM is supplied by a matching source-built provider.")
    (license (list license:expat license:bsd-3 license:asl2.0))))

(define-public ncc-for-hermes-next
  (package
    (name "ncc-for-hermes-next")
    (version "0.34.0")
    (source %ncc-source)
    (build-system gnu-build-system)
    (native-inputs (list python-minimal node))
    (inputs (list ncc-source-build-modules))
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
              (invoke "python3" #$(local-file "../../../scripts/build-hermes-ncc.py")
                      #$output "--node" #$(file-append node "/bin/node")
                      "--modules" #$(file-append ncc-source-build-modules "/lib/node_modules"))))
          (replace 'install (lambda _ #t)))))
    (home-page "https://github.com/vercel/ncc")
    (synopsis "Source-built ncc with full loaders and generated resources")
    (description "This package builds ncc's original CLI, compiler API,
loaders, declarations, V8 caches, licenses and all emitted resources from source.
It retains the authored build pipeline and uses source-built mappings WASM.")
    (license license:expat)))
