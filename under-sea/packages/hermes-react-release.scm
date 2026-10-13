(define-module (under-sea packages hermes-react-release)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages node)
  #:use-module (under-sea packages hermes-react-release-hooks-types-node-lock)
  #:use-module (under-sea packages hermes-react-rollup3)
  #:use-module (under-sea packages hermes-react-closure)
  #:use-module (under-sea packages hermes-react-compiler-node-lock)
  #:use-module (under-sea packages hermes-react-rollup-node-lock)
  #:use-module (under-sea packages hermes-react-rollup-node)
  #:use-module (under-sea packages hermes-react-rollup)
  #:use-module (under-sea packages hermes-react-tools)
  #:use-module (under-sea packages hermes-source-map))

(define-public react-release-for-hermes-next
  (package
    (name "react-release-for-hermes-next")
    (version "19.3.0-canary-52684925-20251110")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/facebook/react/tar.gz/52684925368a41a0c9fbfca9016cdcbb72fc9d1e")
       (file-name "react-52684925368a41a0c9fbfca9016cdcbb72fc9d1e-source.tar.gz")
       (sha256 (base16-string->bytevector
                "8ef0acfa8ce4bdcb50854c1020d334d4efb8b1807f61652ecfad7c449b024620"))))
    (build-system gnu-build-system)
    (native-inputs (list python-minimal python-pyyaml node))
    (inputs (list rollup3-for-hermes-react closure-node-for-hermes-react
                  closure-java-node-for-hermes-react
                  rollup-node-for-hermes-react-compiler
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
              ;; Guix may reuse a kept-failed build directory; previously
              ;; assembled module trees and stale symlinks must not leak into
              ;; this build's layout.
              (for-each (lambda (dir)
                          (when (file-exists? dir)
                            (delete-file-recursively dir)))
                        '("guix-react-modules" "guix-compiler-node-modules"
                          "guix-react-release-stage"))
              (call-with-output-file "guix-archive-paths.tsv"
                (lambda (port)
                  (for-each
                   (lambda (entry) (format port "~a\t~a~%" (car entry) (cadr entry)))
                   '#$%react-release-hooks-types-node-source-origins)
                  (format port "tslib@2.8.1\t~a~%"
                          #$(cadr (assoc "tslib@2.8.1" %rollup-node-source-origins)))))
              (invoke "python3" "-c"
                      "import json,sys; json.dump(dict(zip(sys.argv[2::2],sys.argv[3::2])),open(sys.argv[1],'w'))"
                      "guix-providers.json"
                      "rollup@3.29.5"
                      #$(file-append rollup3-for-hermes-react "/lib/node_modules/rollup")
                      "google-closure-compiler@20230206.0.0"
                      #$(file-append closure-node-for-hermes-react "/lib/node_modules/google-closure-compiler")
                      "google-closure-compiler-java@20230206.0.0"
                      #$(file-append closure-java-node-for-hermes-react "/lib/node_modules/google-closure-compiler-java"))
              (invoke "python3" #$(local-file "../../scripts/assemble-agent-browser-node.py")
                      #$(local-file "../../planning/hermes-react-release-hooks-types-node-inventory.json")
                      #$(local-file "../../planning/hermes-react-release-hooks-types-node-archives.json")
                      "yarn.lock" "guix-react-modules"
                      "--providers" "guix-providers.json"
                      "--archive-paths" "guix-archive-paths.tsv"
                      "--lock-format" "yarn-v1"
                      "--peer-bindings" #$(local-file "../../planning/hermes-react-release-hooks-types-peer-bindings.json")
                      "--yarn-peer-audit" #$(local-file "../../planning/hermes-react-release-hooks-types-peer-audit.json")
                      "--compose-provider" "google-closure-compiler@20230206.0.0"
                      "--compose-provider" "google-closure-compiler-java@20230206.0.0"
                      "--optional-replacements" #$(local-file "../../planning/hermes-react-build-java-path-replacements.json"))
              (call-with-output-file "guix-compiler-archive-paths.tsv"
                (lambda (port)
                  (for-each
                   (lambda (entry) (format port "~a\t~a~%" (car entry) (cadr entry)))
                   '#$%react-compiler-node-source-origins)))
              (invoke "python3" "-c"
                      "import json,sys; json.dump(dict(zip(sys.argv[2::2],sys.argv[3::2])),open(sys.argv[1],'w'))"
                      "guix-compiler-providers.json"
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
                      #$(local-file "../../scripts/assemble-agent-browser-node.py")
                      #$(local-file "../../planning/hermes-react-compiler-config-node-inventory.json")
                      #$(local-file "../../planning/hermes-react-compiler-config-node-archives.json")
                      "compiler/yarn.lock" "guix-compiler-node-modules"
                      "--providers" "guix-compiler-providers.json"
                      "--archive-paths" "guix-compiler-archive-paths.tsv"
                      "--lock-format" "yarn-v1" "--peer-bindings"
                      #$(local-file "../../planning/hermes-react-compiler-config-peer-bindings.json")
                      "--yarn-peer-audit"
                      #$(local-file "../../planning/hermes-react-compiler-config-peer-audit.json")
                      "--compose-provider" "rollup@4.34.9"
                      "--compose-provider" "esbuild@0.25.0"
                      "--compose-provider" "source-map@0.8.0-beta.0")
              (invoke "python3" #$(local-file "../../scripts/build-react-source-release.py")
                      "." "guix-react-modules" "guix-react-release-stage"
                      "--compiler-modules" "guix-compiler-node-modules"
                      "--node" #$(file-append node "/bin/node")
                      "--metadata-script" #$(local-file "../../scripts/patch-react-source-metadata.py"))))
          (replace 'install
            (lambda _
              (invoke "python3" #$(local-file "../../scripts/install-react-source-release.py")
                      "guix-react-release-stage" #$output))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/facebook/react")
    (synopsis "Source-built React release channels for Next vendor resources")
    (description "This package executes the complete authored React release
build for the fixed source commit.  It uses source-built Rollup and Closure Java
providers and authenticated build dependencies.  Complete channel resources and
licenses are installed.  Functional validation is deferred.")
    (license license:expat)))
