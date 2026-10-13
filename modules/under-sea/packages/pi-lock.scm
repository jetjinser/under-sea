;;; Locked Pi source release and coding-agent install lock (earendil-works/pi).
(define-module (under-sea packages pi-lock)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16))

(define-public %pi-version "1.0.4")

(define-public %pi-source
  (origin
    (method url-fetch)
    (uri "https://github.com/earendil-works/pi/releases/download/v1.0.4/pi-1.0.4-source.tar.gz")
    (file-name "pi-1.0.4-source.tar.gz")
    (sha256
     (base16-string->bytevector
      "82407ae8e2446ec6d9d67eddf8dcf0cc813c688c19ab0948ce6c42d4a6001095"))))

(define-public %pi-install-lock
  (origin
    (method url-fetch)
    (uri "https://github.com/earendil-works/pi/releases/download/v1.0.4/pi-coding-agent-install-package-lock.json")
    (file-name "pi-coding-agent-install-package-lock.json")
    (sha256
     (base16-string->bytevector
      "35fd666029cb44d3cceb5a372cbacd2aecc478c69daa14898f006af291d4d869"))))
