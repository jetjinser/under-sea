;;; Generated pin data for Strata.
(define-module (under-sea packages strata-pin)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:export (%strata-version %strata-source))

(define-public %strata-version "0.1.44.1")

(define-public %strata-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/Niko1221/Strata/tar.gz/refs/tags/v0.1.44.1")
    (file-name "strata-0.1.44.1.tar.gz")
    (sha256
     (base16-string->bytevector
      "3d6ed3659a90ffbb5f435a9b03d000d1d54a36b9ff2b0d016f761a86b5081728"))))
