;;; Loro Python bindings, built from the PyPI source distribution with a
;;; vendored crates.io closure.  This is the optional real-time collaboration
;;; backend for marimo.

(define-module (under-sea packages loro)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system pyproject)
  #:use-module (gnu packages base)
  #:use-module (gnu packages build-tools)
  #:use-module (gnu packages commencement)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages rust)
  #:use-module (under-sea packages loro-lock))

(define-public loro
  (package
    (name "loro")
    (version %loro-version)
    (source %loro-source)
    (build-system pyproject-build-system)
    (native-inputs (list maturin rust (list rust "cargo")
                         pkg-config gcc-toolchain tar))
    (arguments
     (list
      #:tests? #f
      #:modules '((guix build pyproject-build-system)
                  (guix build utils)
                  (ice-9 match))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'unpack-crates
            (lambda _
              (mkdir-p "vendor")
              (for-each
               (match-lambda
                 ((name checksum origin)
                  (let ((destination (string-append "vendor/" name)))
                    (mkdir-p destination)
                    (invoke "tar" "xzf" origin "-C" destination
                            "--strip-components=1")
                    (call-with-output-file
                        (string-append destination "/.cargo-checksum.json")
                      (lambda (port)
                        (format port "{\"files\":{},\"package\":\"~a\"}"
                                checksum))))))
               (list #$@(map (lambda (entry)
                               #~(list #$(car entry) #$(cadr entry)
                                       #$(caddr entry)))
                             %loro-crate-sources)))
              (mkdir-p ".cargo")
              (call-with-output-file ".cargo/config.toml"
                (lambda (port)
                  (display "[source.crates-io]\n\
replace-with = \"vendored-sources\"\n\n\
[source.vendored-sources]\n\
directory = \"vendor\"\n\
[net]\n\
offline = true\n" port)))
              (setenv "CARGO_HOME" (string-append (getcwd) "/cargo-home"))
              (setenv "CARGO_NET_OFFLINE" "true")
              (setenv "CC" "gcc")
              (setenv "RUSTFLAGS" "-C linker=gcc"))))))
    (supported-systems '("x86_64-linux"))
    (properties '((upstream-github "loro-dev/loro-py")))
    (home-page "https://loro.dev/")
    (synopsis "CRDT library with Python bindings")
    (description "Loro is a CRDT library for local-first applications.  This
package builds the Python bindings from the upstream source distribution with
an offline, hash-pinned crates.io closure.")
    (license license:expat)))
