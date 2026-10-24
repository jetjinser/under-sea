;;; Newer versions of two marimo dependencies that are not yet in the pinned
;;; Guix channel.  They are kept as private under-sea variants so the channel's
;;; own packages are untouched.

(define-module (under-sea packages marimo-deps)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages serialization)
  #:export (python-msgspec-0.22
            python-pymdown-extensions-10.21))

(define-public python-msgspec-0.22
  (package
    (inherit python-msgspec)
    (version "0.22.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://files.pythonhosted.org/packages/source/m/msgspec/"
             "msgspec-" version ".tar.gz"))
       (sha256
        (base32 "0f6fzjpja9z5sm078cjyb3cbnq9bgcvksalcbpiry5b9955644qa"))))
    ;; The Guix 0.20 recipe regenerates a source header from a `scripts/'
    ;; directory that the 0.22 PyPI sdist does not ship; the sdist already
    ;; contains the generated header.
    (arguments (list #:tests? #f))
    (home-page "https://github.com/msgspec/msgspec")))

(define-public python-pymdown-extensions-10.21
  (package
    (inherit python-pymdown-extensions)
    (version "10.21.2")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://files.pythonhosted.org/packages/source/p/"
             "pymdown-extensions/pymdown_extensions-" version ".tar.gz"))
       (sha256
        (base32 "1p7vj3xb79dq0zcg6ygsyd7x6y6rf7mcnpg3k5kdy3hxi9dmmxf3"))))))
