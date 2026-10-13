;;; Source-built undici with a source-rebuilt llhttp WASM parser.
(define-module (under-sea packages hermes-undici)
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

(define %undici-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/nodejs/undici/tar.gz/refs/tags/v8.10.2")
    (file-name "undici-8.10.2.tar.gz")
    (sha256
     (base16-string->bytevector
      "624b88cdd02deeaf814d6587114f3b6bbb14df61ba60909465beff170711750b"))))

(define-public undici-for-hermes
  (package
    (name "undici-for-hermes")
    (version "8.10.2")
    (source %undici-source)
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
          (replace 'build
            (lambda* (#:key inputs #:allow-other-keys)
              (invoke "sh"
                      #$(local-file "../../scripts/build-undici-llhttp-wasm.sh")
                      (assoc-ref inputs "wasi-libc")
                      (assoc-ref inputs "wasi-compiler-rt")
                      (assoc-ref inputs "binaryen")
                      (getcwd)
                      (string-append (getcwd) "/built"))))
          (replace 'install
            (lambda _
              (let ((module (string-append #$output "/lib/node_modules/undici")))
                (mkdir-p module)
                (for-each (lambda (item)
                            (copy-recursively item (string-append module "/" item)))
                          '("index.js" "index-fetch.js" "index.d.ts" "lib"
                            "types" "scripts" "docs"))
                (for-each (lambda (file)
                            (copy-file file (string-append module "/" file)))
                          '("package.json" "LICENSE" "README.md"))
                ;; Replace the prebuilt llhttp payloads with the source build.
                (for-each (lambda (stale)
                            (when (file-exists? stale) (delete-file stale)))
                          (list (string-append module "/lib/llhttp/llhttp.wasm")
                                (string-append module "/lib/llhttp/llhttp_simd.wasm")))
                (for-each (lambda (js)
                            (copy-file (string-append (getcwd) "/built/" js)
                                       (string-append module "/lib/llhttp/" js)))
                          '("llhttp-wasm.js" "llhttp_simd-wasm.js"))))))))
    (supported-systems '("x86_64-linux"))
    (properties '((max-silent-time . 7200)))
    (home-page "https://github.com/nodejs/undici")
    (synopsis "Source-built undici with a source-built llhttp WASM parser")
    (description "This package compiles undici's bundled llhttp C parser to
WASM with the Guix wasi toolchain and combines it with the upstream JavaScript
sources.  The npm precompiled llhttp WebAssembly payload is not used.")
    (license license:expat)))
