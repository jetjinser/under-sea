;;; REA (rea-agents): reverse-engineering agent CLI and MCP server.
;;;
;;; `rea` builds the upstream source tree and installs only the runtime npm
;;; closure; `rea-release` keeps the published npm artifact as a fallback.
;;; Both materialise fixed sha256 npm origins (rea-lock.scm and
;;; rea-source-lock.scm) directly into node_modules, without network access.
;;;
;;; node-pty is the only native dependency.  Its npm platform package ships a
;;; prebuilt .node, so it is excluded from the runtime lock and replaced with
;;; the source-built binding from node-pty-for-hermes.
(define-module (under-sea packages rea)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages node)
  #:use-module (gnu packages python)
  #:use-module (under-sea packages hermes-node)
  #:use-module (under-sea packages rea-lock)
  #:use-module (under-sea packages rea-source-lock))

(define (rea-origin-table origins file)
  "Return a gexp writing ORIGINS as a path/version/store TSV to FILE."
  #~(call-with-output-file #$file
      (lambda (port)
        #$@(map (lambda (entry)
                  #~(format port "~a\t~a\t~a~%"
                            #$(car entry)
                            #$(cadr entry)
                            #$(caddr entry)))
                origins))))

(define %rea-extract-npm
  (plain-file
   "extract-npm.py"
   (string-append
    "import os, sys, tarfile\n"
    "root = os.getcwd()\n"
    "for line in open(sys.argv[1], encoding='utf-8'):\n"
    "    if not line.strip():\n"
    "        continue\n"
    "    path, _version, src = line.rstrip('\\n').split('\\t', 2)\n"
    "    dest = os.path.join(root, path)\n"
    "    os.makedirs(dest, exist_ok=True)\n"
    "    with tarfile.open(src) as archive:\n"
    "        archive.extractall(dest, filter='data')\n"
    "    entries = os.listdir(dest)\n"
    "    if len(entries) == 1 and os.path.isdir(os.path.join(dest, entries[0])):\n"
    "        top = os.path.join(dest, entries[0])\n"
    "        for entry in os.listdir(top):\n"
    "            os.replace(os.path.join(top, entry),\n"
    "                       os.path.join(dest, entry))\n"
    "        os.rmdir(top)\n")))

(define (rea-extract-origins origins file)
  "Write ORIGINS to FILE and extract the npm tarballs under the current dir."
  #~(begin
      #$(rea-origin-table origins file)
      (invoke #$(file-append python-minimal "/bin/python3")
              #$%rea-extract-npm #$file)
      (delete-file #$file)))

(define (rea-install-node-pty dir)
  "Install the source-built node-pty binding into DIR."
  #~(begin
      (mkdir-p #$dir)
      (copy-file
       #$(file-append node-pty-for-hermes
                      "/lib/node_modules/node-pty/build/Release/pty.node")
       (string-append #$dir "/pty.node"))
      (chmod (string-append #$dir "/pty.node") #o755)
      (call-with-output-file (string-append #$dir "/package.json")
        (lambda (port)
          (display
           (string-append
            "{\"name\":\"@lydell/node-pty-linux-x64\","
            "\"version\":\"1.1.0\",\"os\":[\"linux\"],"
            "\"cpu\":[\"x64\"]}\n")
           port)))))

(define (rea-patch-host-detection dir)
  "Teach the bundled runtime to accept any detected distribution."
  #~(for-each
     (lambda (file)
       (substitute* file
         (("distribution\\?\\.packageFamily !== undefined")
          "distribution !== undefined")))
     (find-files #$dir "\\.js$")))

(define-public rea-release
  (package
    (name "rea")
    (version %rea-version)
    (source %rea-source)
    (build-system gnu-build-system)
    (native-inputs (list python-minimal))
    (inputs (list bash-minimal node procps))
    (arguments
     (list
      #:modules '((guix build gnu-build-system)
                  (guix build utils)
                  (ice-9 format))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          ;; REA classifies a Linux host as supported only when it recognizes
          ;; a package family in /etc/os-release.  Guix is glibc-based but has
          ;; no package-family entry, so teach the bundled runtime that any
          ;; detected distribution is usable for analysis providers.
          (add-after 'unpack 'patch-guix-host-detection
            (lambda _
              #$(rea-patch-host-detection ".")))
          (replace 'build
            (lambda _
              ;; Materialise the locked runtime closure exactly where npm
              ;; would have placed it, then install the source-built pty.
              #$(rea-extract-origins %rea-npm-origins "deps.tsv")
              #$(rea-install-node-pty "node_modules/@lydell/node-pty-linux-x64")))
          (replace 'install
            (lambda* (#:key inputs #:allow-other-keys)
              (let* ((out #$output)
                     (prefix (string-append out "/lib/node_modules/rea-agents")))
                (mkdir-p (dirname prefix))
                (copy-recursively "." prefix)
                (mkdir-p (string-append out "/bin"))
                (for-each
                 (lambda (name)
                   (let ((wrapper (string-append out "/bin/" name)))
                     (call-with-output-file wrapper
                       (lambda (port)
                         (format port "#!~a\nexec ~a ~s \"$@\"\n"
                                 (string-append (assoc-ref inputs "bash-minimal")
                                                "/bin/bash")
                                 (string-append (assoc-ref inputs "node")
                                                "/bin/node")
                                 (string-append prefix "/scripts/rea.mjs"))))
                     (chmod wrapper #o555)))
                 '("rea" "rea-agents"))
                (for-each
                 (lambda (name)
                   (wrap-program (string-append out "/bin/" name)
                     `("PATH" ":" prefix
                       (,(string-append (assoc-ref inputs "procps") "/bin")))))
                 '("rea" "rea-agents"))))))
    ))    (supported-systems '("x86_64-linux"))
    (properties '((upstream-github "morluto/rea")
                  (max-silent-time . 7200)))
    (home-page "https://github.com/morluto/rea")
    (synopsis "Reverse-engineering agent CLI and MCP server")
    (description "REA is a reverse-engineering agent command-line tool and
Model Context Protocol server.  This package installs the upstream published
npm release artifact, which already contains the compiled runtime, together
with its locked runtime dependency closure.  Every npm tarball is a fixed
sha256 origin and is materialised offline; the native node-pty binding is
built from source rather than taken from npm's prebuilt platform package.
The @command{rea} and @command{rea-agents} commands run with the packaged Node
runtime.")
    (license license:expat)))

;;; Source-built REA.  The npm artifact remains available as `rea-release';
;;; this variant runs the upstream turbo/TypeScript build against the locked
;;; package-lock closure and installs only the runtime node_modules closure.
(define-public rea-source
  (package
    (name "rea")
    (version %rea-source-version)
    (source %rea-source-tree)
    (build-system gnu-build-system)
    (native-inputs (list python-minimal))
    (inputs (list bash-minimal node procps))
    (arguments
     (list
      #:modules '((guix build gnu-build-system)
                  (guix build utils)
                  (ice-9 format))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          (replace 'build
            (lambda* (#:key inputs #:allow-other-keys)
              ;; Materialise the complete package-lock closure, then run the
              ;; underlying TypeScript/artifact scripts directly.  Turbo and
              ;; npm's .bin links are not needed for these entry points.
              #$(rea-extract-origins %rea-build-origins "deps.tsv")
              (setenv "HOME" (getcwd))
              (setenv "TURBO_TELEMETRY_DISABLED" "1")
              (let ((node (string-append (assoc-ref inputs "node") "/bin/node")))
                (invoke node "scripts/clean-build-output.mjs")
                (invoke node "node_modules/typescript/bin/tsc"
                        "-p" "tsconfig.build.json")
                (invoke node "scripts/record-catalog-digests.mjs")
                (invoke node "scripts/bundle-runtime.mjs")
                (invoke node "scripts/generate-skill-metadata.mjs"))
              #$(rea-install-node-pty
                 "node_modules/@lydell/node-pty-linux-x64")
              #$(rea-patch-host-detection "dist")))
          (replace 'install
            (lambda* (#:key inputs #:allow-other-keys)
              (let* ((out #$output)
                     (prefix (string-append out "/lib/node_modules/rea-agents")))
                (mkdir-p (dirname prefix))
                (for-each
                 (lambda (file)
                   (copy-recursively file (string-append prefix "/" file)))
                 '("dist" "scripts" "bridge" "skills" "native"
                   "third_party" "licenses"))
                (for-each
                 (lambda (file)
                   (install-file file prefix))
                 '("package.json" "README.md" "DISCLAIMER.md"
                   "THIRD_PARTY_NOTICES.md" "install.sh"))
                ;; Install only the runtime closure, not the build closure.
                (chdir prefix)
                #$(rea-extract-origins %rea-npm-origins "runtime.tsv")
                #$(rea-install-node-pty
                   "node_modules/@lydell/node-pty-linux-x64")
                (mkdir-p (string-append out "/bin"))
                (for-each
                 (lambda (name)
                   (let ((wrapper (string-append out "/bin/" name)))
                     (call-with-output-file wrapper
                       (lambda (port)
                         (format port "#!~a\nexec ~a ~s \"$@\"\n"
                                 (string-append (assoc-ref inputs "bash-minimal")
                                                "/bin/bash")
                                 (string-append (assoc-ref inputs "node")
                                                "/bin/node")
                                 (string-append prefix "/scripts/rea.mjs"))))
                     (chmod wrapper #o555)))
                 '("rea" "rea-agents"))
                (for-each
                 (lambda (name)
                   (wrap-program (string-append out "/bin/" name)
                     `("PATH" ":" prefix
                       (,(string-append (assoc-ref inputs "procps") "/bin")))))
                 '("rea" "rea-agents"))))))
    ))    (supported-systems '("x86_64-linux"))
    (properties '((upstream-github "morluto/rea")
                  (max-silent-time . 7200)))
    (home-page "https://github.com/morluto/rea")
    (synopsis "Reverse-engineering agent CLI and MCP server")
    (description "REA is a reverse-engineering agent command-line tool and
Model Context Protocol server.  This variant builds the upstream turbo and
TypeScript sources from a locked package-lock closure, then installs only the
runtime node_modules closure.  The native node-pty binding is built from
source rather than taken from npm's prebuilt platform package.")
    (license license:expat)))

(define-public rea rea-source)
