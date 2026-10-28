;;; Generated pin data for marimo.
(define-module (under-sea packages marimo-pin)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base32)
  #:export (%marimo-version %marimo-source))

(define-public %marimo-version "0.25.2")

(define-public %marimo-source
  (origin
    (method url-fetch)
    (uri (string-append
          "https://files.pythonhosted.org/packages/source/m/marimo/"
          "marimo-" %marimo-version ".tar.gz"))
    (sha256
     (base32 "1c2na1v932mjzxzf7zq080j95mgb84dchzfbyzhjarn6hjn3iyiw"))))
