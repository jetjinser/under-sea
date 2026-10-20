;;; Autodesk Licensing Service and Identity Manager (proprietary, prebuilt).
;;;
;;; Extracted from the workstation installer in the same Moldflow archive as the
;;; thin-client.  The Autodesk Licensing Service (AdskLicensingService) is a
;;; static Go binary that self-locates relative to its executable; the Agent,
;;; InstHelper, UpdateSupport and Identity Manager are dynamic and only need the
;;; store interpreter plus libstdc++/libgcc_s.  The package is non-substitutable
;;; and not meant to be published (Autodesk EULA).
(define-module (under-sea packages adsk-licensing)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages cpio)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages package-management)
  #:use-module (under-sea packages moldflow))

(define %adsk-licensing-version "16.2.0.15195")

(define-public adsk-licensing
  (package
    (name "adsk-licensing")
    (version %adsk-licensing-version)
    (source
     (origin
       (method url-fetch)
       (uri (string-append "file://localhost" %moldflow-archive))
       (file-name (string-append "Autodesk_MFIU_" version ".tar.bz2"))
       (sha256
        (base16-string->bytevector
         "f48e759290cbf4d11e37cfc928c0acf021426b4aaa3313c080aa600d1158ea29"))))
    (build-system gnu-build-system)
    (native-inputs (list bash-minimal coreutils-minimal tar gzip xz bzip2
                         findutils grep sed cpio rpm))
    (inputs (list `(,gcc "lib")))
    (arguments
     (list
      #:substitutable? #f
      #:validate-runpath? #f
      #:modules '((guix build gnu-build-system) (guix build utils)
                  (srfi srfi-13))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'build)
          (delete 'check)
          (add-after 'unpack 'extract-workstation
            (lambda _
              (let ((installer
                     (car (find-files "."
                                      "^install-workstation-autodesk-moldflow-insight-[0-9].*\\.sh$"))))
                (mkdir-p "payload")
                (invoke "bash" installer "--noexec" "--nox11" "--target"
                        (string-append (getcwd) "/payload")))))
          (replace 'install
            (lambda* (#:key inputs #:allow-other-keys)
              (define (dynamic-elf? file)
                (zero? (status:exit-val
                        (system* "patchelf" "--print-interpreter" file))))
              (let* ((out #$output)
                     (ver #$%adsk-licensing-version)
                     (lic (string-append out "/opt/Autodesk/AdskLicensing"))
                     (loader #$(file-append glibc "/lib/ld-linux-x86-64.so.2"))
                     (gcc-lib (dirname (search-input-file inputs "lib/libstdc++.so.6")))
                     (rpms (map (lambda (p) (string-append (getcwd) "/" p))
                                (list (car (find-files "payload" "^adsklicensing[0-9].*\\.rpm$"))
                                      (car (find-files "payload" "^adskidentitymanager.*\\.rpm$"))))))
                (mkdir-p out)
                (chdir out)
                (for-each
                 (lambda (rpm)
                   (invoke "bash" "-c"
                           (string-append "rpm2cpio '" rpm "' | cpio -idm --quiet")))
                 rpms)

                ;; Patch the interpreter of the dynamic helpers; the bundled
                ;; libraries are found through their own $ORIGIN rpath.
                (for-each
                 (lambda (file)
                   (when (dynamic-elf? file)
                     (invoke "patchelf" "--set-interpreter" loader file)
                     (catch 'invoke-error
                       (lambda () (invoke "patchelf" "--add-rpath" gcc-lib file))
                       (lambda _ #t))))
                 (find-files out ".*"))

                ;; Convenience entry points and the version symlink used by the
                ;; Autodesk tools (/usr/bin and /opt paths are wired by the
                ;; system service via special-files).
                (mkdir-p (string-append out "/bin"))
                (symlink (string-append lic "/" ver
                                       "/AdskLicensingService/AdskLicensingService")
                         (string-append out "/bin/AdskLicensingService"))
                (symlink ver (string-append lic "/Current"))))))))
    (supported-systems '("x86_64-linux"))
    (properties '((max-silent-time . 7200)))
    (home-page "https://www.autodesk.com/support/technical/product/autodesk-licensing-service")
    (synopsis "Autodesk Licensing Service (proprietary exception)")
    (description "This package deploys the Autodesk Licensing Service and
Identity Manager from the Moldflow workstation installer.  The service is
proprietary, distributed under the Autodesk license, and is not built from
source; it is non-substitutable and must be built from a user-supplied archive.
Moldflow Insights solvers rely on it to check out licenses.")
    (license (license:non-copyleft "https://www.autodesk.com/company/legal-notices-trademarks/software-license-agreements"))))
