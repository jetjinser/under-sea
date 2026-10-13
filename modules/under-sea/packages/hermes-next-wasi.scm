;;; Source-built WASI standard library for Next's SWC error-code plugin.
(define-module (under-sea packages hermes-next-wasi)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (gnu packages rust)
  #:use-module (gnu packages web)
  #:use-module (gnu packages python)
  #:use-module (gnu packages llvm))

(define-public rust-sysroot-wasip1-for-hermes-next
  (package
    (inherit rust-sysroot-for-wasm32-unknown-unknown)
    (name "rust-sysroot-wasip1-for-hermes-next")
    (native-inputs
     (modify-inputs (package-native-inputs rust-sysroot-for-wasm32-unknown-unknown)
       (prepend wasi-libc wasi-compiler-rt python-minimal lld-21)))
    (arguments
     (substitute-keyword-arguments
         (package-arguments rust-sysroot-for-wasm32-unknown-unknown)
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-after 'configure 'configure-wasi-preview-one
              (lambda _
                (invoke "python3" #$(local-file "../../../scripts/configure-hermes-wasi.py")
                        "config.toml" #$(file-append wasi-libc "/share/wasi-sysroot"))))))))
    (synopsis "Source-built Rust WASI preview-one standard library for Next")
    (description "This package builds the channel's Rust 1.93 standard library
for wasm32-wasip1 using source-built WASI libc.  It supplies the matching sysroot
needed to rebuild Next's error-code SWC WebAssembly plugin without rustup
or precompiled target libraries.  Plugin compilation and framework integration
are separate packages.")))
