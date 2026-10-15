;;; Build the Next framework from its authored source and locked module graph.
(define-module (under-sea packages hermes-next-framework)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (under-sea gexp)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages node)
  #:use-module (gnu packages python)
  #:use-module (gnu packages bash)
  #:use-module (under-sea packages hermes-next-node)
  #:use-module (under-sea packages hermes-next-swc-core)
  #:use-module (under-sea packages hermes-next-node-lock)
  #:use-module (under-sea packages hermes-satori)
  #:use-module (under-sea packages hermes-vercel-og)
  #:use-module (under-sea packages next-native-lock))

(define %next-type-origins
  ;; Root devDependencies the staged module graph omits, but the authored
  ;; tsconfig (`$$compiled.internal.d.ts`, optional CSS optimizer) needs.
  (list
   (list "critters@0.0.6"
     (origin (method url-fetch)
       (uri "https://registry.npmjs.org/critters/-/critters-0.0.6.tgz")
       (file-name "next-critters-0.0.6.tgz")
       (sha256 (base16-string->bytevector "dea538238b3b447db8166fbd076e7906436ead4a44e33506d71cfa756853a525"))))
   (list "@types/busboy@1.5.3"
     (origin (method url-fetch)
       (uri "https://registry.npmjs.org/@types/busboy/-/busboy-1.5.3.tgz")
       (file-name "next-types-busboy-1.5.3.tgz")
       (sha256 (base16-string->bytevector "e187c4a57dc826033cb267c597a3631a6d90923656541da8264ba467d601c64a"))))
   (list "@types/http-proxy@1.17.3"
     (origin (method url-fetch)
       (uri "https://registry.npmjs.org/@types/http-proxy/-/http-proxy-1.17.3.tgz")
       (file-name "next-types-http-proxy-1.17.3.tgz")
       (sha256 (base16-string->bytevector "20aa59edd8a3f3f6e0e62e54eb18a2ffc8000ce5e9d9794b0f6843954022c4b7"))))
   (list "@types/trusted-types@2.0.3"
     (origin (method url-fetch)
       (uri "https://registry.npmjs.org/@types/trusted-types/-/trusted-types-2.0.3.tgz")
       (file-name "next-types-trusted-types-2.0.3.tgz")
       (sha256 (base16-string->bytevector "c78f9df96d26ba8972c7a3f2d705d0a42bd1c41f9e6d50df727026f0b0ea20ac"))))
   (list "@types/string-hash@1.1.1"
     (origin (method url-fetch)
       (uri "https://registry.npmjs.org/@types/string-hash/-/string-hash-1.1.1.tgz")
       (file-name "next-types-string-hash-1.1.1.tgz")
       (sha256 (base16-string->bytevector "0041b8dc0c44cbd9a19b7cd5151aba366f36a1879d945e59ae958dcfe76fc12f"))))))

(define-public next-framework-for-hermes
  (package
    (name "next-framework-for-hermes")
    (version %next-native-version)
    (source %next-native-source)
    (build-system gnu-build-system)
    (native-inputs (list node python-minimal))
    (inputs (list next-source-build-modules next-1608-task-source-build-modules
                  vercel-og-for-hermes-browser satori-for-hermes-browser))
    (arguments
     (list
      #:substitutable? #f
      #:modules '((guix build gnu-build-system) (guix build utils))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          (add-after 'unpack 'make-source-writable
            (lambda _
              ;; src/compiled ships read-only files; copy_ncced preserves the mode
              ;; and later ncc tasks cannot overwrite them.
              (invoke "chmod" "-R" "u+w" "packages/next/src/compiled")))
          (add-after 'unpack 'patch-devtools-aliases
            (lambda _
              (invoke "python3"
                      #$(under-sea-script "patch-next-webpack-aliases.py")
                      ".")))
          (add-after 'patch-devtools-aliases 'patch-unused-expect-error
            (lambda _
              (invoke "python3"
                      #$(under-sea-script "patch-next-middleware-webpack.py")
                      ".")))
          (add-after 'patch-unused-expect-error 'patch-export-request-store
            (lambda _
              (invoke "python3"
                      #$(under-sea-script "patch-next-export-request-store.py")
                      ".")))
          (add-after 'unpack 'stage-modules
            (lambda _
              (invoke "python3"
                      #$(under-sea-script "stage-hermes-next-modules.py")
                      "."
                      #$(file-append next-source-build-modules "/lib/node_modules")
                      "--node" #$(file-append node "/bin/node")
                      "--shell" #$(file-append bash-minimal "/bin/sh"))))
          (add-after 'stage-modules 'relink-workspace-packages
            (lambda _
              ;; The locked module graph can carry absolute workspace self-link
              ;; targets from the tree it was assembled in; point them at this
              ;; build's authored packages so resolution stays in-tree.
              (invoke "python3"
                      #$(under-sea-script "relink-hermes-next-workspaces.py")
                      ".")))
          (add-after 'relink-workspace-packages 'provide-typescript
            (lambda _
              ;; ncc (next-env/font) and tsc (font/react-refresh-utils) need the
              ;; locked TypeScript compiler and Node type definitions, which are
              ;; root devDependencies the staged module graph does not hoist.
              ;; Materialize the exact locked packages where those tools resolve
              ;; them.
              (let ((typescript
                     #$(cadr (assoc "typescript@5.9.2" %next-node-source-origins)))
                    (node-types
                     #$(cadr (assoc "@types/node@20.17.6" %next-node-source-origins)))
                    (undici-types
                     #$(cadr (assoc "undici-types@6.19.8" %next-node-source-origins))))
                (for-each
                 (lambda (entry)
                   (let ((destination (car entry))
                         (archive (cdr entry)))
                     (when (file-exists? destination)
                       (delete-file-recursively destination))
                     (mkdir-p destination)
                     (invoke "tar" "xf" archive "-C" destination
                             "--strip-components=1")))
                 (append
                  (map (lambda (directory)
                         (cons (string-append directory "/node_modules/typescript")
                               typescript))
                       '("." "packages/next" "packages/next-env" "packages/font"
                         "packages/react-refresh-utils"))
                  (map (lambda (directory)
                         (cons (string-append directory "/node_modules/@types/node")
                               node-types))
                       '("." "packages/next" "packages/next-env" "packages/font"
                         "packages/react-refresh-utils"))
                  (map (lambda (directory)
                         (cons (string-append directory "/node_modules/undici-types")
                               undici-types))
                       '("." "packages/next" "packages/next-env" "packages/font"
                         "packages/react-refresh-utils")))))))
          (add-after 'provide-typescript 'link-undeclared-task-deps
            (lambda _
              ;; packages/next/taskfile.js requires modules that are not declared
              ;; in packages/next/package.json; the authored Next build expects
              ;; them hoisted.  Link the exact locked versions extracted in the
              ;; source module graph.
              (let ((deps (string-append (getcwd) "/packages/next/node_modules")))
                (mkdir-p deps)
                (for-each
                 (lambda (entry)
                   (let ((target (string-append deps "/" (car entry))))
                     (unless (file-exists? target)
                       (mkdir-p (dirname target))
                       (symlink (cdr entry) target))))
                 (list
                  (cons "resolve-from"
                        #$(file-append next-source-build-modules
                                       "/lib/node_modules/.sources/3fc664d5b09bf13ea609c7ca38431d99ad4cf99cf61cde086d36f76112f8b0ce/package"))
                  (cons "@babel/parser"
                        #$(file-append next-source-build-modules
                                       "/lib/node_modules/.sources/96bea728c0f98e28ac9076fc0ba875126aba375df0b7bee9a68d7e7399bd8b62/package"))
                  (cons "execa"
                        #$(file-append next-source-build-modules
                                       "/lib/node_modules/.sources/a0c2c672c3fccddd8bd85ffff34f8f18d893b9f136946e6225b9abc9a8fae10e/package"))
                  (cons "webpack-bundle-analyzer"
                        #$(file-append next-1608-task-source-build-modules
                                       "/lib/node_modules/.sources/9a36e6d11626f611c78ced3ca2828504a1c417a2afcaeff5863c16269c62c56f/package"))
                  (cons "@swc/core-linux-x64-gnu"
                        #$(file-append swc-core-binding-for-hermes-next
                                       "/lib/node_modules/@swc/core-linux-x64-gnu")))))))
          (add-after 'link-undeclared-task-deps 'link-next-self
            (lambda _
              ;; Next's webpack config aliases react to `next/dist/compiled/react`;
              ;; the package manager normally links the workspace package `next`
              ;; to itself so that bare `next/...` requests resolve.
              (let* ((root (getcwd))
                     (nextpkg (string-append root "/packages/next")))
                (mkdir-p (string-append root "/node_modules"))
                (unless (file-exists? (string-append root "/node_modules/next"))
                  (symlink nextpkg (string-append root "/node_modules/next")))
                (unless (file-exists? (string-append nextpkg "/node_modules/next"))
                  (symlink nextpkg (string-append nextpkg "/node_modules/next"))))))
          (add-after 'link-next-self 'build-workspace-packages
            (lambda _
              ;; packages/next's release bundles consume authored workspace
              ;; packages that upstream builds with `turbo run build`.  Build the
              ;; ones its bundling needs, using each package's own toolchain, so
              ;; @next/env and the polyfills resolve with a real dist.
              (define (run directory . arguments)
                (with-directory-excursion directory
                  (apply invoke arguments)))
              (run "packages/next-polyfill-module"
                   "./node_modules/.bin/microbundle" "-i" "src/index.js"
                   "-o" "dist/polyfill-module.js" "-f" "iife" "--no-sourcemap"
                   "--external" "none" "--no-pkg-main")
              (run "packages/next-polyfill-nomodule"
                   "./node_modules/.bin/microbundle" "-i" "src/index.js"
                   "-o" "dist/polyfill-nomodule.js" "-f" "iife" "--no-sourcemap"
                   "--external" "none" "--no-pkg-main")
              (run "packages/next-env"
                   "./node_modules/.bin/ncc" "build" "./index.ts"
                   "-o" "./dist/" "--minify" "--no-cache"
                   "--no-source-map-register")
              (run "packages/font"
                   "./node_modules/.bin/ncc" "build" "./fontkit.js"
                   "--minify" "-o" "dist/fontkit")
              (run "packages/font"
                   "./node_modules/.bin/tsc" "-d" "-p" "tsconfig.build.json")
              ;; react-refresh-utils is compiled into
              ;; next/dist/compiled/@next/react-refresh-utils and loaded at
              ;; runtime by next dev/build.
              (run "packages/react-refresh-utils"
                   "node" "./node_modules/typescript/bin/tsc"
                   "-d" "-p" "tsconfig.json")))
          (add-after 'build-workspace-packages 'provide-build-tooling
            (lambda _
              ;; The authored tasks invoke `pnpm`; forward it to npm and honour
              ;; workspace (-w) scope.  Also wrap taskr so the copies it makes
              ;; from read-only vendored inputs stay writable.
              (let ((bin (string-append (getcwd) "/guix-tool-bin"))
                    (shell #$(file-append bash-minimal "/bin/sh")))
                (mkdir-p bin)
                (let ((pnpm (string-append bin "/pnpm")))
                  (call-with-output-file pnpm
                    (lambda (port)
                      (display
                       (string-append
                        "#!" shell "\n"
                        "set -eu\n"
                        "w=0\n"
                        "while [ \"${1:-}\" = \"-w\" ] || [ \"${1:-}\" = \"--workspace\" ]; do w=1; shift; done\n"
                        "if [ \"$w\" = 1 ]; then d=\"$PWD\"; while [ \"$d\" != / ] && [ ! -f \"$d/pnpm-workspace.yaml\" ]; do d=$(dirname \"$d\"); done; cd \"$d\"; fi\n"
                        "exec npm \"$@\"\n")
                       port)))
                  (chmod pnpm #o755))
                (let ((wrapper (string-append bin "/taskr-release")))
                  (call-with-output-file wrapper
                    (lambda (port)
                      (display
                       (string-append
                        "#!" shell "\n"
                        "set -eu\n"
                        "( while :; do chmod -R u+w dist 2>/dev/null || true; sleep 0.05; done ) &\n"
                        "guard=$!\n"
                        "./node_modules/.bin/taskr release\n"
                        "status=$?\n"
                        "kill \"$guard\" 2>/dev/null || true\n"
                        "wait \"$guard\" 2>/dev/null || true\n"
                        "exit \"$status\"\n")
                       port)))
                  (chmod wrapper #o755)))))
          (add-after 'provide-build-tooling 'install-source-og
            (lambda _
              ;; Next vendors @vercel/og and satori into src/compiled.  Populate
              ;; that tree from the source-built providers (never a published
              ;; payload), removing any placeholder first, and expose the same
              ;; providers under their package names for the type task.
              (let ((target
                     (string-append (getcwd)
                                    "/packages/next/src/compiled/@vercel/og"))
                    (modules (string-append (getcwd)
                                            "/packages/next/node_modules"))
                    (og #$(file-append vercel-og-for-hermes-browser
                                       "/lib/node_modules/@vercel/og"))
                    (satori #$(file-append satori-for-hermes-browser
                                           "/lib/node_modules/satori")))
                (when (file-exists? target)
                  (delete-file-recursively target))
                (invoke "python3"
                        #$(under-sea-script "install-next-source-og.py")
                        "." og satori)
                (mkdir-p (string-append modules "/@vercel"))
                (for-each
                 (lambda (entry)
                   (let ((destination (string-append modules "/" (car entry))))
                     (when (file-exists? destination)
                       (delete-file-recursively destination))
                     (symlink (cdr entry) destination)))
                 (list (cons "satori" satori) (cons "@vercel/og" og))))))
          (add-after 'install-source-og 'provide-missing-types
            (lambda _
              ;; The authored tsconfig references a few root devDependencies the
              ;; staged module graph omits; materialize the exact locked packages
              ;; so the types task and the optional CSS optimizer resolve them.
              (for-each
               (lambda (entry)
                 (let ((destination
                        (string-append (getcwd) "/packages/next/node_modules/"
                                       (car entry)))
                       (archive (cdr entry)))
                   (when (file-exists? destination)
                     (delete-file-recursively destination))
                   (mkdir-p destination)
                   (invoke "tar" "xf" archive "-C" destination
                           "--strip-components=1")))
               (list
                (cons "@types/busboy"
                      #$(cadr (assoc "@types/busboy@1.5.3" %next-type-origins)))
                (cons "@types/http-proxy"
                      #$(cadr (assoc "@types/http-proxy@1.17.3" %next-type-origins)))
                (cons "@types/string-hash"
                      #$(cadr (assoc "@types/string-hash@1.1.1" %next-type-origins)))
                (cons "@types/trusted-types"
                      #$(cadr (assoc "@types/trusted-types@2.0.3" %next-type-origins)))
                (cons "critters"
                      #$(cadr (assoc "critters@0.0.6" %next-type-origins)))))))
          (add-after 'provide-missing-types 'preserve-symlinks-tsc
            (lambda _
              ;; Registry packages are linked from the immutable store; without
              ;; --preserveSymlinks tsc resolves a package's realpath and cannot
              ;; see the consumer's hoisted peer/type packages.  Keep declaration
              ;; resolution at the symlink location.
              (let* ((tsc (string-append (getcwd)
                                         "/packages/next/node_modules/.bin/tsc"))
                     (real (string-append tsc ".real")))
                (rename-file tsc real)
                (call-with-output-file tsc
                  (lambda (port)
                    (display
                     (string-append
                      "#!" #$(file-append bash-minimal "/bin/sh") "\n"
                      "exec " real " --preserveSymlinks \"$@\"\n")
                     port)))
                (chmod tsc #o755))))
          (replace 'build
            (lambda _
              (setenv "NODE_ENV" "production")
              (setenv "NEXT_TELEMETRY_DISABLED" "1")
              (let ((toolbin (string-append (getcwd) "/guix-tool-bin")))
                (setenv "PATH" (string-append toolbin ":"
                                              (getcwd) "/node_modules/.bin:"
                                              (getenv "PATH")))
                ;; taskr loads @taskr/esnext from the package location; expose the
                ;; consumer node_modules and keep the authored CommonJS
                ;; transpilation (Node 24's automatic ESM detection breaks it).
                (setenv "NODE_PATH" (string-append (getcwd) "/packages/next/node_modules"))
                (setenv "NODE_OPTIONS" "--no-experimental-detect-module")
                (chdir "packages/next")
                (invoke (string-append toolbin "/taskr-release"))
                (unless (file-exists? "dist/bin/next")
                  (error "Next release produced no dist/bin/next; taskr likely swallowed an error")))))
          (replace 'install
            (lambda _
              (let* ((out #$output)
                     (lib (string-append out "/lib/node_modules"))
                     (bin (string-append out "/bin"))
                     (next (string-append lib "/next")))
                ;; cwd is packages/next from the 'build phase.
                (mkdir-p next)
                (copy-recursively "." next)
                ;; The source build leaked react/react-dom (a build-time canary)
                ;; into node_modules.  Point these peer dependencies at Next's own
                ;; compiled React so the framework is self-consistent.
                (for-each
                 (lambda (peer)
                   (let ((target (string-append next "/node_modules/" peer)))
                     (when (file-exists? target)
                       (delete-file-recursively target))
                     (symlink (string-append "../dist/compiled/" peer) target)))
                 '("react" "react-dom"))
                ;; The built `next` references its authored sibling workspace
                ;; packages through relative links; install the built siblings
                ;; so those links resolve in the immutable output.
                (for-each
                 (lambda (name)
                   (let ((source (string-append "../" name))
                         (destination (string-append lib "/" name)))
                     (when (file-exists? source)
                       (mkdir-p destination)
                       (copy-recursively source destination))))
                 '("next-env" "next-polyfill-module" "next-polyfill-nomodule"
                   "font" "react-refresh-utils" "next-swc"))
                (mkdir-p bin)
                (symlink (string-append next "/dist/bin/next")
                         (string-append bin "/next"))))))))
    (supported-systems '("x86_64-linux"))
    (properties '((max-silent-time . 7200)))
    (home-page "https://github.com/vercel/next.js")
    (synopsis "Source-built Next framework for Hermes dashboard export")
    (description "This package builds the Next 16.1.1 framework from its
authored source with the locked module graph and source-built SWC/Rspack
bindings, to be consumed by the Hermes dashboard static export.  It does not
ship a prebuilt Next distribution.  Functional validation is deferred.")
    (license license:expat)))
