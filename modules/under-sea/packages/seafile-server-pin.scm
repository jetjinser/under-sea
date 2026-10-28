;;; Generated pin data for the Seafile server core.
(define-module (under-sea packages seafile-server-pin)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base32)
  #:export (%seafile-server-version %seafile-server-source))

(define-public %seafile-server-version "14.0.9")

(define-public %seafile-server-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/haiwen/seafile-server/tar.gz/refs/tags/v14.0.9-server")
    (file-name "seafile-server-14.0.9.tar.gz")
    (sha256
     (base32 "0jjq5cr29cc7n7h317lhqi8g9al6gvrlz6i621xj9p1qva81fg13"))))
