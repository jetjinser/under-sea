;;; Shared build arguments for PyPI sdists that use uv-dynamic-versioning.
;;; The pinned plugin has no VCS history in a source archive, so builds supply
;;; the authoritative version explicitly.

(define-module (under-sea packages python-uv)
  #:use-module (guix gexp)
  #:export (uv-dynamic-version-arguments))

(define (uv-dynamic-version-arguments version)
  "Return pyproject-build-system arguments that set VERSION for the
uv-dynamic-versioning Hatch plugin and skip upstream tests."
  (list #:tests? #f
        #:phases
        #~(modify-phases %standard-phases
            (add-before 'build 'set-version
              (lambda _
                (setenv "UV_DYNAMIC_VERSIONING_BYPASS" #$version))))))
