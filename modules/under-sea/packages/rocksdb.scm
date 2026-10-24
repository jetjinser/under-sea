;;; Newer RocksDB for the SeaweedFS cgo filer backend.  grocksdb 1.11 uses
;;; the slice/checkpoint APIs introduced in RocksDB 11, which are absent from
;;; the 10.x package in the pinned channel.

(define-module (under-sea packages rocksdb)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (gnu packages databases)
  #:export (rocksdb-11))

(define-public rocksdb-11
  (package
    (inherit rocksdb)
    (version "11.8.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/facebook/rocksdb/archive/refs/tags/v"
             version ".tar.gz"))
       (sha256
        (base32 "1zqsjbl1ly8s6y8np86xcx4ad2p9knjdqk2g0g7g876blwk9g3b1"))))
    ;; The upstream test suite is large and not needed for the SeaweedFS
    ;; consumer; the inherited build options and inputs are otherwise reused.
    (arguments (list #:tests? #f))))
