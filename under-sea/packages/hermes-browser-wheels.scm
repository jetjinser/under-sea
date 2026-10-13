;;; Wheel-only Python components for the Hermes browser runtimes.
;;;
;;; These distributions publish no source archive, so they are recorded
;;; prebuilt exceptions and installed verbatim from the upstream wheel.  They
;;; are consumed as independent components by make-hermes-package, never
;;; fetched at runtime.
(define-module (under-sea packages hermes-browser-wheels)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages base)
  #:use-module (gnu packages elf))

(define-public playwright-for-hermes
  (package
    (name "playwright-for-hermes")
    (version "1.62.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://files.pythonhosted.org/packages/43/6b/"
             "b24aebc2b04bffcb342bccf96e287c78b363e1615bed5cea97500cc0393a/"
             "playwright-1.62.0-py3-none-manylinux1_x86_64.whl"))
       (sha256
        (base16-string->bytevector
         "ba33bae6a13b3d9d354c751cb618af357d20fe1d57767cbcce52079bbef17ad3"))))
    (build-system gnu-build-system)
    (native-inputs (list unzip patchelf))
    (arguments
     (list
      #:substitutable? #f
      #:validate-runpath? #f
      #:modules '((guix build gnu-build-system) (guix build utils))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'build)
          (delete 'check)
          ;; unzip preserves the executable bit on the bundled Node driver.
          (replace 'unpack (lambda _ (invoke "unzip" #$source)))
          (replace 'install
            (lambda _
              (copy-recursively "."
                (string-append #$output "/lib/python3.12/site-packages"))))
          ;; The bundled Node driver targets /lib64; point it at the store
          ;; loader so the prebuilt exception can execute under Guix.
          (add-after 'install 'patch-node-interpreter
            (lambda _
              (let ((node (string-append #$output
                                         "/lib/python3.12/site-packages/playwright/driver/node")))
                (chmod node #o755)
                (invoke "patchelf" "--set-interpreter"
                        #$(file-append glibc "/lib/ld-linux-x86-64.so.2")
                        node)))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://playwright.dev/python/")
    (synopsis "Playwright Python bindings (prebuilt wheel exception)")
    (description "This package installs the upstream Playwright Python wheel,
which is only distributed prebuilt and bundles a Node driver.  It is recorded
as a source-unavailable exception and used by the Camoufox controller.")
    (license license:asl2.0)))

(define-public ua-parser-builtins-for-hermes
  (package
    (name "ua-parser-builtins-for-hermes")
    (version "202610")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://files.pythonhosted.org/packages/97/e4/"
             "16e330a5cc8b2fa66d01f1a71c21750693a60fe9fc02751c0d1f43a0269c/"
             "ua_parser_builtins-202610-py3-none-any.whl"))
       (sha256
        (base16-string->bytevector
         "ed4b7c4c665323a5f4b2f118af86369412a9bb92e349a120f58f210127e30586"))))
    (build-system gnu-build-system)
    (native-inputs (list unzip))
    (arguments
     (list
      #:substitutable? #f
      #:validate-runpath? #f
      #:modules '((guix build gnu-build-system) (guix build utils))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'build)
          (delete 'check)
          (replace 'unpack (lambda _ (invoke "unzip" #$source)))
          (replace 'install
            (lambda _
              (copy-recursively "."
                (string-append #$output "/lib/python3.12/site-packages")))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/ua-parser/uap-python")
    (synopsis "ua-parser builtins data (prebuilt wheel exception)")
    (description "This package installs the upstream ua-parser-builtins wheel,
which is only distributed prebuilt (pure data).  It is recorded as a
source-unavailable exception and used by the Camoufox controller.")
    (license license:asl2.0)))
