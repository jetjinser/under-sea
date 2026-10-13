;;; Exact source-built native tools for the React Compiler build environment.
(define-module (under-sea packages hermes-react-tools)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages node)
  #:use-module (under-sea packages hermes-satori-tools))

(define-public esbuild-for-hermes-react-compiler
  (package
    (inherit esbuild-for-hermes-satori)
    (name "esbuild-for-hermes-react-compiler")
    (version "0.25.0")
    (source
     (origin
       (inherit (package-source esbuild-for-hermes-satori))
       (uri "https://codeload.github.com/evanw/esbuild/tar.gz/refs/tags/v0.25.0")
       (file-name "react-compiler-esbuild-0.25.0-source.tar.gz")
       (sha256
        (base16-string->bytevector
         "c200f558d25a36513b830af8f9a09b5b8924807536f9c3b6b6024c301fee3b2c"))))
    (synopsis "Source-built esbuild matching the React Compiler lock")
    (description "This package compiles the exact esbuild 0.25.0 Go executable
and installs its Linux x64 platform provider.  The authored Go module retains
the same fixed x/sys revision as the shared source recipe.  Functional checks
are deferred until the complete component combination is built.")))

(define (make-esbuild-node-source-package name compiler)
  (package
    (inherit compiler)
    (name name)
    (source
     (origin
       (inherit (package-source compiler))
       (snippet #f)))
    (build-system gnu-build-system)
    (native-inputs (list node))
    (inputs (list compiler))
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
              (invoke "node" "scripts/esbuild.js"
                      #$(file-append compiler "/bin/esbuild")
                      "--neutral")))
          (replace 'install
            (lambda _
              (let ((module (string-append #$output "/lib/node_modules/esbuild")))
                (copy-recursively "npm/esbuild" module)
                (copy-file "LICENSE.md" (string-append module "/LICENSE.md"))))))))
    (synopsis "Source-built esbuild Node API for React Compiler")
    (description "This package runs the upstream neutral Node build against
the matching source-built Go compiler.  It generates the Node API, installer,
command shim and TypeScript declarations from the authored source.  The Linux
platform provider is supplied separately when composing locked Node modules;
the installer is not executed during this build.  Functional validation is
deferred until all components are assembled.")))

(define-public esbuild-node-for-hermes-react-compiler
  (make-esbuild-node-source-package "esbuild-node-for-hermes-react-compiler"
                                   esbuild-for-hermes-react-compiler))

(define-public esbuild-for-hermes-rollup3
  (package
    (inherit esbuild-for-hermes-satori)
    (name "esbuild-for-hermes-rollup3")
    (version "0.18.20")
    (source
     (origin
       (inherit (package-source esbuild-for-hermes-satori))
       (uri "https://codeload.github.com/evanw/esbuild/tar.gz/refs/tags/v0.18.20")
       (file-name "esbuild-0.18.20-rollup3-source.tar.gz")
       (sha256 (base16-string->bytevector
                "f4072282dd01d9343b03e6551f88599d9877b5e9f3a82e595e988e091249a86f"))))
    (synopsis "Source-built esbuild matching Rollup 3's release lock")
    (description "This package builds esbuild 0.18.20 and its Linux platform
provider with the exact authored x/sys revision.  Functional validation is deferred.")))

(define-public esbuild-node-for-hermes-rollup3
  (make-esbuild-node-source-package "esbuild-node-for-hermes-rollup3"
                                   esbuild-for-hermes-rollup3))
