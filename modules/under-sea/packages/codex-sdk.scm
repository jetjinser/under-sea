;;; Codex TypeScript SDK: offline compilation against the upstream lock.
(define-module (under-sea packages codex-sdk)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (under-sea gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages node)
  #:use-module (gnu packages python)
  #:use-module (under-sea packages codex)
  #:use-module (under-sea packages codex-lock)
  #:use-module (under-sea packages hermes-node))

(define %sdk-build-sources
  (list
    (list "typescript-5.9.2.tgz"
      (origin
        (method url-fetch)
        (uri "https://registry.npmjs.org/typescript/-/typescript-5.9.2.tgz")
        (file-name "typescript-5.9.2.tgz")
        (sha256 (base16-string->bytevector "67a3bc82e822b8f45f653a80fc3a9730d23214d36c83ba85dd7f5abebee82062"))))
    (list "types-node-20.19.18.tgz"
      (origin
        (method url-fetch)
        (uri "https://registry.npmjs.org/@types/node/-/node-20.19.18.tgz")
        (file-name "types-node-20.19.18.tgz")
        (sha256 (base16-string->bytevector "2356fad8ae608cf6c5ed54f059cafcbdf79236a1445a895a39c81f8a90f856aa"))))
    (list "undici-types-6.21.0.tgz"
      (origin
        (method url-fetch)
        (uri "https://registry.npmjs.org/undici-types/-/undici-types-6.21.0.tgz")
        (file-name "undici-types-6.21.0.tgz")
        (sha256 (base16-string->bytevector "cfa1a9a5e18988850e548f4f6b629c58da32dc32bebb116e58ea301e516fd16d"))))
    (list "mcp-sdk-1.26.0.tgz"
      (origin
        (method url-fetch)
        (uri "https://registry.npmjs.org/@modelcontextprotocol/sdk/-/sdk-1.26.0.tgz")
        (file-name "mcp-sdk-1.26.0.tgz")
        (sha256 (base16-string->bytevector "d932597ad68dabf54fc3899cb5afb74939443e36af65d50ea709c9bd0ea1e9a8"))))
    (list "zod-3.25.76.tgz"
      (origin
        (method url-fetch)
        (uri "https://registry.npmjs.org/zod/-/zod-3.25.76.tgz")
        (file-name "zod-3.25.76.tgz")
        (sha256 (base16-string->bytevector "9e1f1a05f0dd0c1dab64ee91ceb9bf55cd44d35368c70edda80a2fdc70a88377"))))
  ))

(define %mcp-sdk-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/modelcontextprotocol/typescript-sdk/tar.gz/refs/tags/v1.26.0")
    (file-name "mcp-sdk-1.26.0-source.tar.gz")
    (sha256 (base16-string->bytevector
             "5b6b37e32f46f03405d311b6e905c294e52a865fc8e27b5ae21fa787521163e7"))))

(define-public codex-sdk
  (package
    (name "codex-sdk")
    (version %codex-version)
    (source %codex-source)
    (build-system gnu-build-system)
    (native-inputs (list node python esbuild-for-hermes))
    (inputs (list codex-complete))
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
                  '#$%sdk-build-sources)))
            (replace 'build
              (lambda _
                (invoke "python3"
                  #$(under-sea-script "build-codex-sdk-types.py")
                  "sdk/typescript" "sdk-archives" "sdk-build"
                  "--node" (which "node")
                  "--esbuild" #$(file-append esbuild-for-hermes "/bin/esbuild")
                  "--codex-bin" #$(file-append codex-complete "/bin/codex")
                  "--version" #$%codex-version
                  "--install-prefix" #$output)))
            (add-after 'build 'build-public-type-closure
              (lambda _
                (mkdir "mcp-source")
                (invoke "tar" "-xzf" #$%mcp-sdk-source
                        "-C" "mcp-source" "--strip-components=1")
                (invoke "python3"
                  #$(under-sea-script "build-codex-sdk-public-types.py")
                  "sdk-build" "mcp-source" "sdk-public-types"
                  "--node" (which "node")
                  "--install-sdk"
                  (string-append #$output "/lib/node_modules/@openai/codex-sdk"))))
            (replace 'install (lambda _ #t)))))
    (home-page "https://github.com/openai/codex")
    (synopsis "TypeScript SDK for the source-built Codex CLI")
    (description "This package compiles the Codex TypeScript SDK and public
 declarations offline.  Its default executable is the matching source-built
 complete Codex package.  An explicit executable override remains supported.
 Its private public-type dependencies are compiled from matching MCP and Zod
 sources and installed with the SDK.")
    (license license:asl2.0)))
