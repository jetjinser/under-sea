;;; Generated pin data for python-ms-ivy.
(define-module (under-sea packages ivy-pin)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix base32)
  #:export (%ivy-version %ivy-commit %ivy-source))

(define-public %ivy-version "1.8.26")
(define-public %ivy-commit "8858a0241ed37141757b7a051acc24c58e49c2f3")
(define-public %ivy-source
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://github.com/kenmcmil/ivy")
          (commit %ivy-commit)))
    (file-name "ivy-1.8.26-checkout")
    (sha256
     (base32 "0m47cw6bgyn40435dpz7zyn7x09qwdhzwhnhs5q53j4vc4r0xr0d"))))
