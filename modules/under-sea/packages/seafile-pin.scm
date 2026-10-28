;;; Generated pin data for the Seafile client.
(define-module (under-sea packages seafile-pin)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base32)
  #:export (%seafile-version %seafile-source))

(define-public %seafile-version "9.0.22")

(define-public %seafile-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/haiwen/seafile/tar.gz/refs/tags/v9.0.22")
    (file-name "seafile-9.0.22.tar.gz")
    (sha256
     (base32 "1mf1a4nzykjsx57d01h15qdiykwy98x9j9fcymsc8mpi2dc80qmf"))))
