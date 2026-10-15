;;; Matching Next SWC/Turbopack binding built from locked upstream sources.
(define-module (under-sea packages hermes-next-native)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (under-sea gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages rust)
  #:use-module (gnu packages python)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages assembly)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages compression)
  #:use-module (under-sea packages next-native-lock)
  #:use-module ((under-sea packages next-1608-native-lock) #:prefix analyzer:))

(define %next-native-features
  "plugin,image-extended,tracing/release_max_level_trace")

(define (next-swc-source-package name version source crates git-sources commit)
  (package
    (name name)
    (version version)
    (source source)
    (build-system gnu-build-system)
    (native-inputs (list rust-1.95 (list rust-1.95 "cargo") python
                         clang-15 nasm cmake-minimal pkg-config))
    (inputs (list openssl zlib))
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
              (call-with-output-file "crate-sources.tsv"
                (lambda (port)
                  (for-each
                    (match-lambda
                      ((name checksum source)
                       (format port "~a\t~a\t~a~%" name checksum source)))
                    '#$crates)))
              (call-with-output-file "git-sources.tsv"
                (lambda (port)
                  (for-each
                    (match-lambda
                      ((identity source)
                       (format port "~a\t~a~%" identity source)))
                    '#$git-sources)))
              (setenv "RUSTC_BOOTSTRAP" "1")
              ;; Match upstream release CI while preserving truthful dirty
              ;; metadata and a distinct identity for the packaging patches.
              (setenv "CI" "1")
              (setenv "CARGO_BUILD_JOBS" "1")
              (setenv "CARGO_HOME" (string-append (getcwd) "/guix-cargo-home"))
              (setenv "CARGO_TARGET_DIR" (string-append (getcwd) "/target"))
              (setenv "CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER" "gcc")
              (setenv "CC" "gcc")
              (setenv "CXX" "g++")
              (setenv "LIBCLANG_PATH" #$(file-append clang-15 "/lib"))
              (invoke "python3" #$(under-sea-script "prepare-next-native.py")
                      "--rust-patch" #$(under-sea-script "patch-next-rust.py")
                      "--vendor-patch" #$(under-sea-script "patch-next-vendor.py")
                      "." "." "guix-next-work" "--source-commit"
                      #$commit
                      "--features" #$%next-native-features)))
          (replace 'build
            (lambda _
              (invoke "cargo" "build" "--release" "--offline" "--locked"
                      "-p" "next-swc-napi" "--features"
                      #$%next-native-features)))
          (replace 'install
            (lambda _
              (let ((module (string-append #$output
                             "/lib/node_modules/@next/swc-linux-x64-gnu")))
                (mkdir-p module)
                (copy-file "target/release/libnext_swc_napi.so"
                           (string-append module "/next-swc.linux-x64-gnu.node"))
                (copy-file "license.md" (string-append module "/LICENSE"))
                (copy-file "guix-next-work/source-identity.json"
                           (string-append module "/source-identity.json"))
                (call-with-output-file (string-append module "/package.json")
                  (lambda (port)
                    (format port "{\"name\":\"@next/swc-linux-x64-gnu\",\"version\":\"~a\",\"main\":\"next-swc.linux-x64-gnu.node\",\"os\":[\"linux\"],\"cpu\":[\"x64\"]}~%"
                            #$version)))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/vercel/next.js")
    (synopsis "Source-built Next SWC and Turbopack Node binding")
    (description "This package builds the matching Linux Next SWC/Turbopack
binding from source with plugin and image codec support, using locked registry
and Git sources for offline compilation.")
    (license license:expat)))

(define-public next-swc-for-hermes-browser
  (next-swc-source-package "next-swc-for-hermes-browser"
                          %next-native-version %next-native-source
                          %next-native-crate-sources %next-native-git-sources
                          "3aa53984e9d6bc4b5860c76e90cccfd6780989af"))

;; The analyzer workspace locks this framework version independently of the
;; final Next 16.1.1 framework. Preserve its exact source and native graph.
(define-public next-swc-for-hermes-analyzer-bootstrap
  (next-swc-source-package "next-swc-for-hermes-analyzer-bootstrap"
                          analyzer:%next-native-version analyzer:%next-native-source
                          analyzer:%next-native-crate-sources analyzer:%next-native-git-sources
                          "817ee56da939545d4b77cc54542f4c45a524e60a"))
