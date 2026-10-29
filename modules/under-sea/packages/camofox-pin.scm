;;; Generated pin data for camofox-browser.
(define-module (under-sea packages camofox-pin)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:export (%camofox-version %camofox-source))

(define-public %camofox-version "1.18.1")
(define-public %camofox-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/jo-inc/camofox-browser/tar.gz/refs/tags/v1.18.1")
    (file-name "camofox-browser-for-hermes-1.18.1.tar.gz")
    (sha256
     (base16-string->bytevector
      "c511b0d80b0ed088caec171658198dd99aef6e889b07d101b23913a58bb33f5d"))))
