;;; Pi coding agent built from the locked npm source closure with source-built natives.
(define-module (under-sea packages pi)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (under-sea gexp)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system trivial)
  #:use-module (gnu packages node)
  #:use-module (gnu packages python)
  #:use-module (gnu packages xorg)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages bash)
  #:use-module (under-sea packages bun)
  #:use-module (under-sea packages pi-lock)
  #:use-module (under-sea packages pi-node-lock)
  #:use-module (under-sea packages hermes-esbuild)
  #:use-module (under-sea packages hermes-quickjs-wasi)
  #:use-module (under-sea packages hermes-photon-wasm)
  #:use-module (under-sea packages hermes-undici)
  #:use-module (under-sea packages hermes-node-native))

(define %pi-typescript
  ;; TS 7 ships only a native Go compiler binary; substitute the self-contained
  ;; JavaScript compiler so the build stays pure source without native payloads.
  (origin
    (method url-fetch)
    (uri "https://registry.npmjs.org/typescript/-/typescript-5.9.2.tgz")
    (file-name "typescript-5.9.2.tgz")
    (sha256
     (base16-string->bytevector
      "67a3bc82e822b8f45f653a80fc3a9730d23214d36c83ba85dd7f5abebee82062"))))

(define-public pi
  (package
    (name "pi")
    (version %pi-version)
    (source %pi-source)
    (build-system gnu-build-system)
    (native-inputs (list node python-minimal patchelf))
    (inputs (list node bash-minimal esbuild-for-hermes-0282 lightningcss-for-hermes
                  quickjs-wasi-for-hermes photon-wasm-for-hermes-node
                  undici-for-hermes libxcb))
    (arguments
     (list
      #:substitutable? #f
      #:modules '((guix build gnu-build-system) (guix build utils) (ice-9 match))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          (replace 'build
            (lambda* (#:key inputs #:allow-other-keys)
              (setenv "NODE_ENV" "production")
              (setenv "NEXT_TELEMETRY_DISABLED" "1")
              ;; Materialize the locked archives into the exact on-disk npm
              ;; layout, replacing native platform payloads with source builds.
              (call-with-output-file "guix-archive-paths.tsv"
                (lambda (port)
                  (for-each
                   (match-lambda
                     ((path version source)
                      (format port "~a\t~a~%" path source)))
                   '#$%pi-node-sources)))
              (let ((typescript "providers/typescript")
                    (esbuild "providers/@esbuild/linux-x64"))
                (mkdir-p typescript)
                (invoke "tar" "xf" #$%pi-typescript "-C" typescript
                        "--strip-components=1")
                (mkdir-p (string-append esbuild "/bin"))
                (symlink #$(file-append esbuild-for-hermes-0282 "/bin/esbuild")
                         (string-append esbuild "/bin/esbuild"))
                (call-with-output-file (string-append esbuild "/package.json")
                  (lambda (port)
                    (display "{\"name\":\"@esbuild/linux-x64\",\"version\":\"0.28.2\",\"os\":[\"linux\"],\"cpu\":[\"x64\"]}\n"
                             port))))
              (call-with-output-file "guix-providers.json"
                (lambda (port)
                  (display "{" port)
                  (let ((first? #t))
                    (for-each
                     (match-lambda
                       ((path . source)
                        (unless first? (display "," port))
                        (set! first? #f)
                        (format port "~s:~s" path source)))
                     `(("node_modules/typescript"
                        . ,(string-append (getcwd) "/providers/typescript"))
                       ("node_modules/@esbuild/linux-x64"
                        . ,(string-append (getcwd) "/providers/@esbuild/linux-x64"))
                       ("node_modules/lightningcss-linux-x64-gnu"
                        . ,(string-append (assoc-ref inputs "lightningcss-for-hermes")
                                          "/lib/node_modules/lightningcss-linux-x64-gnu"))
                       ("node_modules/quickjs-wasi"
                        . ,(string-append (assoc-ref inputs "quickjs-wasi-for-hermes")
                                          "/lib/node_modules/quickjs-wasi"))
                       ("node_modules/@silvia-odwyer/photon-node"
                        . ,(string-append (assoc-ref inputs "photon-wasm-for-hermes-node")
                                          "/lib/node_modules/@silvia-odwyer/photon-node"))
                       ("node_modules/undici"
                        . ,(string-append (assoc-ref inputs "undici-for-hermes")
                                          "/lib/node_modules/undici"))))
                    (display "}" port))))
              (invoke "python3"
                      #$(under-sea-script "assemble-pi-node.py")
                      #$(under-sea-repo-file "planning/pi-node-inventory.json")
                      (getcwd)
                      "--archive-paths" "guix-archive-paths.tsv"
                      "--providers" "guix-providers.json")
              ;; Node scripts materialized during assembly still carry
              ;; `#!/usr/bin/env` shebangs; the build sandbox has no /usr/bin,
              ;; so re-run the standard shebang patcher over the tree.
              ((assoc-ref %standard-phases 'patch-source-shebangs)
               #:inputs inputs)
              ;; Build every workspace package from source (TypeScript + esbuild).
              (invoke "npm" "run" "build:offline")
              ;; Replace the shipped prebuilt TUI native addons with a source
              ;; build of the Linux X11 clipboard helper.
              (for-each delete-file-recursively
                        '("packages/tui/native/linux/prebuilds"
                          "packages/tui/native/darwin/prebuilds"
                          "packages/tui/native/win32/prebuilds"))
              (setenv "CC" "gcc")
              (invoke "sh" "packages/tui/native/linux/build.sh")
              (invoke "patchelf" "--set-rpath"
                      (string-append (assoc-ref inputs "libxcb") "/lib")
                      "packages/tui/native/linux/prebuilds/linux-x64/linux-platform-x11.node")))
          (replace 'install
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((prefix (string-append #$output "/lib/pi"))
                    (bin (string-append #$output "/bin")))
                (mkdir-p prefix)
                (copy-recursively "node_modules"
                                  (string-append prefix "/node_modules"))
                (copy-recursively "packages"
                                  (string-append prefix "/packages"))
                (mkdir-p bin)
                ;; Wrap the CLI so it runs with the packaged Node rather than
                ;; relying on `#!/usr/bin/env node' being resolvable.
                (let ((wrapper (string-append bin "/pi")))
                  (call-with-output-file wrapper
                    (lambda (port)
                      (display
                       (string-append
                        "#!" (assoc-ref inputs "bash-minimal") "/bin/bash\n"
                        "exec " (assoc-ref inputs "node") "/bin/node "
                        prefix "/packages/coding-agent/dist/bundle/cli.js \"$@\"\n")
                       port)))
                  (chmod wrapper #o555)))))
          (add-after 'install 'smoke
            (lambda* (#:key outputs #:allow-other-keys)
              (invoke (string-append (assoc-ref outputs "out") "/bin/pi")
                      "--version"))))))
    (supported-systems '("x86_64-linux"))
    (properties '((upstream-github "earendil-works/pi")
                  (max-silent-time . 7200)))
    (home-page "https://github.com/earendil-works/pi")
    (synopsis "Pi coding agent built from source")
    (description "This package assembles Pi's locked npm dependency closure
offline, replaces native platform payloads with source-built components, and
builds every workspace package from TypeScript source with the source-built
esbuild, installing the coding-agent CLI as @command{pi}.")
    (license license:asl2.0)))

;; PD2: a single-file Pi executable produced by bun's compiler from the
;; already source-built workspace, mirroring upstream scripts/build-binaries.sh.
(define-public pi-standalone
  (package
    (name "pi-standalone")
    (version %pi-version)
    (source #f)
    (build-system trivial-build-system)
    (inputs (list pi bun-for-hermes bash-minimal))
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let* ((out (assoc-ref %outputs "out"))
                 (pi (assoc-ref %build-inputs "pi"))
                 (bun (assoc-ref %build-inputs "bun-for-hermes"))
                 (bash (assoc-ref %build-inputs "bash-minimal"))
                 (root (string-append pi "/lib/pi"))
                 (coding-agent (string-append root "/packages/coding-agent"))
                 (app (string-append out "/lib/pi-standalone")))
            (mkdir-p app)
            (with-directory-excursion coding-agent
              (invoke (string-append bun "/bin/bun") "build" "--compile"
                      "--no-compile-autoload-bunfig"
                      "./dist/bun/cli.js"
                      "./src/utils/image-resize-worker.ts"
                      "./src/extensions/codemode/worker.ts"
                      "--outfile" (string-append app "/pi")))
            ;; Mirror upstream scripts/build-binaries.sh asset layout so the
            ;; standalone executable finds theme/assets/export-html/wasm/native.
            (for-each
             (lambda (f)
               (let ((src (string-append coding-agent "/" f)))
                 (when (file-exists? src)
                   (copy-file src (string-append app "/" f)))))
             '("package.json" "README.md" "CHANGELOG.md"))
            (for-each
             (lambda (spec)
               (let ((src (string-append coding-agent "/" (car spec))))
                 (when (file-exists? src)
                   (copy-recursively src (string-append app "/" (cdr spec))))))
             '(("dist/modes/interactive/theme" . "theme")
               ("dist/modes/interactive/assets" . "assets")
               ("dist/core/export-html" . "export-html")
               ("docs" . "docs")
               ("examples" . "examples")))
            (let ((wasm (string-append root
                                       "/node_modules/@silvia-odwyer/photon-node/photon_rs_bg.wasm")))
              (when (file-exists? wasm)
                (copy-file wasm (string-append app "/photon_rs_bg.wasm"))))
            (let ((native (string-append root
                                         "/packages/tui/native/linux/prebuilds/linux-x64")))
              (when (file-exists? native)
                (copy-recursively native
                                  (string-append app "/native/linux/prebuilds/linux-x64"))))
            ;; Run from the asset directory so relative paths resolve.
            (mkdir-p (string-append out "/bin"))
            (let ((wrapper (string-append out "/bin/pi")))
              (call-with-output-file wrapper
                (lambda (port)
                  (display (string-append "#!" bash "/bin/bash\n"
                                          "cd " app "\n"
                                          "exec ./pi \"$@\"\n")
                           port)))
              (chmod wrapper #o555))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/earendil-works/pi")
    (synopsis "Single-file Pi coding agent (bun standalone)")
    (description "This package compiles the source-built Pi coding agent into a
single self-contained executable with bun, following upstream's
@file{build-binaries.sh} entrypoints and worker layout.")
    (license license:asl2.0)))
