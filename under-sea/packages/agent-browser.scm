;;; agent-browser Rust CLI built offline from exact source dependencies.
(define-module (under-sea packages agent-browser)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages rust)
  #:use-module (gnu packages python)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages commencement)
  #:use-module (under-sea packages agent-browser-lock)
  #:use-module (under-sea packages hermes-agent-browser-dashboard))

(define-public agent-browser
  (package
    (name "agent-browser")
    (version %agent-browser-version)
    (source %agent-browser-source)
    (build-system gnu-build-system)
    (native-inputs (list rust (list rust "cargo") python-minimal pkg-config
                         cmake-minimal perl gcc-toolchain))
    (inputs (list zlib openssl agent-browser-dashboard))
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
              (call-with-output-file "crate-sources.tsv"
                (lambda (port)
                  (for-each (match-lambda
                              ((name checksum source)
                               (format port "~a\t~a\t~a~%" name checksum source)))
                            '#$%agent-browser-crate-sources)))
              (setenv "CARGO_HOME" (string-append (getcwd) "/guix-cargo-home"))
              (setenv "CARGO_BUILD_JOBS" (number->string (min 4 (parallel-job-count))))
              (setenv "CC" "gcc")
              (setenv "CXX" "g++")
              (setenv "AR" "ar")
              (setenv "RUSTFLAGS" "-C linker=gcc")
              (setenv "OPENSSL_NO_VENDOR" "1")
              (invoke "python3"
                      #$(local-file "../../scripts/build-agent-browser.py"))))
          (add-before 'build 'embed-dashboard
            (lambda _
              ;; The CLI embeds ../packages/dashboard/out via rust-embed; install
              ;; the source-built dashboard export so the upstream placeholder
              ;; index.html is not baked in.
              (copy-recursively
               #$(file-append agent-browser-dashboard
                              "/share/agent-browser-dashboard")
               "packages/dashboard/out")))
          (replace 'build
            (lambda _
              (invoke "cargo" "build" "--release" "--offline" "--locked"
                      "--manifest-path" "cli/Cargo.toml" "-p" "agent-browser")))
          (replace 'install
            (lambda _
              (let ((bin (string-append #$output "/bin")))
                (install-file "cli/target/release/agent-browser" bin)
                (install-file "LICENSE"
                              (string-append #$output "/share/doc/agent-browser"))))))))
    (supported-systems '("x86_64-linux"))
    (properties '((max-silent-time . 7200)))
    (home-page "https://github.com/vercel-labs/agent-browser")
    (synopsis "Fast browser automation CLI for AI agents")
    (description "This package builds the agent-browser Rust CLI from source
with an offline, hash-pinned crate vendor, embedding the source-built dashboard
static export in place of the upstream placeholder.  Runtime browsers, drivers
and model credentials are configured separately.  Functional validation is
deferred.")
    (license license:asl2.0)))
