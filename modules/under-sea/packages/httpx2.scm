;;; Newer httpx2/httpcore2 releases for the current pydantic-ai stack.
;;; The pinned channel ships 2.4.0; pydantic-ai 2.61 requires httpx2 >= 2.7.

(define-module (under-sea packages httpx2)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system pyproject)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages python-xyz)
  #:use-module (under-sea packages hermes-build-tools)
  #:use-module (under-sea packages python-uv)
  #:export (python-httpcore2-2.16
            python-httpx2-2.16))

(define-public python-httpcore2-2.16
  (package
    (name "python-httpcore2")
    (version "2.16.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://files.pythonhosted.org/packages/c0/61/"
             "afa9d6b7452f9eca73f73d45324eb0bb52f098fd5e6049bf6b8263be9b4e/"
             "httpcore2-" version ".tar.gz"))
       (sha256
        (base32 "0hw688s6a4lkkrspj5jmqa76yil7z3gpfiimv0f7xcb36m0x0b67"))))
    (build-system pyproject-build-system)
    (arguments (uv-dynamic-version-arguments "2.16.0"))
    (native-inputs (list python-hatchling
                         python-hatch-fancy-pypi-readme
                         python-hermes-uv-dynamic-versioning))
    (propagated-inputs (list python-h11
                             python-truststore
                             python-anyio
                             python-h2
                             python-socksio
                             python-trio))
    (home-page "https://github.com/pydantic/httpx")
    (synopsis "Low-level HTTP client used by httpx2")
    (description "httpcore2 is the transport layer for httpx2, with h11,
HTTP/2 and truststore support.")
    (license license:bsd-3)))

(define-public python-httpx2-2.16
  (package
    (name "python-httpx2")
    (version "2.16.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://files.pythonhosted.org/packages/43/73/"
             "5ca2cedf5e4e50423d1c258877865a6b62793633b561c58499f8aeb33b7e/"
             "httpx2-" version ".tar.gz"))
       (sha256
        (base32 "0zydbdl1zwxprm1w9amavqp06pwy6n6cl3yypdzzzwp8520wjm0d"))))
    (build-system pyproject-build-system)
    (arguments (uv-dynamic-version-arguments "2.16.0"))
    (native-inputs (list python-hatchling
                         python-hatch-fancy-pypi-readme
                         python-hermes-uv-dynamic-versioning))
    (propagated-inputs (list python-anyio
                             python-httpcore2-2.16
                             python-idna
                             python-truststore
                             python-typing-extensions))
    (home-page "https://github.com/pydantic/httpx")
    (synopsis "Next-generation HTTP client for Python")
    (description "httpx2 is the HTTP client used by current pydantic-ai
releases; this variant provides the 2.16 API required by pydantic-ai 2.61.")
    (license license:bsd-3)))
