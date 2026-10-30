;;; Exact zsh source used by Codex's managed shell component.
(define-module (under-sea packages codex-zsh-lock)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:export (%codex-zsh-version %codex-zsh-commit %codex-zsh-source
            %codex-zsh-patch-sha256))

(define-public %codex-zsh-version "5.9.0.3-test-77045ef")
(define-public %codex-zsh-commit
  "77045ef899e53b9598bebc5a41db93a548a40ca6")
(define-public %codex-zsh-source
  (origin
    (method url-fetch)
    (uri (string-append "https://codeload.github.com/zsh-users/zsh/tar.gz/"
                        %codex-zsh-commit))
    (file-name "codex-zsh-77045ef.tar.gz")
    (sha256 (base16-string->bytevector
             "4dbbd45e64b4afa03d7cb363c2b1583619187f3d1508707fc532e4a77d5e6597"))))

(define-public %codex-zsh-patch-sha256
  "696b7d923b8071554d00e811afb9a08fcad4baada796f7314d12ecd72d06152c")
