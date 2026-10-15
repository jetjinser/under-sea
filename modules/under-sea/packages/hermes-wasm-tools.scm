;;; Matching source-built WebAssembly generators for Hermes browser resources.
(define-module (under-sea packages hermes-wasm-tools)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (under-sea gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages rust)
  #:use-module (gnu packages python)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages tls)
  #:use-module (under-sea packages wasm-bindgen-cli-lock))

(define %mio-source
  (cadr (assoc "git+https://github.com/guybedford/mio?tag=1.2.3-cf.emscripten#0788dbb67883cb6191503af999471def54e3fb77"
               %wasm-bindgen-cli-git-sources)))
(define %tokio-source
  (cadr (assoc "git+https://github.com/guybedford/tokio?tag=1.53.1-cf.emscripten#7227f2d72739c3bc9821074cc704e7582be92907"
               %wasm-bindgen-cli-git-sources)))

(define-public wasm-bindgen-cli-for-hermes-browser
  (package
    (name "wasm-bindgen-cli-for-hermes-browser")
    (version "0.2.129")
    (source %wasm-bindgen-cli-source)
    (build-system gnu-build-system)
    (native-inputs (list rust-1.93 (list rust-1.93 "cargo")
                         python-minimal pkg-config))
    (inputs (list openssl))
    (arguments
     (list
      #:substitutable? #f
      #:modules '((guix build gnu-build-system) (guix build utils) (ice-9 match))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          (add-before 'build 'prepare-offline-workspace
            (lambda _
              (invoke "python3" #$(under-sea-script "scope-wasm-bindgen-cli.py")
                      "." #$(under-sea-repo-file "planning/wasm-bindgen-cli-scoped-Cargo.lock")
                      "--original-lock"
                      #$(under-sea-repo-file "planning/wasm-bindgen-cli-Cargo.lock"))
              (mkdir-p "guix-source-inputs")
              (for-each
               (match-lambda
                 ((identity checksum source)
                  (copy-file source (string-append "guix-source-inputs/" identity ".crate"))))
               '#$%wasm-bindgen-cli-crate-sources)
              (copy-file #$%tokio-source
                         "guix-source-inputs/guybedford-tokio-7227f2d72739c3bc9821074cc704e7582be92907.tar.gz")
              (invoke "python3" #$(under-sea-script "prepare-wasm-bindgen-vendor.py")
                      "." "guix-source-inputs" "guix-offline-work"
                      "--inventory" #$(under-sea-repo-file "planning/hermes-wasm-bindgen-cli-source.json")
                      "--tokio-manifest" #$(under-sea-repo-file "planning/wasm-bindgen-cli-tokio-Cargo.toml"))
              (invoke "python3" #$(under-sea-script "prepare-wasm-bindgen-mio.py")
                      #$%mio-source
                      "b5dc36d23de733fd129750fc4d1f7b9e4940a1696ff927d99f1df22325a697dc"
                      "guix-offline-work/mio" "guix-offline-work/cargo-home/config.toml")
              (setenv "CARGO_HOME" (string-append (getcwd) "/guix-offline-work/cargo-home"))
              (setenv "CARGO_TARGET_DIR" (string-append (getcwd) "/target"))
              (setenv "CARGO_BUILD_JOBS" "1")
              (setenv "CC" "gcc")
              (setenv "CXX" "g++")
              (setenv "CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER" "gcc")))
          (replace 'build
            (lambda _
              (invoke "cargo" "build" "--release" "--offline" "--locked"
                      "-p" "wasm-bindgen-cli" "--bins")))
          (replace 'install
            (lambda _
              (let ((bin (string-append #$output "/bin")))
                (mkdir-p bin)
                (for-each
                 (lambda (name)
                   (copy-file (string-append "target/release/" name)
                              (string-append bin "/" name)))
                 '("wasm-bindgen" "wasm-bindgen-test-runner" "wasm2es6js"))))))))
    (supported-systems '("x86_64-linux"))
    (properties '((max-silent-time . 7200)))
    (home-page "https://github.com/wasm-bindgen/wasm-bindgen")
    (synopsis "Matching source-built wasm-bindgen CLI for Hermes browser")
    (description "This package builds all three wasm-bindgen CLI programs
from fixed source inputs.  Its version matches Hermes browser's source-built
resvg bindings.  Registry and patched Git sources are prepared for offline
Cargo without fetching a binary generator or relying on a developer Git cache.")
    (license (list license:asl2.0 license:expat))))
