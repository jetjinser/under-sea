;;; The exact patched zsh revision used by Codex's release workflow.
(define-module (under-sea packages codex-zsh)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (gnu packages shells))

(define-public codex-zsh
  (package
    (inherit zsh)
    (name "codex-zsh")
    (version "5.9.0.3-test-77045ef")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/zsh-users/zsh/tar.gz/77045ef899e53b9598bebc5a41db93a548a40ca6")
       (file-name "codex-zsh-77045ef.tar.gz")
       (sha256 (base16-string->bytevector
                "4dbbd45e64b4afa03d7cb363c2b1583619187f3d1508707fc532e4a77d5e6597"))))
    (arguments
     (list
      #:substitutable? #f
      #:tests? #f
      #:configure-flags #~'("--with-tcsetpgrp" "--enable-pcre" "--disable-site-fndir")
      #:phases
      #~(modify-phases %standard-phases
          (replace 'bootstrap
            (lambda _
              (invoke "patch" "-p1" "-i"
                      #$(local-file "../patches/codex-zsh-exec-wrapper.patch"))
              ;; Util/preconfig hides failures inside a pipeline. Run the
              ;; root .preconfig explicitly so missing tools fail the build.
              (invoke "sh" ".preconfig")))
          (add-before 'configure 'fix-shell-paths
            (lambda _
              (with-fluids ((%default-port-encoding #f))
                (substitute* '("configure" "configure.ac" "Src/exec.c"
                               "Src/mkmakemod.sh" "Config/installfns.sh" "Config/defs.mk.in")
                  (("/bin/sh") (which "sh"))))))
          (replace 'install
            (lambda _
              ;; Git sources have no generated Yodl manpages; the managed
              ;; runtime needs the shell, modules and completion functions.
              (invoke "make" "install.bin" "install.modules" "install.fns")
              (install-file "LICENCE"
                            (string-append #$output "/share/doc/codex-zsh")))))))
    (synopsis "Codex shell with exec interception support")
    (description "This package builds the exact zsh source revision and
EXEC_WRAPPER patch used by Codex.  It is a runtime component for Codex's
managed shell, rather than a replacement for the user's login shell.")))
