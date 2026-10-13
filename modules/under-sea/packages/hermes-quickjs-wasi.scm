;;; Source-built quickjs-wasi (QuickJS compiled to a WASI reactor) for Pi.
(define-module (under-sea packages hermes-quickjs-wasi)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages web)
  #:use-module (gnu packages python))

(define %quickjs-wasi-source
  ;; vercel-labs/quickjs-wasi at tag quickjs-wasi@3.6.2 (commit 5a7a0eed...).
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/vercel-labs/quickjs-wasi/tar.gz/5a7a0eeda87c99542f8cf3095b6d61ecfa755977")
    (file-name "quickjs-wasi-3.6.2.tar.gz")
    (sha256
     (base16-string->bytevector
      "cb3a2e58fd7187104b9294962e205c28433ecb7653d75771a35ef98dfdfb8484"))))

(define %quickjs-ng-source
  ;; quickjs-ng submodule pinned by quickjs-wasi@3.6.2.
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/quickjs-ng/quickjs/tar.gz/6d46d07d04041b40f4f49eaa7fdebe44c314c699")
    (file-name "quickjs-ng.tar.gz")
    (sha256
     (base16-string->bytevector
      "a62cf1ff7d6d2f82b90a2d247a57e9eb56b81c03feb1f372a53923426e358cb0"))))

(define %quickjs-wasi-npm
  ;; The published JavaScript wrapper/types.  The wasm binary and extension
  ;; dynamic modules in this tarball are NOT used; they are rebuilt below.
  (origin
    (method url-fetch)
    (uri "https://registry.npmjs.org/quickjs-wasi/-/quickjs-wasi-3.6.2.tgz")
    (file-name "quickjs-wasi-3.6.2-npm.tgz")
    (sha256
     (base16-string->bytevector
      "f1f4349f19a2d849e33ea0ae9bec2e7062b8839f4eceb17c9051ddbaa2720982"))))

(define-public quickjs-wasi-for-hermes
  (package
    (name "quickjs-wasi-for-hermes")
    (version "3.6.2")
    (source %quickjs-wasi-source)
    (build-system gnu-build-system)
    (native-inputs (list clang-toolchain llvm lld wasi-libc wasi-compiler-rt
                         binaryen bash-minimal python-minimal))
    (arguments
     (list
      #:substitutable? #f
      #:modules '((guix build gnu-build-system) (guix build utils))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'check)
          (add-after 'unpack 'unpack-quickjs-ng
            (lambda _
              (mkdir-p "quickjs-ng")
              (invoke "tar" "xf" #$%quickjs-ng-source "-C" "quickjs-ng"
                      "--strip-components=1")))
          (replace 'build
            (lambda* (#:key inputs #:allow-other-keys)
              (invoke "sh"
                      #$(local-file "../../../scripts/build-quickjs-wasi.sh")
                      (assoc-ref inputs "wasi-libc")
                      (assoc-ref inputs "wasi-compiler-rt")
                      (assoc-ref inputs "binaryen")
                      (getcwd)
                      (string-append (getcwd) "/built"))))
          (replace 'install
            (lambda _
              (let ((module (string-append #$output "/lib/node_modules/quickjs-wasi"))
                    (staging (string-append (getcwd) "/npm")))
                (mkdir-p staging)
                (invoke "tar" "xf" #$%quickjs-wasi-npm "-C" staging
                        "--strip-components=1" "package/dist" "package/package.json"
                        "package/LICENSE" "package/README.md")
                (mkdir-p module)
                (copy-recursively (string-append staging "/dist")
                                  (string-append module "/dist"))
                (for-each (lambda (file)
                            (copy-file (string-append staging "/" file)
                                       (string-append module "/" file)))
                          '("package.json" "LICENSE" "README.md"))
                (copy-file (string-append (getcwd) "/built/quickjs.wasm")
                           (string-append module "/quickjs.wasm"))
                (copy-recursively (string-append (getcwd) "/built/extensions")
                                  (string-append module "/extensions"))))))))
    (supported-systems '("x86_64-linux"))
    (properties '((max-silent-time . 7200)))
    (home-page "https://github.com/vercel-labs/quickjs-wasi")
    (synopsis "Source-built QuickJS WASI runtime for Pi")
    (description "This package compiles quickjs-ng and the quickjs-wasi C
extensions into a WASI reactor module using the Guix clang/lld/wasi-libc
toolchain, and combines them with the published JavaScript wrapper.  The
prebuilt wasm payloads from npm are not used.  The URL extension, which requires
libc++, is not built.")
    (license license:expat)))
