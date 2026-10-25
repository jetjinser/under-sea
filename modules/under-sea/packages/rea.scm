;;; REA (rea-agents): reverse-engineering agent CLI and MCP server.
;;;
;;; The published npm tarball is the upstream release artifact and already
;;; contains the compiled dist/ tree, so the build installs that tarball plus
;;; its locked runtime dependency closure instead of rebuilding TypeScript.
;;; Every npm tarball is a fixed sha256 origin (see rea-lock.scm) and the build
;;; materialises node_modules directly, without running npm or using network.
;;;
;;; node-pty is the only native dependency.  Its npm platform package ships a
;;; prebuilt .node, so it is excluded from the lock and replaced with the
;;; source-built binding from node-pty-for-hermes.
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
  #:use-module (under-sea packages rea-lock))

(define-public rea
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
              (for-each
               (lambda (file)
                 (substitute* file
                   (("distribution\\?\\.packageFamily !== undefined")
                    "distribution !== undefined")))
               (find-files "." "\\.js$"))))
          (replace 'build
            (lambda _
              ;; Record the exact path, version and store item for every
              ;; runtime tarball, then extract each one into the node_modules
              ;; path npm would have used.
              (call-with-output-file "deps.tsv"
                (lambda (port)
                  #$@(map (lambda (entry)
                            #~(format port "~a\t~a\t~a~%"
                                      #$(car entry)
                                      #$(cadr entry)
                                      #$(caddr entry)))
                          %rea-npm-origins)))
              (call-with-output-file "extract.py"
                (lambda (port)
                  (display
                   (string-append
                    "import os, tarfile\n"
                    "root = os.getcwd()\n"
                    "for line in open('deps.tsv', encoding='utf-8'):\n"
                    "    if not line.strip():\n"
                    "        continue\n"
                    "    path, version, src = line.rstrip('\\n').split('\\t', 2)\n"
                    "    dest = os.path.join(root, path)\n"
                    "    os.makedirs(dest, exist_ok=True)\n"
                    "    with tarfile.open(src) as t:\n"
                    "        t.extractall(dest, filter='data')\n"
                    ;; npm tarballs nest their contents under one top-level
                    ;; directory (package/); flatten it.
                    "    entries = os.listdir(dest)\n"
                    "    if len(entries) == 1 and os.path.isdir(\n"
                    "            os.path.join(dest, entries[0])):\n"
                    "        top = os.path.join(dest, entries[0])\n"
                    "        for f in os.listdir(top):\n"
                    "            os.replace(os.path.join(top, f),\n"
                    "                       os.path.join(dest, f))\n"
                    "        os.rmdir(top)\n")
                   port)))
              (invoke #$(file-append python-minimal "/bin/python3") "extract.py")
              ;; Replace node-pty's prebuilt platform package with the
              ;; source-built binding.  @lydell/node-pty resolves this package
              ;; at runtime by platform/arch name.
              (let ((pty-dir "node_modules/@lydell/node-pty-linux-x64"))
                (mkdir-p pty-dir)
                (copy-file
                 (string-append
                  #$node-pty-for-hermes
                  "/lib/node_modules/node-pty/build/Release/pty.node")
                 (string-append pty-dir "/pty.node"))
                (chmod (string-append pty-dir "/pty.node") #o755)
                (call-with-output-file (string-append pty-dir "/package.json")
                  (lambda (port)
                    (display
                     (string-append
                      "{\"name\":\"@lydell/node-pty-linux-x64\","
                      "\"version\":\"1.1.0\",\"os\":[\"linux\"],"
                      "\"cpu\":[\"x64\"]}\n")
                     port))))))
          (replace 'install
            (lambda* (#:key inputs #:allow-other-keys)
              (let* ((out #$output)
                     (prefix (string-append out "/lib/node_modules/rea-agents"))
                     (bin (string-append out "/bin")))
                (mkdir-p (dirname prefix))
                (copy-recursively "." prefix)
                (mkdir-p bin)
                (for-each
                 (lambda (name)
                   (let ((wrapper (string-append bin "/" name)))
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
                ;; Process inspection uses `ps'; expose the packaged procps.
                (wrap-program (string-append bin "/rea")
                  `("PATH" ":" prefix
                    (,(string-append (assoc-ref inputs "procps") "/bin"))))
                (wrap-program (string-append bin "/rea-agents")
                  `("PATH" ":" prefix
                    (,(string-append (assoc-ref inputs "procps") "/bin"))))))))))
    (supported-systems '("x86_64-linux"))
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
