;;; marimo - a reactive Python notebook and app server, packaged from the
;;; upstream source distribution.  The optional SQL, sandbox, LSP, MCP and AI
;;; extras are not included; the Loro collaborative-editing backend is omitted
;;; because Guix does not yet provide its Python bindings.

(define-module (under-sea packages marimo)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system pyproject)
  #:use-module (gnu packages build-tools)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-science)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages serialization))

(define-public marimo
  (package
    (name "marimo")
    (version "0.25.2")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://files.pythonhosted.org/packages/source/m/marimo/"
             "marimo-" version ".tar.gz"))
       (sha256
        (base32 "1c2na1v932mjzxzf7zq080j95mgb84dchzfbyzhjarn6hjn3iyiw"))))
    (build-system pyproject-build-system)
    (native-inputs (list python-uv-build))
    (propagated-inputs
     (list python-click
           python-docutils
           python-itsdangerous
           python-jedi
           python-markdown
           python-msgspec
           python-multipart
           python-narwhals
           python-packaging
           python-psutil
           python-pygments
           python-pymdown-extensions
           python-pyyaml
           python-pyzmq
           python-starlette
           python-tomlkit
           python-uvicorn
           python-websockets))
    (arguments
     (list
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          ;; Guix currently ships pymdown-extensions 10.16 and msgspec 0.20;
          ;; marimo's lower bounds are newer than those versions.  The APIs
          ;; marimo uses are present in both, and the pymdown floor was raised
          ;; upstream for a Pygments>=2.20 incompatibility (Guix has 2.19).
          ;; Loro is only used by the optional real-time collaboration path.
          (add-after 'unpack 'relax-requirements
            (lambda _
              (substitute* "pyproject.toml"
                (("pymdown-extensions>=10\\.21\\.2")
                 "pymdown-extensions>=10.16.1")
                (("msgspec>=0\\.22\\.0")
                 "msgspec>=0.20.0")
                (("\"loro>=1\\.10\\.0;[^\"]*\",\n") ""))))
          (add-after 'unpack 'remove-copilot-lsp
            (lambda _
              ;; The sdist ships prebuilt Copilot LSP native modules and
              ;; ripgrep binaries for several architectures.  They have no
              ;; usable RUNPATH on Guix and are only used by the optional
              ;; Copilot integration, which is disabled by default.
              (when (file-exists? "marimo/_lsp/copilot")
                (delete-file-recursively "marimo/_lsp/copilot"))))
          (add-after 'install 'install-launcher
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (bin (string-append out "/bin"))
                     (site (car (find-files out "^site-packages$"
                                            #:directories? #t)))
                     (python (which "python")))
                (mkdir-p bin)
                (call-with-output-file (string-append bin "/marimo")
                  (lambda (port)
                    (format port
                            (string-append
                             "#!~a~%import sys~%"
                             "sys.path.insert(0, ~s)~%"
                             "from marimo._cli.cli import main~%"
                             "sys.exit(main())~%")
                            python site)))
                (chmod (string-append bin "/marimo") #o755))))
          (add-after 'install-launcher 'smoke-test
            (lambda* (#:key outputs #:allow-other-keys)
              (let ((marimo (string-append (assoc-ref outputs "out")
                                           "/bin/marimo")))
                (invoke marimo "--help")
                (invoke marimo "tutorial" "--help")))))))
    (supported-systems '("x86_64-linux"))
    (properties '((upstream-github "marimo-team/marimo")))
    (home-page "https://marimo.io/")
    (synopsis "Reactive Python notebook and app server")
    (description
     "marimo is a reactive Python notebook that stores notebooks as plain
Python, executes cells in dependency order, and can run them as scripts or
web apps.  This package provides the core notebook server, CLI, editor and
tutorials.  Optional SQL, sandbox, language-server, MCP and AI extras are not
included, and real-time collaborative editing is unavailable because the Loro
Python bindings are not packaged.")
    (license license:asl2.0)))
