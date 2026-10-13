;;; Autodesk Moldflow Insight 2027 thin-client (proprietary, prebuilt exception).
;;;
;;; Upstream ships a Makeself self-extracting installer that is not publicly
;;; redistributable (Autodesk EULA).  The user supplies the downloaded archive
;;; (see %moldflow-archive); the package is non-substitutable and is not meant
;;; to be published.  The thin-client is relocatable: its payload is the product
;;; tree plus the Simulation Compute Manager, with the vendored libraries found
;;; through $ORIGIN/../lib.
(define-module (under-sea packages moldflow)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages)
  #:use-module (gnu packages attr)
  #:use-module (gnu packages acl)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages onc-rpc)
  #:use-module (gnu packages kerberos)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages base)
  #:use-module (gnu packages elf)
  #:export (%moldflow-archive))

(define %moldflow-archive
  ;; The installer is obtained from the user's Autodesk account, not from a
  ;; public URL.  Point MOLDFLOW_ARCHIVE at the downloaded archive.
  (or (getenv "MOLDFLOW_ARCHIVE")
      "/home/jinser/Autodesk_MFIU_2027_Multilingual_Linux_64bit.tar.bz2"))

(define-public moldflow-insight-thinclient
  (package
    (name "moldflow-insight-thinclient")
    (version "2027.0.2")
    (source
     (origin
       (method url-fetch)
       ;; 'localhost' keeps the URI parseable by the offline source-uri lint
       ;; checker; the path is what the file downloader uses.
       (uri (string-append "file://localhost" %moldflow-archive))
       (file-name (string-append "Autodesk_MFIU_" version ".tar.bz2"))
       (sha256
        (base16-string->bytevector
         "f48e759290cbf4d11e37cfc928c0acf021426b4aaa3313c080aa600d1158ea29"))))
    (build-system gnu-build-system)
    (native-inputs (list bash-minimal coreutils-minimal tar gzip xz bzip2
                         patchelf findutils grep sed))
    ;; Vendor libraries the product does not bundle; everything else is found
    ;; through the product's own $ORIGIN/../lib rpath.
    (inputs (list attr acl (list gfortran "lib") libtirpc mit-krb5
                  openssl-1.1 (list util-linux "lib")))
    (arguments
     (list
      #:substitutable? #f
      ;; Prebuilt, self-contained tree with its own rpath; not rewritten.
      #:validate-runpath? #f
      #:modules '((guix build gnu-build-system) (guix build utils)
                  (srfi srfi-13) (ice-9 binary-ports))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'build)
          (delete 'check)
          (add-after 'unpack 'extract-thinclient
            (lambda _
              ;; Only the thin-client installer, not the workstation one.
              (let ((installer
                     (car (find-files "."
                                      "^install-thinclient-autodesk-moldflow-insight-[0-9].*\\.sh$"))))
                (mkdir-p "payload")
                (invoke "bash" installer "--noexec" "--nox11" "--target"
                        (string-append (getcwd) "/payload")))))
          (replace 'install
            (lambda* (#:key inputs #:allow-other-keys)
              (define (libdir file)
                (dirname (search-input-file inputs file)))
              (define (elf? file)
                (catch 'system-error
                  (lambda ()
                    (let* ((port (open-file file "rb"))
                           (b (get-u8 port)))
                      (close-port port)
                      (eqv? b 127)))
                  (lambda _ #f)))
              (define (executable? file)
                (zero? (status:exit-val (system* "test" "-x" file))))
              (let* ((out   #$output)
                     (prod  (string-append out "/autodesk-moldflow-insight-2027"))
                     (scm   (string-append out "/opt/Autodesk/simulation-compute2"))
                     (libdirs (map libdir
                                   '("lib/libgfortran.so.5"
                                     "lib/libstdc++.so.6"
                                     "lib/libgcc_s.so.1"
                                     "lib/libtirpc.so.3"
                                     "lib/libgssapi_krb5.so.2"
                                     "lib/libssl.so.1.1"
                                     "lib/libcrypto.so.1.1"
                                     "lib/libuuid.so.1"
                                     "lib/libattr.so.1"
                                     "lib/libacl.so.1")))
                     (rpath (string-join libdirs ":"))
                     (loader #$(file-append glibc "/lib/ld-linux-x86-64.so.2")))

                ;; Unpack the product and Simulation Compute Manager trees.
                (mkdir-p out)
                (invoke "tar" "xzf"
                        (car (find-files "payload" "^autodesk-moldflow-insight-[0-9].*\\.tar\\.gz$"))
                        "-C" out)
                (invoke "tar" "xzf"
                        (car (find-files "payload" "^simulation-compute-[0-9].*\\.tgz$"))
                        "-C" out)
                (copy-file (car (find-files "payload" "^AdlmThinClientCustomEnv\\.xml$"))
                           (string-append out "/AdlmThinClientCustomEnv.xml"))
                (for-each (lambda (f) (when (file-exists? f) (chmod f #o644)))
                          (list (string-append scm "/bin/ComputeProvisioner.config.json")
                                (string-append scm "/bin/ComputeService.config.json")))

                ;; Rewrite the ELF interpreter (executables) and expose the
                ;; vendor libraries through an absolute rpath; the product's own
                ;; $ORIGIN/../lib rpath is preserved by --add-rpath.
                (for-each
                 (lambda (file)
                   (when (elf? file)
                     (let ((so? (string-contains (basename file) ".so")))
                       (when (and (not so?) (executable? file))
                         (catch 'invoke-error
                           (lambda () (invoke "patchelf" "--set-interpreter" loader file))
                           (lambda _ #t)))
                       (catch 'invoke-error
                         (lambda () (invoke "patchelf" "--add-rpath" rpath file))
                         (lambda _ #t)))))
                 (find-files out ".*"))

                ;; Register the product with the Simulation Compute Manager.
                (let ((config (string-append out "/insight.config.json")))
                  (copy-file (string-append prod "/lib/insight.config.json.in") config)
                  (chmod config #o644)
                  (substitute* config
                    (("MF_INSIGHT_HOME") (string-append prod "/lib"))
                    (("MF_INSIGHT_SERVICE") "mf2027i")
                    (("MF_INSIGHT_DISPLAYSTRING") "Autodesk Moldflow Insight 2027"))
                  (setenv "SCM_DATAPATH" (string-append out "/Autodesk/SimulationCompute/v2"))
                  (mkdir-p (getenv "SCM_DATAPATH"))
                  (invoke (string-append scm "/bin/ComputeTool")
                          "--config" "merge" "--input" config
                          "--output" (string-append scm "/bin/ComputeProvisioner.config.json")))

                ;; Client environment consumed by the solvers.
                (call-with-output-file (string-append out "/mfclient.env")
                  (lambda (port)
                    (format port "AUTODESK_ADLM_THINCLIENT_ENV=~a/AdlmThinClientCustomEnv.xml; export AUTODESK_ADLM_THINCLIENT_ENV~%" out)
                    (format port "SCM_BASE=~a/bin; export SCM_BASE~%" scm)
                    (format port "SCM_DATAPATH=~a/Autodesk/SimulationCompute/v2; export SCM_DATAPATH~%" out)
                    (format port "MFSYN_HOME=~a; export MFSYN_HOME~%" prod)
                    (format port "PATH=$MFSYN_HOME/bin:$PATH; export PATH~%")
                    (format port "[ -z \"$MFSYN_TMP\" ] && MFSYN_TMP=/tmp~%")
                    (format port "export MFSYN_TMP~%")))

                ;; Point embedded shell scripts (PBS/LSF examples, helpers) at
                ;; the store bash; Guix has no /bin/bash.
                (for-each (lambda (f)
                            (unless (elf? f)
                              (catch 'system-error
                                (lambda () (patch-shebang f))
                                (lambda _ #t))))
                          (find-files out ""))))))))
    (supported-systems '("x86_64-linux"))
    (properties '((max-silent-time . 7200)))
    (home-page "https://www.autodesk.com/products/moldflow")
    (synopsis "Autodesk Moldflow Insight 2027 thin-client (proprietary exception)")
    (description "This package deploys the Autodesk Moldflow Insight 2027
thin-client and Simulation Compute Manager from the vendor installer.  The
solver binaries are proprietary and distributed under the Autodesk license, so
this package is non-substitutable and must be built from a user-supplied
archive.  Licensing (Autodesk Licensing Service) and cluster scheduling are
external and configured separately.")
    (license (license:non-copyleft "https://www.autodesk.com/company/legal-notices-trademarks/software-license-agreements"))))
