(define-module (under-sea packages hermes-react-compiler)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages node)
  #:use-module (under-sea packages hermes-react-compiler-node-lock)
  #:use-module (under-sea packages hermes-react-rollup-node)
  #:use-module (under-sea packages hermes-react-rollup)
  #:use-module (under-sea packages hermes-react-tools)
  #:use-module (under-sea packages hermes-source-map))

(define %react-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/facebook/react/tar.gz/52684925368a41a0c9fbfca9016cdcbb72fc9d1e")
    (file-name "react-52684925368a41a0c9fbfca9016cdcbb72fc9d1e-source.tar.gz")
    (sha256 (base16-string->bytevector
             "8ef0acfa8ce4bdcb50854c1020d334d4efb8b1807f61652ecfad7c449b024620"))))

(define-public react-compiler-for-hermes-next
  (package
    (name "react-compiler-for-hermes-next")
    (version "0.0.0-experimental-334f00b-20240725")
    (source %react-source)
    (build-system gnu-build-system)
    (native-inputs (list python-minimal python-pyyaml node))
    (inputs (list rollup-node-for-hermes-react-compiler
                  rollup-binding-for-hermes-react-compiler
                  esbuild-node-for-hermes-react-compiler
                  esbuild-for-hermes-react-compiler
                  source-map-08-for-hermes-browser))
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
                   '#$%react-compiler-node-source-origins)))
              (invoke "python3" "-c"
                      "import json,sys; json.dump(dict(zip(sys.argv[2::2],sys.argv[3::2])),open(sys.argv[1],'w'))"
                      "guix-providers.json"
                      "rollup@4.34.9"
                      #$(file-append rollup-node-for-hermes-react-compiler "/lib/node_modules/rollup")
                      "@rollup/rollup-linux-x64-gnu@4.34.9"
                      #$(file-append rollup-binding-for-hermes-react-compiler
                                     "/lib/node_modules/@rollup/rollup-linux-x64-gnu")
                      "esbuild@0.25.0"
                      #$(file-append esbuild-node-for-hermes-react-compiler "/lib/node_modules/esbuild")
                      "@esbuild/linux-x64@0.25.0"
                      #$(file-append esbuild-for-hermes-react-compiler "/lib/node_modules/@esbuild/linux-x64")
                      "source-map@0.8.0-beta.0"
                      #$(file-append source-map-08-for-hermes-browser "/lib/node_modules/source-map"))
              (invoke "python3"
                      #$(local-file "../../../scripts/assemble-agent-browser-node.py")
                      #$(local-file "../../../planning/hermes-react-compiler-config-node-inventory.json")
                      #$(local-file "../../../planning/hermes-react-compiler-config-node-archives.json")
                      "compiler/yarn.lock" "guix-compiler-node-modules"
                      "--providers" "guix-providers.json"
                      "--archive-paths" "guix-archive-paths.tsv"
                      "--lock-format" "yarn-v1" "--peer-bindings"
                      #$(local-file "../../../planning/hermes-react-compiler-config-peer-bindings.json")
                      "--yarn-peer-audit"
                      #$(local-file "../../../planning/hermes-react-compiler-config-peer-audit.json")
                      "--compose-provider" "rollup@4.34.9"
                      "--compose-provider" "esbuild@0.25.0"
                      "--compose-provider" "source-map@0.8.0-beta.0")
              (invoke "python3"
                      #$(local-file "../../../scripts/build-react-compiler-source.py")
                      "." #$(file-append node "/bin/node") "guix-compiler-node-modules"
                      (string-append #$output "/lib/node_modules/babel-plugin-react-compiler"))))
          (replace 'install (lambda _ #t)))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/facebook/react")
    (synopsis "Authored React Compiler Babel plugin for Next vendor builds")
    (description "This package builds the complete React Compiler plugin entry
from the fixed React source commit with its authored tsup and TypeScript
configuration.  The locked build graph uses source-built Rollup, esbuild and
source-map WASM, authenticated peer bindings and fixed registry inputs.  It
installs the plugin, manifest and licenses; React release integration and
functional validation remain separate steps.")
    (license license:expat)))
