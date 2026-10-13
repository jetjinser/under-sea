;;; Picovoice Porcupine wake-word engine for Hermes (prebuilt exception).
(define-module (under-sea packages hermes-porcupine)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages base)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages python))

(define-public porcupine-for-hermes
  (package
    (name "porcupine-for-hermes")
    (version "4.0.3")
    (source
     (origin
       (method url-fetch)
       (uri "https://files.pythonhosted.org/packages/b2/37/db209e19c4e1d931d1752bdf05c763f119271bb79661d482bdf5f564f662/pvporcupine-4.0.3.tar.gz")
       (file-name "pvporcupine-4.0.3.tar.gz")
       (sha256
        (base16-string->bytevector
         "87d0e4d743a13c3a15b1fb34a9ced66e14bb1125ae079f2e2c09423364a68386"))
       (modules '((guix build utils)))
       (snippet
        #~(begin
            ;; Keep only the Linux x86_64 engine; the other platform payloads
            ;; are unused here.  The Picovoice engine itself is closed-source
            ;; and only distributed prebuilt (recorded exception).
            (for-each
             (lambda (directory)
               (when (file-exists? directory)
                 (delete-file-recursively directory)))
             '("pvporcupine/lib/mac"
               "pvporcupine/lib/windows"
               "pvporcupine/lib/raspberry-pi"
               "pvporcupine/lib/jetson"
               "pvporcupine/lib/beaglebone"))))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (inputs (list glibc (list gcc "lib")))
    (arguments
     (list
      #:substitutable? #f
      #:modules '((guix build gnu-build-system) (guix build utils))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'build)
          (delete 'check)
          (replace 'install
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((site (string-append #$output
                                         "/lib/python3.12/site-packages/pvporcupine"))
                    (lib "pvporcupine/lib/linux/x86_64/libpv_porcupine.so"))
                (copy-recursively "pvporcupine" site)
                (make-file-writable (string-append site "/lib/linux/x86_64/libpv_porcupine.so"))
                (invoke "patchelf" "--set-rpath"
                        (string-append
                         (dirname (search-input-file inputs "lib/libstdc++.so.6")) ":"
                         (dirname (search-input-file inputs "lib/libc.so.6")))
                        (string-append site "/lib/linux/x86_64/libpv_porcupine.so"))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://picovoice.ai/docs/porcupine/")
    (synopsis "Picovoice Porcupine wake-word engine for Hermes (prebuilt)")
    (description "This package provides the @code{pvporcupine} Python module and
its closed-source, prebuilt Linux engine used by the Hermes wake-word runtime.
The engine is only distributed prebuilt, so it is recorded as a
source-unavailable/prebuilt exception; the default keyword files ship with it and
an access key is still required at runtime.")
    (license license:asl2.0)))
