;;; Generated pin data for agent-cat.
(define-module (under-sea packages agent-cat-pin)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix base32)
  #:export (%agent-cat-version %agent-cat-commit %agent-cat-source))

(define-public %agent-cat-version "0.0.0-0.c90ce63")
(define-public %agent-cat-commit "c90ce63bc18d50f54dc76d7961a16e2bb8ea74a2")
(define-public %agent-cat-source
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://github.com/jwiegley/agent-cat")
          (commit %agent-cat-commit)))
    (file-name (git-file-name "agent-cat" %agent-cat-version))
    (sha256
     (base32 "0jhiravlvv56my6rkrmayarql5h0155xy14mxjna6k07ybk82n93"))))
