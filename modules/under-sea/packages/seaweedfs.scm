;;; Source-only SeaweedFS package for the pinned channels.scm.
(define-module (under-sea packages seaweedfs)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages golang)
  #:use-module (under-sea packages seaweedfs-lock))

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
