;;; Kilo Code CLI (kilo) built from source; the TUI is bundled into the
;;; single-file bun-compiled binary.  The TUI itself (@opencode-ai/tui) is a
;;; SolidJS library rendered on the native @opentui core and is not a standalone
;;; program, so packaging "the TUI" means packaging this CLI.
;;;
;;; Every npm dependency is a fixed sha256 origin (see kilocode-lock.scm); the
;;; build assembles bun's install cache from them and then installs/bundles
;;; completely offline (this host's build sandbox has no usable network, so the
;;; download must go through the daemon's url-fetch).
(define-module (under-sea packages kilocode)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (under-sea gexp)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages node)
  #:use-module (gnu packages python)
  #:use-module (gnu packages rust-apps)
  #:use-module (gnu packages virtualization)
  #:use-module (under-sea packages bun)
  #:use-module (under-sea packages kilocode-lock))

(define %kilocode-version "7.8.12")

(define %kilocode-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/kilo-org/kilocode/tar.gz/refs/tags/v7.8.12")
    (file-name "kilocode-7.8.12.tar.gz")
    (sha256
     (base16-string->bytevector
      "96050bedea55c3be9d976546fc225254cf8c50c5393087ad044d1b39e087f4d7"))))

;; The build reads a pinned models.dev snapshot instead of fetching it, so the
;; build stays offline (see packages/opencode/script/generate.ts).
(define %kilocode-models
  ;; A copy of models.dev/api.json, pinned so the build never fetches it.
  (under-sea-repo-file "planning/kilocode-models-dev-api.json"))

(define-public kilocode
  (package
    (name "kilocode")
    (version %kilocode-version)
    (source %kilocode-source)
    (build-system gnu-build-system)
    (native-inputs (list bun-for-hermes tar gzip xz bzip2
                         coreutils-minimal findutils grep sed python-minimal node))
    (inputs (list bash-minimal bubblewrap ripgrep))
    (arguments
     (list
      #:validate-runpath? #f
      ;; strip would corrupt the bun standalone payload (its embedded app is
      ;; located via trailing metadata), making the binary fall back to bun.
      #:strip-binaries? #f
      #:modules '((guix build gnu-build-system) (guix build utils)
                  (srfi srfi-13))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          (replace 'build
            (lambda _
              ;; Reconstruct bun's install cache from the locked origins so the
              ;; installer can run offline.  Extract with Python's tarfile: some
              ;; npm tarballs carry directories without the execute bit, which
              ;; GNU tar cannot then populate; tarfile fixes dir modes at the end.
              (call-with-output-file "cache-map.txt"
                (lambda (port)
                  #$@(map (lambda (entry)
                            #~(format port "~a\t~a~%" #$(car entry) #$(cadr entry)))
                          %kilocode-npm-origins)))
              (call-with-output-file "extract.py"
                (lambda (port)
                  (display
                   (string-append
                    "import json, tarfile, os\n"
                    "for line in open('cache-map.txt', encoding='utf-8'):\n"
                    "    if not line.strip():\n"
                    "        continue\n"
                    "    label, src = line.rstrip('\\n').split('\\t', 1)\n"
                    "    dest = os.path.join('bun-cache', label)\n"
                    "    os.makedirs(dest, exist_ok=True)\n"
                    "    with tarfile.open(src) as t:\n"
                    "        t.extractall(dest, filter='data')\n"
                    ;; npm tarballs nest everything under one top dir (usually
                    ;; package/, sometimes the package basename); flatten it.
                    "    entries = os.listdir(dest)\n"
                    "    if len(entries) == 1 and os.path.isdir(os.path.join(dest, entries[0])):\n"
                    "        top = os.path.join(dest, entries[0])\n"
                    "        for f in os.listdir(top):\n"
                    "            os.replace(os.path.join(top, f),\n"
                    "                       os.path.join(dest, f))\n"
                    "        os.rmdir(top)\n"
                    ;; bun looks a package up at bun-cache/<name>/<label-without-
                    ;; the-name>@@@1; recreate that per-name symlink.
                    "    with open(os.path.join(dest, 'package.json')) as fh:\n"
                    "        name = json.load(fh)['name']\n"
                    "    prefix = name + '@'\n"
                    "    sub = label[len(prefix):] if label.startswith(prefix) else label\n"
                    "    linkdir = os.path.join('bun-cache', name)\n"
                    "    os.makedirs(linkdir, exist_ok=True)\n"
                    "    link = os.path.join(linkdir, sub)\n"
                    "    if not os.path.lexists(link):\n"
                    "        os.symlink(os.path.relpath(dest, linkdir), link)\n")
                   port)))
              (invoke #$(file-append python-minimal "/bin/python3") "extract.py")
              (setenv "HOME" (getcwd))
              (setenv "BUN_INSTALL_CACHE_DIR" (string-append (getcwd) "/bun-cache"))
              (setenv "KILO_VERSION" #$%kilocode-version)
              (setenv "KILO_CHANNEL" "local")
              ;; Use the packaged bubblewrap rather than a bundled one.
              (setenv "KILO_SKIP_BUNDLED_BWRAP" "1")
              (setenv "MODELS_DEV_API_JSON" #$%kilocode-models)
              (invoke #$(file-append bun-for-hermes "/bin/bun")
                      "install" "--frozen-lockfile" "--offline" "--ignore-scripts")
              ;; node_modules/.bin scripts use "#!/usr/bin/env node", which the
              ;; sandbox cannot run; point them at the packaged node (as the
              ;; upstream Nix recipe does with patchShebangs node_modules).
              (for-each
               (lambda (f)
                 (catch #t (lambda () (patch-shebang f)) (lambda _ #t)))
               (filter (lambda (f) (string-contains f "/.bin/"))
                       (find-files "." ".*")))
              ;; Skip the optional web "Kilo Console" (Vite) build: it is not
              ;; part of the CLI/TUI, and its bundler trips on bun's .bin layout.
              ;; Seed an up-to-date dist so build.ts reuses it instead of building.
              (let ((console-dist (string-append (getcwd) "/packages/kilo-console/dist")))
                (mkdir-p console-dist)
                (call-with-output-file (string-append console-dist "/index.html")
                  (lambda (port)
                    (display "<!doctype html><meta charset=\"utf-8\"><title>Kilo Console</title>\n"
                             port))))
              ;; bun's compiled standalone binary already embeds the Guix glibc
              ;; loader as its interpreter (bun-for-hermes is built that way).
              ;; build.ts nonetheless runs `patchelf --set-interpreter
              ;; /lib64/ld-linux-x86-64.so.2`, which both names a path absent
              ;; here and corrupts the bun standalone ELF (segfault on exec);
              ;; disable that step so the embedded loader is kept.
              (substitute* "packages/opencode/script/build.ts"
                (("x64: \"/lib64/ld-linux-x86-64\\.so\\.2\",")
                 "x64: undefined,"))
              (with-directory-excursion "packages/opencode"
                (invoke #$(file-append bun-for-hermes "/bin/bun")
                        "--bun" "./script/build.ts" "--single" "--skip-install"))))
          (replace 'install
            (lambda _
              (let* ((out #$output)
                     (bin (string-append out "/bin"))
                     (dist-bin
                      "packages/opencode/dist/@kilocode/cli-linux-x64/bin"))
                (mkdir-p bin)
                ;; Install the binary together with the runtime auxiliaries it
                ;; resolves next to itself: tree-sitter grammars, sandbox
                ;; worker JS, the seccomp helper, the console assets and
                ;; licenses.  Drop debug source maps (*.map), ~94 MiB.
                (copy-recursively dist-bin bin)
                (for-each delete-file (find-files bin "\\.map$"))
                (for-each (lambda (f) (chmod f #o755))
                          (list (string-append bin "/kilo")
                                (string-append bin "/kilo-sandbox-seccomp")))
                (wrap-program (string-append bin "/kilo")
                  `("KILO_BWRAP_PATH" =
                    (,(string-append #$bubblewrap "/bin/bwrap")))
                  `("KILO_DISABLE_MODELS_FETCH" = ("1"))
                  `("PATH" ":" prefix
                    (,(string-append #$ripgrep "/bin"))))))))))
    (supported-systems '("x86_64-linux"))
    (properties '((upstream-github "kilo-org/kilocode")
                  (max-silent-time . 7200)))
    (home-page "https://kilo.ai/")
    (synopsis "Kilo Code agent CLI with terminal UI")
    (description "This package builds the Kilo Code agent command-line tool
(@code{kilo}) from source with bun.  The terminal user interface (the
@code{opencode-ai/tui} package, rendered on the native opentui core) is bundled
into the single-file executable.  Every npm dependency is a fixed sha256 origin
assembled offline; the native opentui, parcel, lydell/node-pty, fff and
tree-sitter payloads are precompiled exceptions.  It uses the packaged
bubblewrap and ripgrep at runtime.")
    (license license:expat)))
