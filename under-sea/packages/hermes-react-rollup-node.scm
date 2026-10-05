(define-module (under-sea packages hermes-react-rollup-node)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages node)
  #:use-module (under-sea packages hermes-react-rollup)
  #:use-module (under-sea packages hermes-react-rollup-node-lock)
  #:use-module (under-sea packages hermes-react-tools))

(define %locate-character-source
  (cadr (assoc "locate-character@3.0.0" %rollup-node-source-origins)))
(define %is-reference-source
  (cadr (assoc "is-reference@3.0.3" %rollup-node-source-origins)))

(define-public rollup-bootstrap-for-hermes-react
  (package
    (inherit rollup-binding-for-hermes-react-bootstrap)
    (name "rollup-bootstrap-for-hermes-react")
    (native-inputs (list python-minimal))
    (inputs (list esbuild-for-hermes-react-compiler
                  rollup-binding-for-hermes-react-bootstrap))
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
              (invoke "tar" "xf" #$%locate-character-source
                      "--strip-components=1" "-C" "guix-inline/locate-character")
              (invoke "tar" "xf" #$%is-reference-source
                      "--strip-components=1" "-C" "guix-inline/is-reference")
              (call-with-output-file "guix-inline-archive-paths.tsv"
                (lambda (port)
                  (format port "locate-character@3.0.0\t~a~%is-reference@3.0.3\t~a~%"
                          #$%locate-character-source #$%is-reference-source)))
              (invoke "python3"
                      #$(local-file "../../scripts/build-rollup-source-bootstrap.py")
                      "."
                      #$(file-append esbuild-for-hermes-react-compiler "/bin/esbuild")
                      #$(file-append rollup-binding-for-hermes-react-bootstrap
                                     "/lib/node_modules/@rollup/rollup-linux-x64-gnu")
                      (string-append #$output "/lib/node_modules/rollup")
                      "--inline-import-only" "guix-inline"
                      "--input-archives"
                      #$(local-file "../../planning/hermes-react-rollup-all-types-node-archives.json")
                      "--archive-paths" "guix-inline-archive-paths.tsv")))
          (replace 'install (lambda _ #t)))))
    (synopsis "Source-only Rollup bootstrap for the authored Node release")
    (description "This private build tool compiles all five authored TypeScript
entrypoints and installs their source declarations with the exact native binding.
Import-only dependencies are inlined from authenticated source archives whose
integrities match the bootstrap lock. It is a build prerequisite; the final
authored Node and browser releases and functional validation remain separate.")))

(define-public rollup-node-for-hermes-react-compiler
  (package
    (inherit rollup-binding-for-hermes-react-compiler)
    (name "rollup-node-for-hermes-react-compiler")
    (native-inputs (list python-minimal python-pyyaml node))
    (inputs (list rollup-bootstrap-for-hermes-react
                  rollup-binding-for-hermes-react-bootstrap
                  rollup-binding-for-hermes-react-compiler
                  esbuild-node-for-hermes-react-compiler
                  esbuild-for-hermes-react-compiler))
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
                   '#$%rollup-node-source-origins)))
              (invoke "python3" "-c"
                      "import json,sys; json.dump(dict(zip(sys.argv[2::2],sys.argv[3::2])),open(sys.argv[1],'w'))"
                      "guix-providers.json"
                      "rollup@4.34.8"
                      #$(file-append rollup-bootstrap-for-hermes-react "/lib/node_modules/rollup")
                      "@rollup/rollup-linux-x64-gnu@4.34.8"
                      #$(file-append rollup-binding-for-hermes-react-bootstrap
                                     "/lib/node_modules/@rollup/rollup-linux-x64-gnu")
                      "esbuild@0.25.0"
                      #$(file-append esbuild-node-for-hermes-react-compiler "/lib/node_modules/esbuild")
                      "@esbuild/linux-x64@0.25.0"
                      #$(file-append esbuild-for-hermes-react-compiler "/lib/node_modules/@esbuild/linux-x64"))
              (invoke "python3"
                      #$(local-file "../../scripts/assemble-agent-browser-node.py")
                      #$(local-file "../../planning/hermes-react-rollup-all-types-node-inventory.json")
                      #$(local-file "../../planning/hermes-react-rollup-all-types-node-archives.json")
                      "package-lock.json" "node_modules"
                      "--providers" "guix-providers.json"
                      "--archive-paths" "guix-archive-paths.tsv"
                      "--lock-format" "npm" "--npm-peer-audit"
                      #$(local-file "../../planning/hermes-react-rollup-all-types-peer-audit.json")
                      "--compose-provider" "rollup@4.34.8"
                      "--compose-provider" "esbuild@0.25.0")
              (invoke "python3"
                      #$(local-file "../../scripts/build-rollup-source-node.py")
                      "." #$(file-append node "/bin/node")
                      #$(file-append rollup-binding-for-hermes-react-compiler
                                     "/lib/node_modules/@rollup/rollup-linux-x64-gnu")
                      (string-append #$output "/lib/node_modules/rollup"))))
          (replace 'install (lambda _ #t)))))
    (synopsis "Authored source-built Rollup Node release for React Compiler")
    (description "This package runs the upstream Node release build against
its fixed npm lock and a source-only bootstrap. It installs the authored CJS,
ESM, CLI, declarations, source maps and matching native binding. Archive input
paths are fixed Guix store references; install scripts are not run. The separate
browser/WASM release and functional validation remain pending.")))
