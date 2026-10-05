;;; Hermes CLI with an offline, source-built private Python runtime.
(define-module (under-sea packages hermes)
  #:export (make-hermes-package resolve-hermes-python-components)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 match)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages python-science)
  #:use-module (gnu packages rust)
  #:use-module (gnu packages build-tools)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages protobuf)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages libffi)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages image)
  #:use-module (gnu packages video)
  #:use-module (gnu packages audio)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages ssh)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages crypto)
  #:use-module (gnu packages maths)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages sqlite)
  #:use-module (gnu packages serialization)
  #:use-module (under-sea packages hermes-lock)
  #:use-module (under-sea packages hermes-build-tools)
  #:use-module ((under-sea packages hermes-interfaces-lock) #:prefix interfaces:)
  #:use-module ((under-sea packages hermes-integrations-lock) #:prefix integrations:))

(define-public python-for-hermes
  (package
    (inherit python)
    (name "python-for-hermes")
    (inputs (modify-inputs (package-inputs python)
              (replace "sqlite" sqlite-next)))
    (arguments
     (substitute-keyword-arguments (package-arguments python)
       ((#:tests? tests? #t) #f)))))

(define-public python-for-hermes-wrapper
  (package
    (inherit python-wrapper)
    (name "python-for-hermes-wrapper")
    (propagated-inputs (list (list "python" python-for-hermes)))))

(define (resolve-hermes-python-components requirements)
  ;; Resolve exact recipe/output identities without introducing circular
  ;; imports from the Hermes factory into the native engine modules.
  (map (match-lambda
         ((name version module recipe output)
          (let ((provider
                 (module-ref
                  (resolve-interface
                   `(under-sea packages ,(string->symbol module)))
                  (string->symbol recipe))))
            (unless (and (package? provider)
                         (string=? version (package-version provider))
                         (member output (package-outputs provider)))
              (error "Hermes component recipe/version/output mismatch"
                     name version module recipe output))
            (list name version (gexp-input provider output)))))
       requirements))

(define* (make-hermes-package package-name python-sources crate-sources interfaces? git-sources
                             #:optional (python-components '()))
  (let ((source-names (map car python-sources))
        (component-names (map car python-components)))
    (unless (= (length component-names)
               (length (delete-duplicates component-names)))
      (error "Repeated independent Python component" component-names))
    (when (any (lambda (name) (member name source-names)) component-names)
      (error "Python component is also present in the sdist build list"
             component-names)))
  (package
    (name package-name)
    (version %hermes-version)
    (source %hermes-source)
    (build-system gnu-build-system)
    (native-inputs
     (append
      (list rust (list rust "cargo") maturin pkg-config protobuf cmake
           python-for-hermes python-pypa-build python-installer
           python-setuptools python-wheel python-hatchling python-hatch-vcs
           python-hatch-fancy-pypi-readme python-flit-core python-setuptools-scm
           python-cython pybind11 python-pdm-backend python-poetry-core)
      (if interfaces? (list autoconf automake libtool python-expandvars python-pkgconfig
                            python-hermes-uv-dynamic-versioning) '())
      ;; Narwhals' locked sdist uses uv_build, not setuptools or Hatch.
      ;; The fixed channel supplies the source-defined backend in its 0.11
      ;; range, including its explicit Guix uv executable dependency.
      (if (assoc "narwhals" python-sources) (list python-uv-build) '())
      ;; Preserve SciPy's default Fortran and Pythran kernel compilation.
      ;; This channel's Pythran 0.18.1 commit meets SciPy's >=0.18.1,<0.19.
      (if (assoc "scipy" python-sources) (list gfortran python-pythran) '())
      (if (pair? git-sources) (list python-setuptools-rust python-meson
                                   python-hermes-coherent-licensed
                                   python-hermes-hatch-teams-build) '())))
    (inputs (append (list python-for-hermes openssl libffi zlib libjpeg-turbo libpng libtiff libwebp
                         libheif libyaml git openssh bash-minimal)
                    (if (pair? git-sources) (list olm openblas) '())
                    (if (assoc "pynacl" python-sources) (list libsodium) '())
                    (if (assoc "sounddevice" python-sources) (list portaudio) '())
                    (if (assoc "av" python-sources) (list ffmpeg) '())))
    (arguments
     (list
      #:substitutable? #f
      ;; Functional checks are deferred until all component combinations are
      ;; built. The installed smoke-check phase must honor that boundary too.
      #:tests? #f
      #:modules '((guix build gnu-build-system) (guix build utils)
                  (ice-9 match) (srfi srfi-1))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (add-before 'build 'prepare-offline-inputs
            (lambda _
              (for-each
               (match-lambda
                 ((name entries)
                  (call-with-output-file name
                    (lambda (port)
                      (for-each
                       (match-lambda
                         ((a b source) (format port "~a\t~a\t~a~%" a b source)))
                       entries)))))
               (list (list "python-sources.tsv" '#$python-sources)
                     (list "crate-sources.tsv" '#$crate-sources)))
              (setenv "NIX_BUILD_CORES" (number->string (min 4 (parallel-job-count))))
              (when #$(and (assoc "sounddevice" python-sources) #t)
                (setenv "HERMES_PORTAUDIO_LIBRARY"
                        #$(and (assoc "sounddevice" python-sources)
                               (file-append portaudio "/lib/libportaudio.so"))))
              (call-with-output-file "git-sources.tsv"
                (lambda (port)
                  (for-each
                   (match-lambda
                     ((identity name source)
                      (format port "~a\t~a\t~a~%" identity name source)))
                   '#$git-sources)))
              (when #$interfaces? (setenv "HERMES_PACKAGE_ACP" "1"))
              (setenv "HERMES_DISABLE_LAZY_INSTALLS" "1")))
          (replace 'build
            (lambda _
              (unless (null? '#$python-components)
                (call-with-output-file "python-components.tsv"
                  (lambda (port)
                    (for-each
                     (match-lambda
                       ((name version output)
                        (format port "~a\t~a\t~a~%" name version output)))
                     '#$python-components)))
                (invoke #$(file-append python-for-hermes "/bin/python3")
                        #$(local-file "../../scripts/import-hermes-python-components.py")
                        "python-components.tsv" #$output))
              (invoke #$(file-append python-for-hermes "/bin/python3")
                      #$(local-file "../../scripts/build-hermes.py") #$output)
              (invoke "gcc" "-shared" "-fPIC" "-O2" "-Wall" "-Wextra"
                      "-Inative/fts5_cjk/vendor" "native/fts5_cjk/fts5_cjk.c"
                      "-o" "libfts5_cjk.so")))
          (delete 'check)
          (replace 'install
            (lambda _
              (let* ((share (string-append #$output "/share/hermes-agent"))
                     (site (string-append #$output "/lib/python3.12/site-packages")))
                (mkdir-p share)
                (for-each
                 (lambda (directory)
                   (copy-recursively directory (string-append share "/" directory)))
                 '("skills" "optional-skills" "plugins" "locales" "optional-mcps"))
                (install-file "LICENSE" (string-append #$output "/share/doc/hermes-agent"))
                (install-file "libfts5_cjk.so" (string-append share "/lib"))
                (symlink #$(file-append python-for-hermes "/bin/python3")
                         (string-append #$output "/bin/hermes-python"))
                (for-each
                 (lambda (program)
                   (apply wrap-program program
                     `(("PYTHONPATH" ":" prefix (,site))
                       ("GUIX_PYTHONPATH" ":" prefix (,site))
                       ("PYTHONNOUSERSITE" = ("1"))
                       ("HERMES_DISABLE_LAZY_INSTALLS" = ("1"))
                       ("HERMES_BIN" = (,(string-append #$output "/bin/hermes")))
                       ("HERMES_PYTHON" = (,(string-append #$output "/bin/hermes-python")))
                       ("HERMES_FTS5_CJK_SO" = (,(string-append share "/lib/libfts5_cjk.so")))
                       ("HERMES_BUNDLED_SKILLS" = (,(string-append share "/skills")))
                       ("HERMES_OPTIONAL_SKILLS" = (,(string-append share "/optional-skills")))
                       ("HERMES_BUNDLED_PLUGINS" = (,(string-append share "/plugins")))
                       ("HERMES_BUNDLED_LOCALES" = (,(string-append share "/locales")))
                       ("HERMES_OPTIONAL_MCPS" = (,(string-append share "/optional-mcps")))
                       ("PATH" ":" prefix
                        (,#$(file-append git "/bin") ,#$(file-append openssh "/bin")
                         ,#$(file-append bash-minimal "/bin"))))))
                 (find-files (string-append #$output "/bin") "^(hermes|hermes-agent|hermes-python|hermes-acp)$")))))
          (add-after 'install 'smoke-check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (setenv "HERMES_HOME" (string-append (getcwd) "/test-home"))
                (mkdir "installed-check")
                (with-directory-excursion "installed-check"
                  (invoke (string-append #$output "/bin/hermes") "--help")
                  (invoke (string-append #$output "/bin/hermes-python")
                          #$(local-file "../../scripts/check-hermes.py")))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/NousResearch/hermes-agent")
    (synopsis "CLI AI agent with persistent memory and extensible tools")
    (description (if interfaces?
                    "Hermes Agent provides a command-line AI assistant with MCP,
ACP, Google Workspace and dashboard backend dependencies built from source.
Node interfaces and other optional integrations are separate components."
                    "Hermes Agent provides a command-line AI assistant with persistent
memory, skills and local tools.  This package builds its locked core Python and
Rust dependencies from source.  Optional messaging, voice, web and Node user
interfaces are not included."))
    (license license:expat)))

(define-public hermes-agent
  (make-hermes-package "hermes-agent" %hermes-python-sources %hermes-crate-sources #f '()))

(define-public hermes-agent-interfaces
  (make-hermes-package "hermes-agent-interfaces"
                       interfaces:%hermes-python-sources
                       interfaces:%hermes-crate-sources #t '()))

(define-public hermes-agent-integrations
  (make-hermes-package "hermes-agent-integrations"
                       integrations:%hermes-python-sources
                       integrations:%hermes-crate-sources #t
                       integrations:%hermes-git-sources))
