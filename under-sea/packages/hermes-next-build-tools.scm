(define-module (under-sea packages hermes-next-build-tools)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module (under-sea packages hermes-satori-tools))

(define-public esbuild-for-hermes-next
  (package
    (inherit esbuild-for-hermes-satori)
    (name "esbuild-for-hermes-next")
    (version "0.25.9")
    (source
     (origin
       (inherit (package-source esbuild-for-hermes-satori))
       (uri "https://codeload.github.com/evanw/esbuild/tar.gz/refs/tags/v0.25.9")
       (file-name "next-esbuild-0.25.9-source.tar.gz")
       (sha256
        (base16-string->bytevector
         "ae3401455b241827800299aba368683db0042044eb7ed8e43ca0180c85531da4"))))
    (synopsis "Source-built esbuild matching Next's authored build lock")
    (description "This package builds esbuild 0.25.9 and its Linux x64
platform provider from source. It retains the exact x/sys revision in the
upstream Go module, shared with the Satori build tool variant.")))

;; Next's authored lock selects this Git source rather than registry ci-info.
(define-public ci-info-for-hermes-next
  (package
    (name "ci-info-for-hermes-next")
    (version "2.0.0-f43f6a1")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/watson/ci-info/tar.gz/f43f6a1cefff47fb361c88cf4b943fdbcaafe540")
       (file-name "next-ci-info-f43f6a1-source.tar.gz")
       (sha256
        (base16-string->bytevector
         "1bcf8c749d417662f240f1486813becb961ce435ef4e63b657fb09297e5a8ee8"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'build)
          (replace 'install
            (lambda _
              (let ((module (string-append #$output "/lib/node_modules/ci-info")))
                (mkdir-p module)
                ;; Authored JavaScript and vendor data need no transpilation.
                (for-each
                 (lambda (file) (copy-file file (string-append module "/" file)))
                 '("index.js" "vendors.json" "package.json" "LICENSE" "README.md"))
                (call-with-output-file (string-append module "/guix-source-identity.json")
                  (lambda (port)
                    (display "{\"url\":\"https://codeload.github.com/watson/ci-info/tar.gz/f43f6a1cefff47fb361c88cf4b943fdbcaafe540\",\"version\":\"2.0.0\"}\n" port)))))))))
    (home-page "https://github.com/watson/ci-info")
    (synopsis "CI environment metadata at Next's pinned source revision")
    (description "This package installs the authored ci-info JavaScript and
vendor data from the exact Git revision selected by the Next source build.
It does not execute environment detection during the build.")
    (license license:expat)))
