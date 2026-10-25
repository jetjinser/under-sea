;;; Source-only SeaweedFS package for the pinned channels.scm.
(define-module (under-sea packages seaweedfs)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages databases)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages commencement)
  #:use-module (gnu packages golang)
  #:use-module (gnu packages pkg-config)
  #:use-module (under-sea packages rocksdb)
  #:use-module (under-sea packages seaweedfs-lock)
  #:use-module (under-sea packages seaweedfs-rocksdb-lock)
  #:use-module (under-sea packages seaweedfs-full-lock))

(define-public seaweedfs
  (package
    (name "seaweedfs")
    (version %seaweedfs-version)
    (source %seaweedfs-source)
    (properties '((upstream-github "seaweedfs/seaweedfs")))
    ;; Go modules are assembled into a local module proxy.  Each archive and
    ;; metadata file is a separately hashed origin, fetched before the build.
    (build-system gnu-build-system)
    (native-inputs (list go-1.26))
    (arguments
     (list
      #:substitutable? #f
      #:modules '((guix build gnu-build-system)
                  (guix build utils)
                  (ice-9 match))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (add-before 'build 'prepare-go
            (lambda _
              (let ((proxy (string-append (getcwd) "/module-proxy")))
                (for-each
                 (match-lambda
                   ((relative source)
                    (let ((destination (string-append proxy "/" relative)))
                      (mkdir-p (dirname destination))
                      (copy-file source destination))))
                 '#$%seaweedfs-module-files)
                (setenv "GOPROXY" (string-append "file://" proxy)))
              (setenv "GOSUMDB" "off")
              (setenv "GOTOOLCHAIN" "local")
              (setenv "GOWORK" "off")
              (setenv "GOENV" "off")
              ;; The default feature set is pure Go; optional stores which need
              ;; cgo (for example rocksdb) are deliberately not enabled.
              (setenv "CGO_ENABLED" "0")
              (setenv "GOFLAGS" "-mod=readonly -buildvcs=false -trimpath")
              (setenv "GOPATH" (string-append (getcwd) "/gopath"))
              (setenv "GOCACHE" (string-append (getcwd) "/go-cache"))
              (setenv "GOMODCACHE" (string-append (getcwd) "/go-modules"))))
          (replace 'build
            (lambda* (#:key parallel-build? #:allow-other-keys)
              (with-directory-excursion "weed"
                (invoke "go" "build"
                        "-p" (if parallel-build?
                                 (number->string (parallel-job-count))
                                 "1")
                        "-ldflags=-s -w -buildid="
                        "-o" "weed" "."))))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                ;; Upstream's tests need network services and multi-node
                ;; clusters; exercise the built command-line surface instead.
                (invoke "./weed/weed" "version")
                (invoke "./weed/weed" "help"))))
          (replace 'install
            (lambda _
              ;; The gnu-build-system installs LICENSE from the source root.
              (install-file "weed/weed" (string-append #$output "/bin")))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/seaweedfs/seaweedfs")
    (synopsis "Distributed storage system for files, objects and blobs")
    (description
     "SeaweedFS is a distributed storage system for blobs, objects, files and
data lakes.  It provides O(1) disk seeks, an S3-compatible API, erasure
coding, replication and a filer with POSIX-like access.  This package builds
the @command{weed} server and client from source with the default pure-Go
feature set.")
    (license license:asl2.0)))


;;; The RocksDB filer backend is behind the upstream `rocksdb' build tag and
;;; needs cgo plus the RocksDB C++ library.  It has its own module lock because
;;; `go list' must resolve the tag-specific import graph.
(define-public seaweedfs-rocksdb
  (package
    (inherit seaweedfs)
    (name "seaweedfs-rocksdb")
    (native-inputs
     (append (package-native-inputs seaweedfs)
             (list (list "gcc-toolchain" gcc-toolchain)
                   (list "pkg-config" pkg-config))))
    (inputs
     (list (list "rocksdb" rocksdb-11)
           (list "gcc:lib" gcc "lib")
           (list "zlib" zlib)
           (list "bzip2" bzip2)
           (list "snappy" snappy)
           (list "lz4" lz4)
           (list "zstd:lib" zstd "lib")))
    (arguments
     (substitute-keyword-arguments (package-arguments seaweedfs)
       ((#:phases phases #~%standard-phases)
        #~(modify-phases #$phases
            (replace 'prepare-go
              (lambda* (#:key inputs #:allow-other-keys)
                (let* ((rocksdb (assoc-ref inputs "rocksdb"))
                       (gcc-lib (assoc-ref inputs "gcc:lib"))
                       (zlib (assoc-ref inputs "zlib"))
                       (bzip2 (assoc-ref inputs "bzip2"))
                       (snappy (assoc-ref inputs "snappy"))
                       (lz4 (assoc-ref inputs "lz4"))
                       (zstd (assoc-ref inputs "zstd:lib"))
                       (proxy (string-append (getcwd) "/module-proxy")))
                  (for-each
                   (match-lambda
                     ((relative source)
                      (let ((destination
                             (string-append proxy "/" relative)))
                        (mkdir-p (dirname destination))
                        (copy-file source destination))))
                   '#$%seaweedfs-rocksdb-module-files)
                  (setenv "GOPROXY" (string-append "file://" proxy))
                  (setenv "CGO_CPPFLAGS"
                          (string-append "-I" rocksdb "/include"))
                  (setenv "CGO_CFLAGS"
                          (string-append "-I" rocksdb "/include"))
                  (setenv "CGO_CXXFLAGS"
                          (string-append "-I" rocksdb "/include"))
                  (setenv "CGO_LDFLAGS"
                          (string-append
                           "-L" rocksdb "/lib"
                           " -L" gcc-lib "/lib"
                           " -L" zlib "/lib"
                           " -L" bzip2 "/lib"
                           " -L" snappy "/lib"
                           " -L" lz4 "/lib"
                           " -L" zstd "/lib"
                           " -lrocksdb -lstdc++ -lm -lz -lbz2 -lsnappy"
                           " -llz4 -lzstd"
                           " -Wl,-rpath," rocksdb "/lib"
                           " -Wl,-rpath," gcc-lib "/lib"
                           " -Wl,-rpath," zlib "/lib"
                           " -Wl,-rpath," bzip2 "/lib"
                           " -Wl,-rpath," snappy "/lib"
                           " -Wl,-rpath," lz4 "/lib"
                           " -Wl,-rpath," zstd "/lib")))
                (setenv "GOSUMDB" "off")
                (setenv "GOTOOLCHAIN" "local")
                (setenv "GOWORK" "off")
                (setenv "GOENV" "off")
                (setenv "CGO_ENABLED" "1")
                (setenv "CC" "gcc")
                (setenv "CXX" "g++")
                (setenv "GOFLAGS"
                        "-mod=readonly -buildvcs=false -trimpath")
                (setenv "GOPATH" (string-append (getcwd) "/gopath"))
                (setenv "GOCACHE" (string-append (getcwd) "/go-cache"))
                (setenv "GOMODCACHE"
                        (string-append (getcwd) "/go-modules"))))
            (replace 'build
              (lambda* (#:key parallel-build? #:allow-other-keys)
                (with-directory-excursion "weed"
                  (invoke "go" "build"
                          "-tags=rocksdb"
                          "-p" (if parallel-build?
                                   (number->string (parallel-job-count))
                                   "1")
                          "-ldflags=-s -w -buildid="
                          "-o" "weed" "."))))))))
    (synopsis "SeaweedFS with the RocksDB filer backend")
    (description
     "This variant of SeaweedFS enables the optional RocksDB filer store via
the upstream @code{rocksdb} build tag.  It links against the RocksDB C++
library and the compression libraries required by its cgo bindings; the
default @code{seaweedfs} package remains pure Go.")))


;;; A single binary with all the optional filer stores that can be enabled
;;; without additional native libraries: RocksDB (cgo), SQLite (modernc),
;;; TiKV, YDB and Tarantool.  The module lock is generated with the same tag
;;; set; the CGO inputs are inherited from seaweedfs-rocksdb.
(define-public seaweedfs-full
  (package
    (inherit seaweedfs-rocksdb)
    (name "seaweedfs-full")
    (arguments
     (substitute-keyword-arguments (package-arguments seaweedfs-rocksdb)
       ((#:phases phases #~%standard-phases)
        #~(modify-phases #$phases
            (replace 'prepare-go
              (lambda* (#:key inputs #:allow-other-keys)
                (let* ((rocksdb (assoc-ref inputs "rocksdb"))
                       (gcc-lib (assoc-ref inputs "gcc"))
                       (zlib (assoc-ref inputs "zlib"))
                       (bzip2 (assoc-ref inputs "bzip2"))
                       (snappy (assoc-ref inputs "snappy"))
                       (lz4 (assoc-ref inputs "lz4"))
                       (zstd (assoc-ref inputs "zstd:lib"))
                       (proxy (string-append (getcwd) "/module-proxy")))
                  (for-each
                   (match-lambda
                     ((relative source)
                      (let ((destination
                             (string-append proxy "/" relative)))
                        (mkdir-p (dirname destination))
                        (copy-file source destination))))
                   '#$%seaweedfs-full-module-files)
                  (setenv "GOPROXY" (string-append "file://" proxy))
                  (setenv "CGO_CPPFLAGS"
                          (string-append "-I" rocksdb "/include"))
                  (setenv "CGO_CFLAGS"
                          (string-append "-I" rocksdb "/include"))
                  (setenv "CGO_CXXFLAGS"
                          (string-append "-I" rocksdb "/include"))
                  (setenv "CGO_LDFLAGS"
                          (string-append
                           "-L" rocksdb "/lib"
                           " -L" gcc-lib "/lib"
                           " -L" zlib "/lib"
                           " -L" bzip2 "/lib"
                           " -L" snappy "/lib"
                           " -L" lz4 "/lib"
                           " -L" zstd "/lib"
                           " -lrocksdb -lstdc++ -lm -lz -lbz2 -lsnappy"
                           " -llz4 -lzstd"
                           " -Wl,-rpath," rocksdb "/lib"
                           " -Wl,-rpath," gcc-lib "/lib"
                           " -Wl,-rpath," zlib "/lib"
                           " -Wl,-rpath," bzip2 "/lib"
                           " -Wl,-rpath," snappy "/lib"
                           " -Wl,-rpath," lz4 "/lib"
                           " -Wl,-rpath," zstd "/lib")))
                (setenv "GOSUMDB" "off")
                (setenv "GOTOOLCHAIN" "local")
                (setenv "GOWORK" "off")
                (setenv "GOENV" "off")
                (setenv "CGO_ENABLED" "1")
                (setenv "CC" "gcc")
                (setenv "CXX" "g++")
                (setenv "GOFLAGS"
                        "-mod=readonly -buildvcs=false -trimpath")
                (setenv "GOPATH" (string-append (getcwd) "/gopath"))
                (setenv "GOCACHE" (string-append (getcwd) "/go-cache"))
                (setenv "GOMODCACHE"
                        (string-append (getcwd) "/go-modules"))))
            (replace 'build
              (lambda* (#:key parallel-build? #:allow-other-keys)
                (with-directory-excursion "weed"
                  (invoke "go" "build"
                          "-tags=rocksdb,sqlite,tikv,ydb,tarantool"
                          "-p" (if parallel-build?
                                   (number->string (parallel-job-count))
                                   "1")
                          "-ldflags=-s -w -buildid="
                          "-o" "weed" "."))))))))
    (synopsis "SeaweedFS with RocksDB, SQLite, TiKV, YDB and Tarantool")
    (description
     "This variant of SeaweedFS enables the optional RocksDB, SQLite, TiKV,
YDB and Tarantool filer stores.  RocksDB and its compression libraries are
linked via cgo; the other stores are pure Go.  The default @code{seaweedfs}
package remains a small pure-Go build.")))
