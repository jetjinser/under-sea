;;; Exact source-built native bindings for the Hermes Node lock.
(define-module (under-sea packages hermes-node-native)
  #:export (native-binding)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages rust)
  #:use-module (gnu packages python)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages llvm)
  #:use-module (under-sea packages hermes-native-lock)
  #:use-module ((under-sea packages hermes-tailwind-422-lock) #:prefix tailwind422:))

(define (native-binding name version source crates cargo-package library node-name license)
  (package
    (name name)
    (version version)
    (source source)
    (build-system gnu-build-system)
    (native-inputs (list rust-1.95 (list rust-1.95 "cargo") python-minimal
                         pkg-config cmake-minimal clang-15))
    (arguments
     (list
      #:substitutable? #f
      #:modules '((guix build gnu-build-system) (guix build utils) (ice-9 match))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          (add-before 'build 'prepare-native-sources
            (lambda _
              (setenv "CARGO_HOME" (string-append (getcwd) "/cargo-home"))
              (setenv "CARGO_BUILD_JOBS" (number->string (min 2 (parallel-job-count))))
              (setenv "CARGO_PROFILE_RELEASE_DEBUG" "0")
              (setenv "CARGO_PROFILE_RELEASE_LTO" "false")
              (setenv "CC" "gcc")
              (setenv "CXX" "g++")
              (setenv "LIBCLANG_PATH" #$(file-append clang-15 "/lib"))
              (setenv "RUSTFLAGS" "-C linker=gcc")
              (call-with-output-file "crate-sources.tsv"
                (lambda (port)
                  (for-each (match-lambda
                              ((name checksum source)
                               (format port "~a\t~a\t~a~%" name checksum source)))
                            '#$crates)))
              (invoke "python3" #$(local-file "../../scripts/prepare-hermes-native.py"))))
          (replace 'build
            (lambda _
              (invoke "cargo" "build" "--release" "--offline" "--locked"
                      "-p" #$cargo-package)))
          (replace 'install
            (lambda _
              (let ((directory (string-append #$output "/lib/node_modules/" #$node-name)))
                (mkdir-p directory)
                (copy-file (string-append "target/release/" #$library)
                           (string-append directory "/binding.node"))
                (call-with-output-file (string-append directory "/package.json")
                  (lambda (port)
                    (format port "{\"name\":\"~a\",\"version\":\"~a\",\"main\":\"binding.node\"}~%"
                            #$node-name #$version)))))))))
    (supported-systems '("x86_64-linux"))
    (properties '((max-silent-time . 7200)))
    (home-page "https://github.com/NousResearch/hermes-agent")
    (synopsis "Source-built native Node binding for Hermes")
    (description "This component builds an exact native dependency version
from source for Hermes's Node interfaces.  It replaces the npm platform binary
package; interface integration validation is scheduled after component completion.")
    (license license)))

(define-public tailwind-oxide-for-hermes
  (native-binding "tailwind-oxide-for-hermes" "4.3.3"
                  %hermes-tailwind-source %hermes-tailwind-crates
                  "tailwind-oxide" "libtailwind_oxide.so"
                  "@tailwindcss/oxide-linux-x64-gnu" license:expat))

(define-public tailwind-oxide-for-hermes-422
  (native-binding "tailwind-oxide-for-hermes-422" "4.2.2"
                  tailwind422:%hermes-tailwind-source
                  tailwind422:%hermes-tailwind-crates
                  "tailwind-oxide" "libtailwind_oxide.so"
                  "@tailwindcss/oxide-linux-x64-gnu" license:expat))

(define-public rolldown-for-hermes
  (native-binding "rolldown-for-hermes" "1.2.1"
                  %hermes-rolldown-source %hermes-rolldown-crates
                  "rolldown_binding" "librolldown_binding.so"
                  "@rolldown/binding-linux-x64-gnu" license:expat))

(define-public lightningcss-for-hermes
  (native-binding "lightningcss-for-hermes" "1.32.0"
                  %hermes-lightningcss-source %hermes-lightningcss-crates
                  "lightningcss_node" "liblightningcss_node.so"
                  "lightningcss-linux-x64-gnu" license:mpl2.0))
