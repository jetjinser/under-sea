;;; Source-built WASI standard library for Next's SWC error-code plugin.
(define-module (under-sea packages hermes-next-wasi)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (under-sea gexp)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages rust)
  #:use-module (gnu packages web)
  #:use-module (gnu packages python)
  #:use-module (gnu packages llvm))

(define-public rust-sysroot-for-wasm32-unknown-unknown
  (package
    (name "rust-sysroot-for-wasm32-unknown-unknown")
    (version (package-version rust-1.93))
    (source (package-source rust-1.93))
    (build-system gnu-build-system)
    (native-inputs
     (list rust-1.93 (list rust-1.93 "cargo")))
    (arguments
     (list
      #:substitutable? #f
      #:tests? #f
      #:modules '((guix build gnu-build-system) (guix build utils)
                  (ice-9 popen) (ice-9 rdelim) (ice-9 textual-ports)
                  (ice-9 regex) (ice-9 ftw))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          ;; The rust source tree is only read by the toolchain; skip the
          ;; expensive full-tree shebang rewrites.
          (delete 'patch-source-shebangs)
          (delete 'patch-generated-file-shebangs)
          (replace 'configure
            (lambda _
              (let* ((rustc (which "rustc"))
                     (rust-prefix (dirname (dirname rustc)))
                     (sysroot-root (getcwd))
                     (sysroot (string-append sysroot-root "/sysroot"))
                     (host
                      (let ((port (open-input-pipe (string-append rustc " -vV"))))
                        (dynamic-wind
                          (const #t)
                          (lambda ()
                            (let loop ()
                              (let ((line (read-line port)))
                                (cond ((eof-object? line)
                                       (error "rustc -vV: missing host tuple"))
                                      ((string-match "^host: (.*)" line)
                                       => (lambda (m) (match:substring m 1)))
                                      (else (loop))))))
                          (lambda () (close-pipe port))))))
                (setenv "RUSTC_BOOTSTRAP" "1")
                (mkdir-p "guix-cargo-home")
                (setenv "CARGO_HOME" (string-append sysroot-root "/guix-cargo-home"))
                ;; cargo build-std discovers the std sources below the sysroot
                ;; reported by "rustc --print sysroot"; assemble a writable
                ;; skeleton that exposes the unpacked source tree plus the
                ;; host std needed for host build-script compilations.
                (mkdir-p (string-append sysroot "/lib/rustlib/src"))
                (symlink sysroot-root (string-append sysroot "/lib/rustlib/src/rust"))
                (mkdir-p (string-append sysroot "/lib/rustlib/" host))
                (symlink (string-append rust-prefix "/lib/rustlib/" host "/lib")
                         (string-append sysroot "/lib/rustlib/" host "/lib"))
                (call-with-output-file "guix-rustc"
                  (lambda (port)
                    (format port "#!~a
exec ~a --sysroot ~a \"$@\"~%"
                            (or (which "bash") (error "bash not found in PATH"))
                            rustc sysroot)))
                (chmod "guix-rustc" #o555)
                (setenv "RUSTC" (string-append sysroot-root "/guix-rustc"))
                ;; The vendored-source replacement comes from the rust source
                ;; tree's own .cargo/config.toml.  Keep this overlay free of
                ;; build paths: configure-hermes-wasi.py requires the target
                ;; triple to appear exactly twice so it can rewrite both into
                ;; the WASI preview-one equivalents.
                (call-with-output-file "config.toml"
                  (lambda (port)
                    (format port "[unstable]
build-std = [\"std\", \"panic_abort\"]
build-std-features = [\"std_detect_file_io\", \"std_detect_dlsym_getauxval\"]

[build]
target = [\"wasm32-unknown-unknown\"]

[target.wasm32-unknown-unknown]
")))
                ;; An anchor crate detached from the rust workspace manifest;
                ;; build-std compiles the standard library as its dependency.
                (mkdir-p "guix-anchor/src")
                (call-with-output-file "guix-anchor/Cargo.toml"
                  (lambda (port)
                    (format port "[package]
name = \"guix-sysroot-anchor\"
version = \"0.0.0\"
edition = \"2021\"

[workspace]
")))
                (call-with-output-file "guix-anchor/src/lib.rs"
                  (lambda (port) (display "" port))))))
          (replace 'build
            (lambda _
              (let* ((root (getcwd))
                     (config (string-append root "/config.toml"))
                     (cargo-config (string-append root "/config-cargo.toml")))
                ;; cargo parses every unknown key of a target table as a
                ;; links override and rejects strings; the wasi-root entry
                ;; recorded by configure-hermes-wasi.py is ignored by cargo
                ;; itself and only kept for install-time bookkeeping, so
                ;; hide it from the cargo view of the configuration.
                (call-with-output-file cargo-config
                  (lambda (out)
                    (call-with-input-file config
                      (lambda (in)
                        (let loop ()
                          (let ((line (read-line in 'concat)))
                            (unless (eof-object? line)
                              (unless (string-prefix?
                                       "wasi-root"
                                       (string-trim line))
                                (display line out))
                              (loop))))))))
                (with-directory-excursion "guix-anchor"
                  (invoke "cargo" "build" "--offline" "--release"
                          "--config" cargo-config)))))
          (delete 'check)
          (replace 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (config-text
                      (call-with-input-file "config.toml" get-string-all))
                     (wasi-root
                      (let ((match (string-match
                                    "wasi-root = \"([^\"]+)\"" config-text)))
                        (and match (match:substring match 1))))
                     (triples
                      (scandir "guix-anchor/target"
                               (lambda (entry)
                                 (and (not (string-prefix? "." entry))
                                      (file-exists?
                                       (string-append "guix-anchor/target/"
                                                      entry
                                                      "/release/deps")))))))
                (for-each
                 (lambda (triple)
                   (let* ((deps (string-append "guix-anchor/target/" triple
                                               "/release/deps"))
                          (lib (string-append out "/lib/rustlib/" triple
                                              "/lib")))
                     (mkdir-p lib)
                     (for-each
                      (lambda (artifact)
                        (unless (string-contains (basename artifact)
                                                 "guix_sysroot_anchor")
                          (copy-file artifact
                                     (string-append lib "/"
                                                    (basename artifact)))))
                      (append (find-files deps "\\.rlib$")
                              (find-files deps "\\.rmeta$")))))
                 triples)
                ;; A WASI variant's configure records its libc view in
                ;; config.toml; make the installed sysroot self-contained so
                ;; consumers linking with only --sysroot and a wasm linker
                ;; find the target libc archives.
                (when wasi-root
                  (let* ((wasi-view (string-append wasi-root
                                                   "/lib/wasm32-wasip1"))
                         ;; find-files lstats the root and does not descend
                         ;; into symlinks; resolve the libc view symlink to
                         ;; its real directory first.
                         (wasi-lib (false-if-exception
                                    (canonicalize-path wasi-view)))
                         (lib (string-append out "/lib/rustlib/"
                                            "wasm32-wasip1/lib"))
                         ;; rustc's self-contained WASI linking adds only
                         ;; the self-contained directory to the library
                         ;; search path, so expose the target libc there.
                         (self-contained
                          (string-append lib "/self-contained")))
                    (when wasi-lib
                      (mkdir-p lib)
                      (for-each
                       (lambda (file)
                         (install-file file lib)
                         (install-file file self-contained))
                       (find-files wasi-lib "\\.(a|o)$")))))
                #t)))
          (delete 'strip))))
    (supported-systems '("x86_64-linux"))
    (properties '((max-silent-time . 7200) (timeout . 72000)))
    (home-page "https://www.rust-lang.org")
    (synopsis "Source-built Rust standard library for wasm32-unknown-unknown")
    (description "This package compiles the channel's pinned Rust 1.93
standard library for the wasm32-unknown-unknown target from the compiler
source tree with cargo build-std, producing a sysroot directory layout of
target rlibs under @file{lib/rustlib/wasm32-unknown-unknown/lib}.  It lets
WebAssembly crates build against a source-built standard library without
rustup or precompiled target libraries.")
    (license (list license:asl2.0 license:expat))))

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
                (invoke "python3" #$(under-sea-script "configure-hermes-wasi.py")
                        "config.toml" #$(file-append wasi-libc "/share/wasi-sysroot"))))))))
    (synopsis "Source-built Rust WASI preview-one standard library for Next")
    (description "This package builds the channel's Rust 1.93 standard library
for wasm32-wasip1 using source-built WASI libc.  It supplies the matching sysroot
needed to rebuild Next's error-code SWC WebAssembly plugin without rustup
or precompiled target libraries.  Plugin compilation and framework integration
are separate packages.")))
