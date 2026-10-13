(define-module (under-sea packages hermes-react-rollup3)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages node)
  #:use-module (under-sea packages hermes-react-tools)
  #:use-module (under-sea packages hermes-react-rollup3-node-lock))

(define %inline-locate
  (cadr (assoc "locate-character@3.0.0" %rollup3-node-source-origins)))
(define %inline-reference
  (cadr (assoc "is-reference@3.0.2" %rollup3-node-source-origins)))

(define-public rollup3-bootstrap-for-hermes-react
  (package
    (name "rollup3-bootstrap-for-hermes-react")
    (version "3.29.2")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/rollup/rollup/tar.gz/refs/tags/v3.29.2")
       (file-name "rollup-3.29.2-react-source.tar.gz")
       (sha256 (base16-string->bytevector
                "a2fa335d31a4fe19099e04afc01d496cebc2b703ab3fc063c6261f9a959976e5"))))
    (build-system gnu-build-system)
    (native-inputs (list python-minimal))
    (inputs (list esbuild-for-hermes-rollup3))
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
              (mkdir-p "guix-inline/locate-character")
              (mkdir-p "guix-inline/is-reference")
              (invoke "tar" "xf" #$%inline-locate "--strip-components=1"
                      "-C" "guix-inline/locate-character")
              (invoke "tar" "xf" #$%inline-reference "--strip-components=1"
                      "-C" "guix-inline/is-reference")
              (call-with-output-file "guix-inline-archives.tsv"
                (lambda (port)
                  (format port "locate-character@3.0.0\t~a~%is-reference@3.0.2\t~a~%"
                          #$%inline-locate #$%inline-reference)))
              (invoke "python3"
                      #$(local-file "../../../scripts/build-rollup-source-bootstrap.py")
                      "." #$(file-append esbuild-for-hermes-rollup3 "/bin/esbuild")
                      "-" (string-append #$output "/lib/node_modules/rollup")
                      "--inline-import-only" "guix-inline" "--input-archives"
                      #$(local-file "../../../planning/hermes-react-rollup-3292-runtime-archives.json")
                      "--archive-paths" "guix-inline-archives.tsv")))
          (replace 'install (lambda _ #t)))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://rollupjs.org")
    (synopsis "Source-only bootstrap matching Rollup 3's authored build lock")
    (description "This private tool compiles the exact Rollup 3.29.2 authored
API and CLI entries with their declarations.  Import-only sources are verified
against its own upstream lock.  It is a prerequisite for the full release build;
functional validation is deferred.")
    (license license:expat)))

(define-public rollup3-for-hermes-react
  (package
    (inherit rollup3-bootstrap-for-hermes-react)
    (name "rollup3-for-hermes-react")
    (version "3.29.5")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/rollup/rollup/tar.gz/refs/tags/v3.29.5")
       (file-name "rollup-3.29.5-react-source.tar.gz")
       (sha256 (base16-string->bytevector
                "338cf141c6c9621f82a6071c1a3b9ad47a006945b71f4322683bee76dfa610a4"))))
    (native-inputs (list python-minimal python-pyyaml node))
    (inputs (list rollup3-bootstrap-for-hermes-react
                  esbuild-for-hermes-rollup3 esbuild-node-for-hermes-rollup3))
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
                   '#$%rollup3-node-source-origins)))
              (invoke "python3" "-c"
                      "import json,sys; json.dump(dict(zip(sys.argv[2::2],sys.argv[3::2])),open(sys.argv[1],'w'))"
                      "guix-providers.json"
                      "rollup@3.29.2"
                      #$(file-append rollup3-bootstrap-for-hermes-react "/lib/node_modules/rollup")
                      "esbuild@0.18.20"
                      #$(file-append esbuild-node-for-hermes-rollup3 "/lib/node_modules/esbuild")
                      "@esbuild/linux-x64@0.18.20"
                      #$(file-append esbuild-for-hermes-rollup3 "/lib/node_modules/@esbuild/linux-x64"))
              (invoke "python3"
                      #$(local-file "../../../scripts/assemble-agent-browser-node.py")
                      #$(local-file "../../../planning/hermes-react-rollup-3295-browser-node-inventory.json")
                      #$(local-file "../../../planning/hermes-react-rollup-3295-browser-node-archives.json")
                      "package-lock.json" "node_modules"
                      "--providers" "guix-providers.json" "--archive-paths" "guix-archive-paths.tsv"
                      "--lock-format" "npm" "--npm-peer-audit"
                      #$(local-file "../../../planning/hermes-react-rollup-3295-browser-peer-audit.json")
                      "--compose-provider" "rollup@3.29.2"
                      "--compose-provider" "esbuild@0.18.20")
              (invoke "python3" #$(local-file "../../../scripts/build-rollup3-source-release.py")
                      "." #$(file-append node "/bin/node")
                      (string-append #$output "/lib/node_modules/rollup"))))
          (replace 'install (lambda _ #t)))))
    (synopsis "Full source-built Rollup 3 release for React's build pipeline")
    (description "This package builds Rollup 3.29.5 using the authored lock and
matching source-only bootstrap.  It installs the complete CJS, ESM, CLI, declarations,
source maps and browser releases with their manifests and licenses.  Functional
validation is deferred until the complete package combination is assembled.")))
