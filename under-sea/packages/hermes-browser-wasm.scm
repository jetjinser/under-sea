;;; Source-built WebAssembly resources used by the Hermes browser dashboard.
(define-module (under-sea packages hermes-browser-wasm)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system trivial)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages rust)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages node)
  #:use-module (gnu packages python)
  #:use-module (gnu packages web)
  #:use-module (gnu packages pkg-config)
  #:use-module (under-sea packages source-map-wasm-lock)
  #:use-module (under-sea packages resvg-wasm-lock)
  #:use-module (under-sea packages hermes-esbuild)
  #:use-module (under-sea packages hermes-wasm-tools)
  #:use-module (under-sea packages hermes-emscripten-tools))

(define %vscode-oniguruma-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/microsoft/vscode-oniguruma/tar.gz/refs/tags/v1.7.0")
    (file-name "vscode-oniguruma-1.7.0-source.tar.gz")
    (sha256 (base16-string->bytevector
             "0e472a9d670d3301024435c04c09870bce2779c22a099185c2988d99b1cea190"))))

(define %oniguruma-submodule-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/kkos/oniguruma/tar.gz/08d36110c5670c815ad6d6f969e578049d209080")
    (file-name "oniguruma-08d36110c5670c815ad6d6f969e578049d209080-source.tar.gz")
    (sha256 (base16-string->bytevector
             "197bdc01b6e71245ca95e652827fe53c4b1532a4175870f62157b5f909fa0e6f"))))

(define-public oniguruma-source-for-hermes-shiki
  (package
    (name "oniguruma-source-for-hermes-shiki")
    (version "08d36110")
    (source %oniguruma-submodule-source)
    (build-system trivial-build-system)
    (arguments
     (list #:modules '((guix build utils))
           #:builder #~(begin
                         (use-modules (guix build utils))
                         (let ((directory (string-append #$output "/share/source")))
                           (mkdir-p directory)
                           (copy-file #$source
                                      (string-append directory "/oniguruma.tar.gz"))))))
    (home-page "https://github.com/kkos/oniguruma")
    (synopsis "Pinned Oniguruma source used by vscode-oniguruma")
    (description "This package carries the exact upstream Git submodule archive
referenced by vscode-oniguruma 1.7.0. The archive is authenticated and is unpacked
only by the matching source WASM build.")
    (license license:bsd-2)))

(define-public oniguruma-wasm-for-hermes-shiki
  (package
    (name "oniguruma-wasm-for-hermes-shiki")
    (version "1.7.0")
    (source %vscode-oniguruma-source)
    (build-system gnu-build-system)
    (native-inputs
     (list oniguruma-source-for-hermes-shiki
           python-minimal
           emscripten-for-hermes-yoga
           autoconf automake libtool pkg-config bash-minimal node))
    (arguments
     (list
      #:substitutable? #f
      #:modules '((guix build gnu-build-system) (guix build utils))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          (replace 'build
            (lambda _
              (invoke "python3" #$(local-file "../../scripts/build-hermes-oniguruma-wasm.py")
                      #$source
                      #$(file-append oniguruma-source-for-hermes-shiki
                                     "/share/source/oniguruma.tar.gz")
                      #$output)))
          (replace 'install (lambda _ #t)))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/microsoft/vscode-oniguruma")
    (synopsis "Source-built Oniguruma WebAssembly for Shiki")
    (description "This package rebuilds the Oniguruma WebAssembly module from
the exact Git submodule pinned by vscode-oniguruma 1.7.0, using the repository's
source-built Emscripten toolchain. It retains upstream compile and link options,
licenses and source provenance. Functional validation is deferred.")
    (license (list license:expat license:bsd-2))))

(define %resvg-vendor-manifests
  (list
   (list "resvg-wasm-resvg-Cargo.toml" (local-file "../../planning/resvg-wasm-resvg-Cargo.toml"))
   (list "resvg-wasm-rosvgtree-Cargo.toml" (local-file "../../planning/resvg-wasm-rosvgtree-Cargo.toml"))
   (list "resvg-wasm-svgfilters-Cargo.toml" (local-file "../../planning/resvg-wasm-svgfilters-Cargo.toml"))
   (list "resvg-wasm-usvg-Cargo.toml" (local-file "../../planning/resvg-wasm-usvg-Cargo.toml"))
   (list "resvg-wasm-usvg-text-layout-Cargo.toml" (local-file "../../planning/resvg-wasm-usvg-text-layout-Cargo.toml"))
   (list "resvg-wasm-usvg-writer-Cargo.toml" (local-file "../../planning/resvg-wasm-usvg-writer-Cargo.toml"))))

(define-public resvg-wasm-for-hermes-browser
  (package
    (name "resvg-wasm-for-hermes-browser")
    (version "2.4.0")
    (source %resvg-wasm-source)
    (build-system gnu-build-system)
    (native-inputs
     (list rust-1.93 (list rust-1.93 "cargo") python-minimal lld-17 llvm-23
           rust-sysroot-for-wasm32-unknown-unknown wasm-bindgen-cli-for-hermes-browser
           esbuild-for-hermes))
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
               '#$%resvg-wasm-crate-sources)
              (copy-file #$%resvg-wasm-git-source
                         "guix-source-inputs/resvg-6201182cc109d45eb3596e81dede60783592db90.tar.gz")
              (copy-file #$(local-file "../../planning/resvg-wasm-Cargo.lock") "Cargo.lock")
              (mkdir-p "guix-manifests")
              (for-each
               (match-lambda ((name file) (copy-file file (string-append "guix-manifests/" name))))
               '#$%resvg-vendor-manifests)
              (invoke "python3" #$(local-file "../../scripts/prepare-resvg-wasm.py")
                      "." "guix-source-inputs" "guix-offline-work"
                      "--inventory" #$(local-file "../../planning/hermes-resvg-wasm-source.json")
                      "--manifests" "guix-manifests")
              (copy-recursively #$rust-sysroot-for-wasm32-unknown-unknown "guix-wasm-sysroot")
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
                      (string-append "--sysroot " (getcwd) "/guix-wasm-sysroot -C linker=" (which "wasm-ld")))))
          (replace 'build
            (lambda _
              (invoke "cargo" "build" "--release" "--offline" "--locked"
                      "--target" "wasm32-unknown-unknown")
              (for-each
               (lambda (target)
                 (invoke "wasm-bindgen" "--target" target "--out-name" "index"
                         "--out-dir" (string-append "generated/" target)
                         "target/wasm32-unknown-unknown/release/resvg_js.wasm"))
               '("web" "nodejs"))
              ;; Rebuild the upstream TypeScript wrapper against the generated
              ;; web glue; never pair new wasm with the old bundled npm glue.
              (copy-recursively "generated/web" "wasm/dist")
              (mkdir-p "generated/package")
              (invoke "esbuild" "wasm-binding.ts" "--bundle" "--log-level=error"
                      "--define:import.meta.url=undefined" "--format=cjs"
                      "--outfile=generated/package/index.js")
              (invoke "esbuild" "wasm-binding.ts" "--bundle" "--log-level=error"
                      "--define:import.meta.url=undefined" "--format=esm"
                      "--outfile=generated/package/index.mjs")
              (invoke "esbuild" "wasm-binding.ts" "--bundle" "--log-level=error"
                      "--define:import.meta.url=undefined" "--format=iife"
                      "--minify" "--global-name=resvg"
                      "--outfile=generated/package/index.min.js")
              (copy-file "generated/web/index_bg.wasm" "generated/package/index_bg.wasm")
              (copy-file "wasm/package.json" "generated/package/package.json")
              (copy-file "wasm/index.d.ts" "generated/package/index.d.ts")))
          (replace 'install
            (lambda _
              (copy-recursively "generated" (string-append #$output "/share/resvg-wasm"))
              (copy-recursively "generated/package"
                                (string-append #$output "/lib/node_modules/@resvg/resvg-wasm")))))))
    (supported-systems '("x86_64-linux"))
    (properties '((max-silent-time . 7200)))
    (home-page "https://github.com/yisibl/resvg-js")
    (synopsis "Source-built resvg WebAssembly and matching JavaScript glue")
    (description "This package builds resvg's WebAssembly engine from locked
Rust and Git sources and generates matching web and Node JavaScript bindings.
The upstream TypeScript wrapper is bundled against the matching generated glue.
The npm precompiled WebAssembly payload is not installed.  Next bundle
integration remains a separate build step.")
    (license license:mpl2.0)))

(define-public source-map-wasm-for-hermes-browser
  (package
    (name "source-map-wasm-for-hermes-browser")
    (version "0.5.0")
    (source %source-map-wasm-source)
    (build-system gnu-build-system)
    (native-inputs
     (list rust-1.93 (list rust-1.93 "cargo")
           rust-sysroot-for-wasm32-unknown-unknown lld-17 llvm-23
           python-minimal binaryen))
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
          (add-before 'build 'prepare-offline-sources
            (lambda _
              (mkdir-p "guix-crate-inputs")
              (for-each
               (match-lambda
                 ((identity checksum source)
                  (copy-file source
                             (string-append "guix-crate-inputs/" identity ".crate"))))
               '#$%source-map-wasm-crate-sources)
              (copy-file #$(local-file "../../planning/source-map-wasm-Cargo.lock")
                         "source-map-mappings-wasm-api/Cargo.lock")
              (invoke "python3"
                      #$(local-file "../../scripts/prepare-source-map-wasm.py")
                      "." "guix-crate-inputs" "guix-offline-work")
              (setenv "CARGO_HOME" (string-append (getcwd) "/guix-offline-work/cargo-home"))
              (setenv "CARGO_TARGET_DIR" (string-append (getcwd) "/target"))
              (setenv "CARGO_BUILD_JOBS" "1")
              ;; The channel's WASM rlibs omit archive symbol indexes. Build
              ;; them in a writable copy; LLVM 23 understands the Rust bitcode.
              (copy-recursively #$rust-sysroot-for-wasm32-unknown-unknown
                                "guix-wasm-sysroot")
              (for-each make-file-writable
                        (cons "guix-wasm-sysroot"
                              (find-files "guix-wasm-sysroot" ".*"
                                          #:directories? #t)))
              (for-each
               (lambda (archive)
                 (invoke #$(file-append llvm-23 "/bin/llvm-ranlib") archive))
               (find-files "guix-wasm-sysroot" "\\.rlib$"))
              (setenv "CARGO_TARGET_WASM32_UNKNOWN_UNKNOWN_RUSTFLAGS"
                      (string-append "--sysroot "
                                     (getcwd) "/guix-wasm-sysroot"
                                     " -C linker=" (which "wasm-ld")))))
          (replace 'build
            (lambda _
              (with-directory-excursion "source-map-mappings-wasm-api"
                (invoke "cargo" "build" "--release" "--offline" "--locked"
                        "--target" "wasm32-unknown-unknown"))
              ;; Optimize the complete module, retaining panic code instead of
              ;; the upstream optional function-snipping size optimization.
              (invoke "wasm-opt" "-O3" "-Oz" "--all-features"
                      "target/wasm32-unknown-unknown/release/source_map_mappings_wasm_api.wasm"
                      "-o" "mappings.wasm")))
          (replace 'install
            (lambda _
              (let ((directory (string-append #$output "/share/source-map")))
                (mkdir-p directory)
                (copy-file "mappings.wasm" (string-append directory "/mappings.wasm"))))))))
    (home-page "https://github.com/fitzgen/source-map-mappings")
    (synopsis "Source-built source-map WebAssembly implementation")
    (description "This package builds the source-map-mappings implementation
used by source-map 0.8.0-beta.0 from locked Rust sources.  The complete module is
optimized with Binaryen; no precompiled npm WebAssembly payload is installed.
JavaScript integration and functional validation are separate completion steps.")
    (license (list license:asl2.0 license:expat))))
