;;; Rebuild Next's authored error-code SWC plugin instead of copying its WASM.
(define-module (under-sea packages hermes-next-error-plugin)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (under-sea gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages rust)
  #:use-module (gnu packages python)
  #:use-module (gnu packages llvm)
  #:use-module (under-sea packages next-error-plugin-lock)
  #:use-module (under-sea packages hermes-next-wasi))

(define-public next-error-code-plugin-for-hermes
  (package
    (name "next-error-code-plugin-for-hermes")
    (version %next-native-version)
    (source %next-native-source)
    (build-system gnu-build-system)
    (native-inputs
     (list rust-1.93 (list rust-1.93 "cargo") python-minimal lld-21 llvm-23
           rust-sysroot-wasip1-for-hermes-next))
    (arguments
     (list
      #:substitutable? #f
      #:modules '((guix build gnu-build-system) (guix build utils) (ice-9 match))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          (add-before 'build 'prepare-authored-plugin
            (lambda _
              (copy-file "license.md" "crates/next-error-code-swc-plugin/LICENSE")
              ;; Upstream explicitly excludes this independent workspace from
              ;; its root Cargo graph.  Retain its own manifest and Cargo.lock.
              (chdir "crates/next-error-code-swc-plugin")
              (invoke "python3"
                      #$(under-sea-script "patch-next-error-plugin-source.py"))
              (call-with-output-file "crate-sources.tsv"
                (lambda (port)
                  (for-each
                   (match-lambda
                     ((name checksum source)
                      (format port "~a\t~a\t~a~%" name checksum source)))
                   '#$%next-native-crate-sources)))
              (setenv "CARGO_HOME" (string-append (getcwd) "/guix-cargo-home"))
              (invoke "python3" #$(under-sea-script "prepare-hermes-native.py"))
              (copy-recursively #$rust-sysroot-wasip1-for-hermes-next "guix-wasi-rust-sysroot")
              (for-each make-file-writable
                        (cons "guix-wasi-rust-sysroot"
                              (find-files "guix-wasi-rust-sysroot" ".*" #:directories? #t)))
              (for-each
               (lambda (file) (invoke #$(file-append llvm-23 "/bin/llvm-ranlib") file))
               (find-files "guix-wasi-rust-sysroot" "\\.rlib$"))
              (setenv "CARGO_BUILD_JOBS" "1")
              (setenv "CARGO_TARGET_DIR" (string-append (getcwd) "/target"))
              (setenv "CARGO_TARGET_WASM32_WASIP1_RUSTFLAGS"
                      (string-append "--sysroot " (getcwd) "/guix-wasi-rust-sysroot -C linker="
                                     #$(file-append lld-21 "/bin/wasm-ld")))
              ;; Exact authored release script settings, including LTO.
              (setenv "CARGO_PROFILE_RELEASE_STRIP" "true")
              (setenv "CARGO_PROFILE_RELEASE_LTO" "true")))
          (replace 'build
            (lambda _
              (invoke "cargo" "build" "--target" "wasm32-wasip1"
                      "--release" "--offline" "--locked")))
          (replace 'install
            (lambda _
              (let ((destination (string-append #$output "/share/next-error-code-plugin")))
                (mkdir-p destination)
                (copy-file "target/wasm32-wasip1/release/next_error_code_swc_plugin.wasm"
                           (string-append destination "/next_error_code_swc_plugin.wasm"))
                (copy-file "LICENSE" (string-append destination "/LICENSE"))
                (copy-file "Cargo.lock" (string-append destination "/Cargo.lock"))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/vercel/next.js")
    (synopsis "Source-built Next error-code SWC WASI plugin")
    (description "This package rebuilds Next's error-code SWC transform from
its independent authored Cargo lock and matching source-built WASI sysroot.
The transform preserves Next error-code reporting.  The upstream committed
WebAssembly file and rustup binary target downloads are not used.")
    (license license:expat)))
