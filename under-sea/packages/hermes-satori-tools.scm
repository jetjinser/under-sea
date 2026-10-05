(define-module (under-sea packages hermes-satori-tools)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (gnu packages web)
  #:use-module (gnu packages golang-build)
  #:use-module ((guix licenses) #:prefix license:))

(define %esbuild-satori-x-sys
  (package
    (inherit go-golang-org-x-sys)
    (version "0.0.0-20220715151400-c0bba94af5f8")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/golang/sys/tar.gz/c0bba94af5f8")
       (file-name "esbuild-satori-x-sys-c0bba94-source.tar.gz")
       (sha256
        (base16-string->bytevector
         "948e3a5eb69c316307892d81d7c7c63a481e8909a28b886901c0f7caf02e6a30"))))
    (arguments
     (substitute-keyword-arguments (package-arguments go-golang-org-x-sys)
       ((#:tests? _ #t) #f)))))

(define-public esbuild-for-hermes-satori
  (package
    (inherit esbuild)
    (name "esbuild-for-hermes-satori")
    (version "0.18.10")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/evanw/esbuild/tar.gz/refs/tags/v0.18.10")
       (file-name "esbuild-0.18.10-source.tar.gz")
       (sha256
        (base16-string->bytevector
         "c7180e603efbe6908209926bfa397231abf2a461fb33cf92e1116cdcd96ab9db"))
       (modules '((guix build utils)))
       (snippet
        #~(begin
            (copy-file "npm/@esbuild/linux-x64/package.json" "guix-esbuild-platform.json")
            (delete-file-recursively "npm")))))
    (inputs (list %esbuild-satori-x-sys))
    (arguments
     (substitute-keyword-arguments (package-arguments esbuild)
       ((#:tests? _ #t) #f)
       ((#:phases phases #~%standard-phases)
        #~(modify-phases #$phases
            (add-after 'install 'install-source-platform-provider
              (lambda _
                (let* ((files (find-files "." "^guix-esbuild-platform\\.json$"))
                       (directory (string-append #$output "/lib/node_modules/@esbuild/linux-x64")))
                  (unless (= 1 (length files))
                    (error "Missing exact esbuild platform metadata" files))
                  (mkdir-p (string-append directory "/bin"))
                  (copy-file (car files) (string-append directory "/package.json"))
                  (symlink (string-append #$output "/bin/esbuild")
                           (string-append directory "/bin/esbuild")))))))))
    (synopsis "Source-built esbuild matching Satori's tsup lock")
    (description "This package compiles esbuild 0.18.10 with the exact x/sys
source revision declared by its Go module and installs the Linux x64 platform
provider for Satori's locked JavaScript API.  No downloaded npm platform binary
is used.")
    (license license:expat)))
