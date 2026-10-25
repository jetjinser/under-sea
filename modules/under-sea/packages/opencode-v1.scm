;;; opencode v1 (the legacy line that kilocode forked), built from the
;;; v1.19.4 source tag.  The npm release is only a launcher around a 215 MB
;;; prebuilt platform binary, so the CLI is compiled from source here.  Native
;;; npm payloads that have no source in the package tarballs are recorded as
;;; precompiled exceptions in planning/precompiled-exceptions.json.

(define-module (under-sea packages opencode-v1)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix base32)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages node)
  #:use-module (gnu packages python)
  #:use-module (gnu packages rust-apps)
  #:use-module (under-sea gexp)
  #:use-module (under-sea packages bun)
  #:use-module (under-sea packages opencode-v1-lock))

(define %opencode-v1-version "1.19.4")

(define %opencode-v1-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/anomalyco/opencode/tar.gz/refs/tags/v1.19.4")
    (file-name "opencode-1.19.4.tar.gz")
    (sha256
     (base32 "1fyqhi2k74lihv1wbhyznjqszjn3izdjdpcyzdz4mpxj0p83wm9f"))))

;; v1's build script can fetch models.dev at build time; pin the same snapshot
;; used by kilocode so the build stays offline.
(define %opencode-models
  (under-sea-repo-file "planning/kilocode-models-dev-api.json"))

(define-public opencode-v1
  (package
    (name "opencode-v1")
    (version %opencode-v1-version)
    (source %opencode-v1-source)
    (build-system gnu-build-system)
    (native-inputs (list bun-for-opencode tar gzip xz bzip2
                         coreutils-minimal findutils grep sed
                         python-minimal node patchelf))
    (inputs (list bash-minimal ripgrep glibc (list gcc "lib")))
    (arguments
     (list
      #:validate-runpath? #f
      #:strip-binaries? #f
      #:modules '((guix build gnu-build-system) (guix build utils)
                  (srfi srfi-13))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          (replace 'build
            (lambda* (#:key inputs #:allow-other-keys)
              ;; Reconstruct Bun's install cache from the locked origins.
              (call-with-output-file "cache-map.txt"
                (lambda (port)
                  #$@(map (lambda (entry)
                            #~(format port "~a\t~a~%"
                                      #$(car entry) #$(cadr entry)))
                          %opencode-v1-npm-origins)))
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
                    "    entries = os.listdir(dest)\n"
                    "    if len(entries) == 1 and os.path.isdir(os.path.join(dest, entries[0])):\n"
                    "        top = os.path.join(dest, entries[0])\n"
                    "        for f in os.listdir(top):\n"
                    "            os.replace(os.path.join(top, f),\n"
                    "                       os.path.join(dest, f))\n"
                    "        os.rmdir(top)\n"
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
              (setenv "BUN_INSTALL_CACHE_DIR"
                      (string-append (getcwd) "/bun-cache"))
              (setenv "OPENCODE_VERSION" #$%opencode-v1-version)
              (setenv "OPENCODE_CHANNEL" "latest")
              (setenv "OPENCODE_DISABLE_AUTOUPDATE" "1")
              (setenv "OPENCODE_DISABLE_MODELS_FETCH" "1")
              (setenv "MODELS_DEV_API_JSON" #$%opencode-models)
              (invoke #$(file-append bun-for-opencode "/bin/bun")
                      "install" "--frozen-lockfile" "--offline"
                      "--ignore-scripts")
              ;; node_modules/.bin scripts use /usr/bin/env node.
              (for-each
               (lambda (f)
                 (catch #t (lambda () (patch-shebang f)) (lambda _ #t)))
               (filter (lambda (f) (string-contains f "/.bin/"))
                       (find-files "." ".*")))
              ;; The .node payloads have no RUNPATH and need libstdc++/libgcc.
              (let* ((glibc-lib (string-append (assoc-ref inputs "glibc") "/lib"))
                     (gcc-lib (string-append (assoc-ref inputs "gcc") "/lib"))
                     (rpath (string-append glibc-lib ":" gcc-lib)))
                (for-each
                 (lambda (file)
                   ;; The closure contains darwin/arm64 prebuilds too; only
                   ;; ELF payloads need (and accept) patchelf.
                   (catch #t
                     (lambda ()
                       (invoke "patchelf" "--set-rpath" rpath file))
                     (lambda _ #t)))
                 (find-files "node_modules" "\\.node$")))
              (with-directory-excursion "packages/opencode"
                (invoke #$(file-append bun-for-opencode "/bin/bun")
                        "--bun" "./script/build.ts" "--single" "--skip-install"
                        "--skip-embed-web-ui"))))
          (replace 'install
            (lambda _
              (let* ((out #$output)
                     (bin (string-append out "/bin"))
                     (candidate
                      (car (find-files "packages/opencode/dist"
                                       "^opencode$"))))
                (mkdir-p bin)
                (copy-file candidate (string-append bin "/opencode-v1"))
                (chmod (string-append bin "/opencode-v1") #o755)
                (wrap-program (string-append bin "/opencode-v1")
                  `("PATH" ":" prefix
                    (,(string-append #$ripgrep "/bin")))
                  `("OPENCODE_DISABLE_AUTOUPDATE" = ("1"))
                  `("OPENCODE_DISABLE_MODELS_FETCH" = ("1")))))))))
    (supported-systems '("x86_64-linux"))
    (properties '((upstream-github "anomalyco/opencode")
                  (max-silent-time . 7200)))
    (home-page "https://opencode.ai/")
    (synopsis "OpenCode 1 legacy AI coding agent CLI")
    (description "This package builds the legacy OpenCode 1 CLI from the
v1.19.4 source tag.  It is the line that Kilo Code forked and is installed as
@command{opencode-v1} so it can coexist with @command{opencode-v2}.  The Bun
dependency closure is assembled offline from fixed origins; native npm
payloads without source in their tarballs are recorded as a source-unavailable exception.  ripgrep is supplied by Guix.")
    (license license:expat)))
