;;; Generated pin data for opencode-v1.
(define-module (under-sea packages opencode-v1-pin)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base32)
  #:export (%opencode-v1-version %opencode-v1-source))

(define-public %opencode-v1-version "1.19.4")

(define-public %opencode-v1-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/anomalyco/opencode/tar.gz/refs/tags/v1.19.4")
    (file-name "opencode-1.19.4.tar.gz")
    (sha256
     (base32 "1fyqhi2k74lihv1wbhyznjqszjn3izdjdpcyzdz4mpxj0p83wm9f"))))
