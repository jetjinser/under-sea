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
  #:use-module (gnu packages duckdb)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-check)
  #:use-module (gnu packages python-science)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages python-xyz)
  #:use-module (under-sea packages loro)
  #:use-module (under-sea packages marimo-deps)
  #:use-module (under-sea packages marimo-lens)
  #:use-module (under-sea packages marimo-pin)
  #:use-module (under-sea packages pydantic-ai))

(define-public marimo
  (package
    (name "marimo")
    (version %marimo-version)
    (source %marimo-source)
    (build-system pyproject-build-system)
    (native-inputs (list python-uv-build))
    (propagated-inputs
     (list python-click
           python-docutils
           python-itsdangerous
           python-jedi
           loro
           python-markdown
           python-msgspec-0.22
           python-multipart
           python-narwhals
           python-packaging
           python-psutil
           python-pygments
           python-pymdown-extensions-10.21
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


;;; An opt-in variant with the SQL and MCP extras that are already packaged in
;;; the pinned channel.  Keeping it separate preserves the small core package
;;; and its service default.
(define-public marimo-with-extras
  (package
    (inherit marimo)
    (name "marimo-with-extras")
    (propagated-inputs
     (append (package-propagated-inputs marimo)
             (list (list "python-duckdb" python-duckdb)
                   (list "python-polars" python-polars)
                   (list "python-sqlglot" python-sqlglot)
                   (list "python-mcp" python-mcp)
                   (list "marimo-lens" marimo-lens)
                   (list "python-pydantic-ai-slim"
                         python-pydantic-ai-slim)
                   ;; Guix's python-mcp lists several runtime imports as
                   ;; native inputs; expose them to the profile.
                   (list "python-pydantic-settings"
                         python-pydantic-settings)
                   (list "python-jsonschema" python-jsonschema)
                   (list "python-typer" python-typer)
                   (list "python-typing-inspection"
                         python-typing-inspection)
                   ;; The LSP and sandbox extras that are available in the
                   ;; pinned channel.
                   (list "python-lsp-server" python-lsp-server)
                   (list "python-lsp-ruff" python-lsp-ruff)
                   (list "uv" uv))))
    (synopsis "Reactive Python notebook with SQL and MCP extras")
    (description
     "This variant of @code{marimo} adds the SQL stack (DuckDB, Polars and
SQLGlot), the MCP client/server library, the Python LSP server with its Ruff
plugin, the @command{uv} sandbox runtime, the marimo-lens AI context
extension and the pydantic-ai agent framework to the core notebook.  The Loro real-time collaboration bindings
are propagated by the core package; the Copilot LSP remains unavailable.")))
