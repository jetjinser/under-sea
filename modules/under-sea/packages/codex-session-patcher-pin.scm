;;; Generated pin data for codex-session-patcher.
(define-module (under-sea packages codex-session-patcher-pin)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:export (%codex-session-patcher-version
            %codex-session-patcher-commit
            %codex-session-patcher-source))

(define-public %codex-session-patcher-version "1.5.1")
(define-public %codex-session-patcher-commit
  "cf7deab2d5b28c1f70f5b5498461848b69024a15")
(define-public %codex-session-patcher-source
  (origin
    (method url-fetch)
    (uri (string-append
          "https://codeload.github.com/ryfineZ/codex-session-patcher/tar.gz/"
          %codex-session-patcher-commit))
    (file-name (string-append "codex-session-patcher-"
                              %codex-session-patcher-version ".tar.gz"))
    (sha256
     (base16-string->bytevector
      "52ae43fbf79c6ba53bda9c0cf089f0235040bc9ca6b1664022855e56247c74b3"))))
