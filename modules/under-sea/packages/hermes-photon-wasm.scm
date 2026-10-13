;;; Source-built @silvia-odwyer/photon-node (Rust image library as WASM).
(define-module (under-sea packages hermes-photon-wasm)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages rust)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages python)
  #:use-module (under-sea packages photon-wasm-lock)
  #:use-module (under-sea packages hermes-wasm-tools))

(define-public photon-wasm-for-hermes-node
  (package
    (name "photon-wasm-for-hermes-node")
    (version "0.3.4")
    (source %photon-wasm-source)
    (build-system gnu-build-system)
    (native-inputs
     (list rust-1.93 (list rust-1.93 "cargo") python-minimal lld-17 llvm-23
           rust-sysroot-for-wasm32-unknown-unknown
           wasm-bindgen-cli-for-hermes-browser))
    (arguments
     (list
      #:substitutable? #f
      #:modules '((guix build gnu-build-system) (guix build utils) (ice-9 match))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          (add-before 'build 'prepare-offline-sources
            (lambda _
              (mkdir-p "guix-source-inputs")
              (for-each
               (match-lambda
                 ((identity checksum source)
                  (copy-file source (string-append "guix-source-inputs/" identity ".crate"))))
               '#$%photon-wasm-crate-sources)
              (copy-file #$(local-file "../../../planning/photon-wasm-Cargo.lock")
                         "Cargo.lock")
              (invoke "python3" #$(local-file "../../../scripts/prepare-photon-wasm.py")
                      "." "guix-source-inputs" "guix-offline-work"
                      "--inventory"
                      #$(local-file "../../../planning/photon-wasm-source.json"))
              (copy-recursively #$rust-sysroot-for-wasm32-unknown-unknown
                                "guix-wasm-sysroot")
              (for-each make-file-writable
                        (cons "guix-wasm-sysroot"
                              (find-files "guix-wasm-sysroot" ".*" #:directories? #t)))
              (for-each (lambda (file) (invoke #$(file-append llvm-23 "/bin/llvm-ranlib") file))
                        (find-files "guix-wasm-sysroot" "\\.rlib$"))
              (setenv "CARGO_HOME" (string-append (getcwd) "/guix-offline-work/cargo-home"))
              (setenv "CARGO_TARGET_DIR" (string-append (getcwd) "/target"))
              (setenv "CARGO_BUILD_JOBS" "1")
              (setenv "CC" "gcc")
              (setenv "CARGO_TARGET_WASM32_UNKNOWN_UNKNOWN_RUSTFLAGS"
                      (string-append "--sysroot " (getcwd)
                                     "/guix-wasm-sysroot -C linker=" (which "wasm-ld")))))
          (replace 'build
            (lambda _
              (with-directory-excursion "crate"
                (invoke "cargo" "build" "--release" "--offline" "--locked"
                        "--target" "wasm32-unknown-unknown"))
              (mkdir-p "generated")
              (invoke "wasm-bindgen" "--target" "nodejs" "--out-name" "photon_rs"
                      "--out-dir" "generated"
                      "target/wasm32-unknown-unknown/release/photon_rs.wasm")))
          (replace 'install
            (lambda _
              (let ((module (string-append #$output
                                           "/lib/node_modules/@silvia-odwyer/photon-node")))
                (mkdir-p module)
                (for-each (lambda (name)
                            (copy-file (string-append "generated/" name)
                                       (string-append module "/" name)))
                          '("photon_rs.js" "photon_rs_bg.wasm" "photon_rs.d.ts"))
                (copy-file "crate/LICENSE.md" (string-append module "/LICENSE.md"))
                (call-with-output-file (string-append module "/package.json")
                  (lambda (port)
                    (format port "{\"name\":\"@silvia-odwyer/photon-node\",\"version\":\"0.3.4\",\"main\":\"photon_rs.js\",\"types\":\"photon_rs.d.ts\",\"license\":\"Apache-2.0\"}~%")))))))))
    (supported-systems '("x86_64-linux"))
    (properties '((max-silent-time . 7200)))
    (home-page "https://github.com/silvia-odwyer/photon")
    (synopsis "Source-built photon image library as Node WebAssembly")
    (description "This package compiles the photon Rust crate to wasm32 and
generates Node.js bindings with the source-built wasm-bindgen, replacing the
precompiled WebAssembly payload published on npm.")
    (license license:asl2.0)))
