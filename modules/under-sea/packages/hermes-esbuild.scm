;;; Hermes' locked, source-built Go esbuild executable.
(define-module (under-sea packages hermes-esbuild)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (gnu packages web))

(define-public (esbuild-for-hermes-version version hash)
  (package
    (inherit esbuild)
    (name "esbuild-for-hermes")
    (version version)
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://codeload.github.com/evanw/esbuild/tar.gz/refs/tags/v"
                           version))
       (file-name (string-append "esbuild-" version ".tar.gz"))
       (sha256 (base16-string->bytevector hash))
       (modules '((guix build utils)))
       (snippet #~(delete-file-recursively "npm"))))
    ;; Retain the exact x/sys input selected by the pinned Guix channel.
    (arguments
     (substitute-keyword-arguments (package-arguments esbuild)
       ((#:tests? tests? #t) #f)))))

(define-public esbuild-for-hermes
  (esbuild-for-hermes-version
   "0.28.1" "65c756fa87d43178ac4a5242454c2bd0fde325f8ecf77997f8fa4b88f94d5cd2"))

(define-public esbuild-for-hermes-0282
  (esbuild-for-hermes-version
   "0.28.2" "300162f899361d9f0263065f8728ef9086dcfc1a3d36bcbc4e0abe5de9c58bf8"))
