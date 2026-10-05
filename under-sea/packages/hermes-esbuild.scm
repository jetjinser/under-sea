;;; Hermes' locked, source-built Go esbuild executable.
(define-module (under-sea packages hermes-esbuild)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (gnu packages web))

(define-public esbuild-for-hermes
  (package
    (inherit esbuild)
    (name "esbuild-for-hermes")
    (version "0.28.1")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/evanw/esbuild/tar.gz/refs/tags/v0.28.1")
       (file-name "esbuild-0.28.1.tar.gz")
       (sha256 (base16-string->bytevector
                "65c756fa87d43178ac4a5242454c2bd0fde325f8ecf77997f8fa4b88f94d5cd2"))
       (modules '((guix build utils)))
       (snippet #~(delete-file-recursively "npm"))))
    ;; Retain the exact x/sys input selected by the pinned Guix channel.
    (arguments
     (substitute-keyword-arguments (package-arguments esbuild)
       ((#:tests? tests? #t) #f)))))
