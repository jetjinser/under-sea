;;; codex-session-patcher: a small Python tool that cleans AI refusal replies
;;; from Codex/Claude/OpenCode session files.  The core CLI has no runtime
;;; dependencies; the optional web UI (Vite/FastAPI) is not built here.
;;;
;;; License note: upstream declares MIT in pyproject.toml but ships no LICENSE
;;; file and GitHub reports no license; recorded as MIT per the declaration.
(define-module (under-sea packages codex-session-patcher)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system pyproject)
  #:use-module (gnu packages python-build))

(define %codex-session-patcher-commit "cf7deab2d5b28c1f70f5b5498461848b69024a15")

(define-public codex-session-patcher
  (package
    (name "codex-session-patcher")
    (version "1.5.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://codeload.github.com/ryfineZ/codex-session-patcher/tar.gz/"
             %codex-session-patcher-commit))
       (file-name (string-append "codex-session-patcher-" version ".tar.gz"))
       (sha256
        (base16-string->bytevector
         "52ae43fbf79c6ba53bda9c0cf089f0235040bc9ca6b1664022855e56247c74b3"))))
    (build-system pyproject-build-system)
    (native-inputs (list python-setuptools python-wheel))
    (arguments
     (list
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'drop-web-interface
            (lambda _
              ;; The web UI needs the optional FastAPI stack (and a Vite build);
              ;; this package ships only the dependency-free CLI.
              (substitute* "pyproject.toml"
                (("include = \\[\"codex_session_patcher\\*\", \"web\\*\"\\]")
                 "include = [\"codex_session_patcher*\"]")
                (("codex-patcher-web = \"web.backend.main:run_server\"\n") "")))))))
    (home-page "https://github.com/ryfineZ/codex-session-patcher")
    (synopsis "Clean AI refusal replies from coding session files")
    (description "This package provides @command{codex-patcher}, a small Python
tool that detects and removes AI refusal responses from Codex, Claude Code and
OpenCode session files, with optional CTF/pentest prompt handling.  The core
command-line tool has no runtime dependencies; the optional web interface
(Vite front end and FastAPI back end) is not built by this package.")
    (license license:expat)))
