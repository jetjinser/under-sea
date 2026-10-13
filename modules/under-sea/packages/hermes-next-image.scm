;;; Exact image-processing source providers selected by Next's authored lock.
(define-module (under-sea packages hermes-next-image)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (under-sea packages hermes-browser-native))

(define-public vips-for-hermes-next
  (package
    (inherit vips-for-hermes-browser)
    (name "vips-for-hermes-next")
    (version "8.17.2")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/libvips/libvips/tar.gz/refs/tags/v8.17.2")
       (file-name "next-libvips-8.17.2-source.tar.gz")
       (sha256
        (base16-string->bytevector
         "66e2c8f0a716a08cf99e46a27535ef4938f1cae110dd9207cf8e992616b36ba7"))))))

(define-public sharp-binding-for-hermes-next
  (package
    (inherit sharp-binding-for-hermes-browser)
    (name "sharp-binding-for-hermes-next")
    (version "0.34.4")
    (source
     (origin
       (method url-fetch)
       (uri "https://registry.npmjs.org/sharp/-/sharp-0.34.4.tgz")
       (file-name "next-sharp-0.34.4-source.tgz")
       (sha256
        (base16-string->bytevector
         "779ac856972b6c2e78c6c18e6ceaf5037f098a8173ce6bef75810667c749c075"))))
    (inputs
     (modify-inputs (package-inputs sharp-binding-for-hermes-browser)
       (replace "vips-for-hermes-browser" vips-for-hermes-next)))
    (arguments
     (substitute-keyword-arguments
         (package-arguments sharp-binding-for-hermes-browser)
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-after 'install 'matching-platform-metadata
              (lambda _
                (substitute* (string-append #$output
                               "/lib/node_modules/@img/sharp-linux-x64/package.json")
                  (("0\\.34\\.5") "0.34.4"))))))))))
