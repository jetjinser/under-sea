;;; Generated pin data for kilocode; keep the recipe free of volatile values.
(define-module (under-sea packages kilocode-pin)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:export (%kilocode-version %kilocode-source))

(define-public %kilocode-version "7.8.12")

(define-public %kilocode-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/kilo-org/kilocode/tar.gz/refs/tags/v7.8.12")
    (file-name "kilocode-7.8.12.tar.gz")
    (sha256
     (base16-string->bytevector
      "96050bedea55c3be9d976546fc225254cf8c50c5393087ad044d1b39e087f4d7"))))
