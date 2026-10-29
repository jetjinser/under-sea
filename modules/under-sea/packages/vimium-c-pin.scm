;;; Generated pin data for Vimium C.
(define-module (under-sea packages vimium-c-pin)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix base32)
  #:export (%vimium-c-version %vimium-c-commit %vimium-c-source))

(define-public %vimium-c-version "2.12.3")
(define-public %vimium-c-commit "31885269460a3f0635c7dd69176ed387ad138e96")
(define-public %vimium-c-source
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://ghfast.top/https://github.com/gdh1995/vimium-c")
          (commit %vimium-c-commit)))
    (file-name "vimium-c-2.12.3-checkout")
    (sha256
     (base32 "1r4633v748c5hcqxai2m69x58q384pzsvrlg3cr9zmqa9qsxl1hh"))))
