(define-module (under-sea packages hermes-react-rollup)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (under-sea gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages rust)
  #:use-module (gnu packages python)
  #:use-module (gnu packages cmake)
  #:use-module (under-sea packages hermes-react-rollup-lock)
  #:use-module ((under-sea packages hermes-react-rollup-bootstrap-lock) #:prefix bootstrap:))

(define (rollup-source-binding name version source crates)
  (package
    (name name)
    (version version)
    (source source)
    (build-system gnu-build-system)
    (native-inputs (list rust-1.95 (list rust-1.95 "cargo") python-minimal cmake-minimal))
    (arguments
     (list
      #:substitutable? #f
      #:modules '((guix build gnu-build-system) (guix build utils) (ice-9 match))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          (add-before 'build 'prepare-offline-crates
            (lambda _
              (copy-file "LICENSE.md" "rust/LICENSE.md")
              (copy-file "npm/linux-x64-gnu/package.json" "rust/platform-package.json")
              (chdir "rust")
              (call-with-output-file "crate-sources.tsv"
                (lambda (port)
                  (for-each
                   (match-lambda
                     ((name checksum source)
                      (format port "~a\t~a\t~a~%" name checksum source)))
                   '#$crates)))
              (setenv "CARGO_HOME" (string-append (getcwd) "/guix-cargo-home"))
              (setenv "CARGO_BUILD_JOBS" "1")
              (setenv "CC" "gcc")
              (setenv "CXX" "g++")
              (setenv "CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER" "gcc")
              (invoke "python3" #$(under-sea-script "prepare-hermes-native.py"))))
          (replace 'build
            (lambda _
              (invoke "cargo" "build" "--release" "--offline" "--locked"
                      "-p" "bindings_napi")))
          (replace 'install
            (lambda _
              (let ((module (string-append #$output
                             "/lib/node_modules/@rollup/rollup-linux-x64-gnu")))
                (mkdir-p module)
                (copy-file "target/release/libbindings_napi.so"
                           (string-append module "/rollup.linux-x64-gnu.node"))
                (copy-file "LICENSE.md" (string-append module "/LICENSE.md"))
                (copy-file "Cargo.lock" (string-append module "/Cargo.lock"))
                (invoke "python3" "-c"
                        "import json,sys; d=json.load(open('platform-package.json')); assert d['name']=='@rollup/rollup-linux-x64-gnu'; d['version']=sys.argv[2]; json.dump(d,open(sys.argv[1],'w'),indent=2)"
                        (string-append module "/package.json") #$version)))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://rollupjs.org")
    (synopsis "Source-built Rollup native binding for React Compiler")
    (description "This package builds the matching Rollup Linux x64 native
binding from its authored Rust workspace and locked source dependencies, retaining
release LTO. JavaScript framework compilation and functional validation are
separate steps.")
    (license license:expat)))

(define-public rollup-binding-for-hermes-react-compiler
  (rollup-source-binding "rollup-binding-for-hermes-react-compiler" "4.34.9"
                        %hermes-rollup-source %hermes-rollup-crates))

(define-public rollup-binding-for-hermes-react-bootstrap
  (rollup-source-binding "rollup-binding-for-hermes-react-bootstrap" "4.34.8"
                        bootstrap:%hermes-rollup-source bootstrap:%hermes-rollup-crates))
