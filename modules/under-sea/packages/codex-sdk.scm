;;; Codex TypeScript SDK: offline compilation against the upstream lock.
(define-module (under-sea packages codex-sdk)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (under-sea gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages node)
  #:use-module (gnu packages python)
  #:use-module (under-sea packages codex)
  #:use-module (under-sea packages codex-lock)
  #:use-module (under-sea packages hermes-node)
  #:use-module (under-sea packages codex-sdk-lock))

(define-public codex-sdk
  (package
    (name "codex-sdk")
    (version %codex-version)
    (source %codex-source)
    (build-system gnu-build-system)
    (native-inputs (list node python esbuild-for-hermes))
    (inputs (list codex))
    (arguments
      (list
        #:substitutable? #f
        #:modules '((guix build gnu-build-system) (guix build utils)
                    (ice-9 match))
        #:phases
        #~(modify-phases %standard-phases
            (delete 'bootstrap)
            (delete 'configure)
            (delete 'check)
            (add-before 'build 'prepare-locked-sources
              (lambda _
                (mkdir-p "sdk-archives")
                (for-each
                  (match-lambda
                    ((name source)
                     (copy-file source (string-append "sdk-archives/" name))))
                  '#$%codex-sdk-build-sources)))
            (replace 'build
              (lambda _
                (invoke "python3"
                  #$(under-sea-script "build-codex-sdk-types.py")
                  "sdk/typescript" "sdk-archives" "sdk-build"
                  "--node" (which "node")
                  "--esbuild" #$(file-append esbuild-for-hermes "/bin/esbuild")
                  "--codex-bin" #$(file-append codex "/bin/codex")
                  "--version" #$%codex-version
                  "--install-prefix" #$output)))
            (add-after 'build 'build-public-type-closure
              (lambda _
                (mkdir "mcp-source")
                (invoke "tar" "-xzf" #$%codex-sdk-mcp-source
                        "-C" "mcp-source" "--strip-components=1")
                (invoke "python3"
                  #$(under-sea-script "build-codex-sdk-public-types.py")
                  "sdk-build" "mcp-source" "sdk-public-types"
                  "--node" (which "node")
                  "--install-sdk"
                  (string-append #$output "/lib/node_modules/@openai/codex-sdk"))))
            (add-after 'build-public-type-closure 'check-sdk-import
              (lambda _
                (invoke "node" "--input-type=module" "-e"
                  (string-append
                    "const sdk = await import('file://" #$output
                    "/lib/node_modules/@openai/codex-sdk/dist/index.js'); "
                    "if (typeof sdk.Codex !== 'function' || "
                    "typeof sdk.Thread !== 'function') process.exit(1);"))))
            (replace 'install (lambda _ #t)))))
    (home-page "https://github.com/openai/codex")
    (synopsis "TypeScript SDK for the source-built Codex CLI")
    (description "This package compiles the Codex TypeScript SDK and public
 declarations offline.  Its default executable is the matching source-built
 complete Codex package.  An explicit executable override remains supported.
 Its private public-type dependencies are compiled from matching MCP and Zod
 sources and installed with the SDK.")
    (license license:asl2.0)))
