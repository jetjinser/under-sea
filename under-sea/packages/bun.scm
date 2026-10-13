;;; Bun runtime for Hermes/Pi standalone builds (prebuilt exception).
(define-module (under-sea packages bun)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages base)
  #:use-module (gnu packages elf))

(define-public bun-for-hermes
  (package
    (name "bun-for-hermes")
    (version "1.4.2")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/oven-sh/bun/releases/download/bun-v"
             version "/bun-linux-x64.zip"))
       (sha256
        (base16-string->bytevector
         "36368faef7527875d5ffa52e53cd48021741f2a83eb6208a8dd64068d422a913"))))
    (build-system gnu-build-system)
    (native-inputs (list unzip patchelf))
    (arguments
     (list
      #:substitutable? #f
      ;; Bun is a self-hosted prebuilt binary.  Only its ELF interpreter is
      ;; rewritten: adding an rpath makes the large image segfault, and a
      ;; wrapper would break `bun build --compile' (which needs
      ;; /proc/self/exe to be the real binary).
      #:validate-runpath? #f
      #:modules '((guix build gnu-build-system) (guix build utils))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'build)
          (delete 'check)
          (replace 'install
            (lambda _
              (install-file (car (find-files "." "^bun$"))
                            (string-append #$output "/bin"))))
          (add-after 'install 'patch-interpreter
            (lambda _
              (invoke "patchelf" "--set-interpreter"
                      #$(file-append glibc "/lib/ld-linux-x86-64.so.2")
                      (string-append #$output "/bin/bun")))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://bun.sh")
    (synopsis "Bun JavaScript/TypeScript runtime (prebuilt exception)")
    (description "This package deploys the upstream prebuilt Bun runtime used
to produce Pi's standalone @file{pi} executable.  Bun bootstraps itself with a
prebuilt binary and is not built from source here, so it is recorded as a
source-unavailable exception.")
    (license license:expat)))
