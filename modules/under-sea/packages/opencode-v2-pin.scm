;;; Generated pin data for opencode-v2.
(define-module (under-sea packages opencode-v2-pin)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base32)
  #:export (%opencode-v2-version %opencode-v2-source))

(define-public %opencode-v2-version "2.1.4")

(define-public %opencode-v2-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/anomalyco/opencode/tar.gz/refs/tags/v2.1.4")
    (file-name "opencode-2.1.4.tar.gz")
    (sha256
     (base32 "07znbxrld6l7jf4kw8mvlw1s8rqr8a47m7b7v3kz3zq4qnwy25pb"))))
