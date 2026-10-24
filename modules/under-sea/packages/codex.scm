;;; Codex CLI built offline from exact upstream source dependencies.
(define-module (under-sea packages codex)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (under-sea gexp)
  #:use-module (guix utils)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages rust)
  #:use-module (gnu packages rust-apps)
  #:use-module (gnu packages python)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages protobuf)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages sqlite)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages regex)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages audio)
  #:use-module (gnu packages gstreamer)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages xiph)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages base)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages virtualization)
  #:use-module (gnu packages build-tools)
  #:use-module (under-sea packages codex-zsh)
  #:use-module (under-sea packages codex-icu)
  #:use-module (under-sea packages codex-v8-lock)
  #:use-module (under-sea packages codex-lock))

(define-public codex-base
  (package
    (name "codex-base")
    (version %codex-version)
    (source %codex-source)
    (build-system gnu-build-system)
    (native-inputs (list rust-1.95 (list rust-1.95 "cargo") python-minimal
                         pkg-config cmake-minimal clang-15 protobuf))
    (inputs (list openssl sqlite zlib (list zstd "lib") oniguruma libcap
                  bash-minimal coreutils-minimal git-minimal bubblewrap ripgrep))
    (arguments
     (list
      #:substitutable? #f
      #:modules '((guix build gnu-build-system) (guix build utils)
                  (ice-9 match))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (add-before 'build 'prepare-offline-sources
            (lambda _
              (call-with-output-file "crate-sources.tsv"
                (lambda (port)
                  (for-each (match-lambda
                              ((name checksum source)
                               (format port "~a\t~a\t~a~%" name checksum source)))
                            '#$%codex-crate-sources)))
              (call-with-output-file "git-sources.tsv"
                (lambda (port)
                  (for-each (match-lambda
                              ((identity source)
                               (format port "~a\t~a~%" identity source)))
                            '#$%codex-git-sources)))
              (setenv "CARGO_HOME" (string-append (getcwd) "/guix-cargo-home"))
              (setenv "CARGO_BUILD_JOBS" (number->string (min 4 (parallel-job-count))))
              (setenv "CARGO_PROFILE_RELEASE_DEBUG" "0")
              (setenv "CARGO_PROFILE_RELEASE_LTO" "false")
              (setenv "CARGO_PROFILE_RELEASE_STRIP" "symbols")
              (setenv "CC" "gcc")
              (setenv "CXX" "g++")
              (setenv "AR" "ar")
              (setenv "OPENSSL_NO_VENDOR" "1")
              (setenv "ZSTD_SYS_USE_PKG_CONFIG" "1")
              (setenv "LIBCLANG_PATH" #$(file-append clang-15 "/lib"))
              (setenv "PROTOC" #$(file-append protobuf "/bin/protoc"))
              (setenv "RUSTFLAGS" "-C linker=gcc")
              (invoke "python3" #$(under-sea-script "build-codex.py"))
              (chdir "codex-rs")))
          (replace 'build
            (lambda _
              (invoke "cargo" "build" "--release" "--offline" "--locked"
                      "-p" "codex-cli" "--bin" "codex"
                      "-p" "codex-linux-sandbox" "--bin" "codex-linux-sandbox")))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (invoke "target/release/codex" "--version")
                (invoke "target/release/codex" "--help")
                (invoke "target/release/codex" "exec" "--help")
                (invoke "cargo" "test" "--release" "--offline" "--locked"
                        "-p" "codex-execpolicy" "--lib"))))
          (replace 'install
            (lambda _
              (let ((bin (string-append #$output "/bin")))
                (install-file "target/release/codex" bin)
                (install-file "target/release/codex-linux-sandbox" bin)
                (install-file "../LICENSE" (string-append #$output "/share/doc/codex"))
                (install-file "guix-models-direct.json"
                              (string-append #$output "/share/codex"))
                (call-with-output-file (string-append #$output "/codex-package.json")
                  (lambda (port)
                    (format port "{\"version\":\"~a\"}~%" #$%codex-version)))
                (mkdir-p (string-append #$output "/codex-resources"))
                (symlink #$(file-append bubblewrap "/bin/bwrap")
                         (string-append #$output "/codex-resources/bwrap"))
                (symlink #$(file-append ripgrep "/bin/rg")
                         (string-append #$output "/codex-resources/rg"))
                (wrap-program (string-append bin "/codex")
                  `("PATH" ":" prefix
                    (,#$(file-append bash-minimal "/bin")
                     ,#$(file-append coreutils-minimal "/bin")
                     ,#$(file-append git-minimal "/bin"))))))))))
    (supported-systems '("x86_64-linux"))
    ;; Native linking can remain quiet for a long time even without LTO.
    (properties '((upstream-github "openai/codex")
                  (max-silent-time . 7200)))
    (home-page "https://github.com/openai/codex")
    (synopsis "Codex CLI and Linux sandbox (base package)")
    (description "Codex provides a terminal interface for AI-assisted coding.
This base package builds the CLI and Linux sandbox from source without the
optional V8 code-mode, audio or managed-shell components.  It is the shared
build base for the Codex variants; use the codex package for the complete
installation.  When used standalone, select
share/codex/guix-models-direct.json via model_catalog_json to run in direct
tool mode.")
    (license license:asl2.0)))

;; Keep the native audio host independently buildable: it shares exact Cargo
;; inputs with the CLI but does not require rebuilding the CLI itself.
(define-public codex-voice-host
  (package
    (inherit codex-base)
    (name "codex-voice-host")
    (inputs (modify-inputs (package-inputs codex-base)
              (prepend alsa-lib opus gstreamer gst-plugins-base gst-plugins-good)))
    (arguments
     (substitute-keyword-arguments (package-arguments codex-base)
       ((#:phases phases)
        #~(modify-phases #$phases
            (replace 'build
              (lambda _
                (invoke "cargo" "build" "--release" "--offline" "--locked"
                        "-p" "codex-voice-host" "--bin" "codex-voice-host")))
            ;; Installed-client/audio integration checks are scheduled after
            ;; component completion together with the other packages.
            (delete 'check)
            (replace 'install
              (lambda _
                (let ((bin (string-append #$output "/bin")))
                  (install-file "target/release/codex-voice-host" bin)
                  (install-file "../LICENSE"
                                (string-append #$output "/share/doc/codex-voice-host"))
                  (wrap-program (string-append bin "/codex-voice-host")
                    `("GST_PLUGIN_SYSTEM_PATH" ":" prefix
                      (,#$(file-append gst-plugins-base "/lib/gstreamer-1.0")
                       ,#$(file-append gst-plugins-good "/lib/gstreamer-1.0")))
                    `("GST_PLUGIN_SCANNER" =
                      (,#$(file-append gstreamer "/libexec/gstreamer-1.0/gst-plugin-scanner")))))))))))
    (synopsis "Native audio host for Codex")
    (description "This package builds Codex's native voice host from source,
with Guix GStreamer plugins, ALSA and Opus.  It is a component for the Codex
package resource layout; model and audio integration validation is separate.")))

(define-public codex-with-audio-and-zsh
  (package
    (inherit codex-base)
    (name "codex-with-audio-and-zsh")
    (inputs (modify-inputs (package-inputs codex-base)
              (prepend codex-voice-host codex-zsh)))
    (arguments
     (substitute-keyword-arguments (package-arguments codex-base)
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-after 'install 'install-extra-components
              (lambda _
                (let ((resources (string-append #$output "/codex-resources")))
                  (mkdir-p (string-append resources "/voice/bin"))
                  (mkdir-p (string-append resources "/zsh/bin"))
                  (symlink #$(file-append codex-voice-host "/bin/codex-voice-host")
                           (string-append resources "/voice/bin/codex-voice-host"))
                  (symlink #$(file-append codex-zsh "/bin/zsh")
                           (string-append resources "/zsh/bin/zsh")))))))))
    (synopsis "Codex with native audio and managed zsh")
    (description "Codex provides a terminal interface for AI-assisted coding.
This variant includes the source-built native audio host and patched managed
zsh, without the V8 code-mode host.")))

(define-public codex-code-mode-host
  (package
    (inherit codex-base)
    (name "codex-code-mode-host")
    (inputs (modify-inputs (package-inputs codex-base) (prepend glib)))
    (native-inputs
     (modify-inputs (package-native-inputs codex-base)
       (prepend gn ninja clang-23 llvm-23 clang-runtime-23 codex-icu-data rust-bindgen-cli (list rust "tools"))))
    (arguments
     (substitute-keyword-arguments (package-arguments codex-base)
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-before 'prepare-offline-sources 'configure-source-v8
              (lambda _
                (setenv "V8_FROM_SOURCE" "1")
                ;; Chromium's GN Rust rules use unstable compiler options.
                ;; Enable them on the pinned, source-built Guix compiler.
                (setenv "RUSTC_BOOTSTRAP" "1")
                (setenv "GN" #$(file-append gn "/bin/gn"))
                (setenv "NINJA" #$(file-append ninja "/bin/ninja"))
                (setenv "CLANG_BASE_PATH" #$clang-23)
                (setenv "GUIX_V8_COMPILER_RT" #$clang-runtime-23)
                (setenv "GUIX_V8_LLVM_AR" #$(file-append llvm-23 "/bin/llvm-ar"))
                (setenv "GUIX_V8_ICU_DATA" #$(file-append codex-icu-data "/share/codex-icu/icudtl.dat"))
                (call-with-output-file "v8-crate-sources.tsv"
                  (lambda (port)
                    (for-each
                     (match-lambda
                       ((name checksum source)
                        (format port "~a\t~a\t~a~%" name checksum source)))
                     '#$%codex-v8-crate-sources)))
                (setenv "GUIX_V8_RUST_INVENTORY"
                        #$(under-sea-repo-file "planning/codex-v8-rust-inventory.json"))
                ;; Chromium expects bindgen, rustfmt and libclang in one
                ;; prefix, while Guix keeps these tools in separate outputs.
                (let ((prefix (string-append (getcwd) "/guix-v8-bindgen")))
                  (mkdir-p (string-append prefix "/bin"))
                  ;; The Guix wrapper fixes LIBCLANG_PATH to Clang 18.
                  ;; GN supplies our matching libclang path itself.
                  (symlink #$(file-append rust-bindgen-cli "/bin/.bindgen-real")
                           (string-append prefix "/bin/bindgen"))
                  (symlink #$(file-append (gexp-input rust "tools") "/bin/rustfmt")
                           (string-append prefix "/bin/rustfmt"))
                  (symlink #$(file-append clang-23 "/lib")
                           (string-append prefix "/lib"))
                (setenv "GN_ARGS"
                        (string-append
                         "use_sysroot=false use_custom_libcxx=true use_lld=false "
                         "clang_use_chrome_plugins=false clang_version=\"23\" use_thin_lto=false "
                         "treat_warnings_as_errors=false symbol_level=0 "
                         "rust_sysroot_absolute=\"" #$rust-1.95 "\" "
                         "rustc_version=\"1.95.0\" "
                         "rust_bindgen_root=\"" prefix "\"")))))
            (replace 'build
              (lambda _
                ;; rusty_v8 uses its bundled libc++; Guix's libstdc++ search
                ;; path would intercept libc++'s include_next C headers.
                (setenv "CPLUS_INCLUDE_PATH" (or (getenv "C_INCLUDE_PATH") ""))
                ;; The inherited offline preparation selects Clang 15 for
                ;; ordinary crates. rusty_v8's bundled libc++ needs the same
                ;; modern libclang as its GN compilation and bindings.
                (setenv "LIBCLANG_PATH" #$(file-append clang-23 "/lib"))
                ;; Cargo otherwise buffers the build script's Ninja stdout,
                ;; hiding real V8 compilation progress from Guix's timeout.
                (invoke "cargo" "build" "--release" "--offline" "--locked" "-vv"
                        "-p" "codex-code-mode-host" "--bin" "codex-code-mode-host")))
            (delete 'check)
            (replace 'install
              (lambda _
                (install-file "target/release/codex-code-mode-host"
                              (string-append #$output "/bin"))
                (install-file "../LICENSE"
                              (string-append #$output "/share/doc/codex-code-mode-host"))))))))
    (synopsis "V8 execution host for Codex code mode")
    (description "This component builds Codex's code-mode host and the locked
rusty_v8 engine from source using Guix GN, Ninja, Clang and Rust toolchains.
Runtime protocol validation is scheduled after component completion.")))

(define-public codex
  (package
    (inherit codex-with-audio-and-zsh)
    (name "codex")
    (inputs
     (modify-inputs (package-inputs codex-with-audio-and-zsh)
       (prepend codex-code-mode-host)))
    (arguments
     (substitute-keyword-arguments (package-arguments codex-with-audio-and-zsh)
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-after 'build 'build-release-helpers
              (lambda _
                (invoke "cargo" "build" "--release" "--offline" "--locked"
                        "-p" "codex-responses-api-proxy"
                        "--bin" "codex-responses-api-proxy"
                        "-p" "codex-app-server" "--bin" "codex-app-server")))
            (add-after 'install-extra-components 'install-code-mode-host
              (lambda _
                (symlink #$(file-append codex-code-mode-host "/bin/codex-code-mode-host")
                         (string-append #$output "/codex-resources/codex-code-mode-host"))
                (for-each
                 (lambda (program)
                   (install-file (string-append "target/release/" program)
                                 (string-append #$output "/bin")))
                 '("codex-responses-api-proxy" "codex-app-server"))))))))
    (synopsis "AI-assisted coding CLI and TUI")
    (description "Codex provides a terminal interface for AI-assisted coding.
This package includes the CLI and Linux sandbox, the source-built V8 code-mode
host, the native audio host, and the patched managed zsh.  Components are
installed in the resource layout used by Codex's install-context discovery.
The upstream model catalog remains the default.")))
