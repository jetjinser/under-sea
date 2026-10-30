;;; The exact patched zsh revision used by Codex's release workflow.
(define-module (under-sea packages codex-zsh)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (gnu packages shells)
  #:use-module (under-sea packages codex-zsh-lock))

;; Anchor for local-file references next to this module.  In compiled
;; channel contexts current-filename is #f, so fall back to locating this
;; very file through %load-path.
(define %source-directory
  (dirname
   (or (current-filename)
       (search-path %load-path "under-sea/packages/codex-zsh.scm")
       (error "under-sea/packages/codex-zsh.scm not found on %load-path"))))

(define-public codex-zsh
  (package
    (inherit zsh)
    (name "codex-zsh")
    (version %codex-zsh-version)
    (source %codex-zsh-source)
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
                      #$(local-file (string-append %source-directory
                                                   "/patches/codex-zsh-exec-wrapper.patch")))
              ;; Util/preconfig hides failures inside a pipeline. Run the
              ;; root .preconfig explicitly so missing tools fail the build.
              (invoke "sh" ".preconfig")))
          (add-before 'configure 'fix-shell-paths
            (lambda _
              (with-fluids ((%default-port-encoding #f))
                (substitute* '("configure" "configure.ac" "Src/exec.c"
                               "Src/mkmakemod.sh" "Config/installfns.sh" "Config/defs.mk.in")
                  (("/bin/sh") (which "sh"))))))
          (add-after 'install 'smoke-exec-wrapper
            (lambda _
              (let ((wrapper (string-append (getcwd) "/exec-wrapper-smoke")))
                (call-with-output-file wrapper
                  (lambda (port)
                    (format port "#!~a~%: > exec-wrapper-ran~%exec \"$@\"~%"
                            (which "sh"))))
                (chmod wrapper #o755)
                (setenv "EXEC_WRAPPER" wrapper)
                (invoke (string-append #$output "/bin/zsh") "-fc"
                        (string-append (which "env") " true"))
                (unless (file-exists? "exec-wrapper-ran")
                  (error "Codex zsh did not invoke EXEC_WRAPPER")))))
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
