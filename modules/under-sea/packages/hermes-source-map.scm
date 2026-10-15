(define-module (under-sea packages hermes-source-map)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (under-sea gexp)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages python)
  #:use-module (under-sea packages hermes-node)
  #:use-module (under-sea packages hermes-browser-wasm)
  #:use-module ((guix licenses) #:prefix license:))

(define (url-library name version hash)
  (list name
        (origin
          (method url-fetch)
          (uri (string-append "https://registry.npmjs.org/" name "/-/" name "-" version ".tgz"))
          (file-name (string-append name "-" version "-source.tgz"))
          (sha256 (base16-string->bytevector hash)))))

(define %url-libraries
  (list
   (url-library "whatwg-url" "7.1.0" "085adf58d2b9bc40b131cf97e126a1842305f8f38f623aa60ba36963e50119ab")
   (url-library "lodash.sortby" "4.7.0" "329cd6fe5d14a3744352a5ced7eb8bbbd4ecc2de27b2d665e6419e80cb13554a")
   (url-library "tr46" "1.0.1" "d706ec1821ccdcda578daa422e5f8990db6e01245eb12a26fd0954dcfd035dbc")
   (url-library "webidl-conversions" "4.0.2" "c6cd2e13852f5be72442c707a1e77291a9e26989e354119f026ab0091f791089")
   (url-library "punycode" "2.1.1" "e5ccd079bf02390e34cbb51b75f73a8be42795146a2e2e23cbb204dddb04ff3c")))

(define (make-hermes-source-map version commit hash)
  (package
    (name "source-map-for-hermes-browser")
    (version version)
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://codeload.github.com/mozilla/source-map/tar.gz/" commit))
       (file-name (string-append "source-map-" version "-source.tar.gz"))
       (sha256 (base16-string->bytevector hash))))
    (build-system gnu-build-system)
    (native-inputs (list python-minimal esbuild-for-hermes))
    (arguments
     (list
      #:substitutable? #f
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          (add-after 'unpack 'unpack-browser-url-sources
            (lambda _
              (for-each
               (lambda (entry)
                 (let ((directory (string-append "node_modules/" (car entry))))
                   (mkdir-p directory)
                   (invoke "tar" "xf" (cadr entry) "--strip-components=1" "-C" directory)))
               (list #$@(if (string=? version "0.8.0-beta.0")
                            (map (lambda (entry) #~(list #$(car entry) #$(cadr entry))) %url-libraries)
                            '())))))
          (replace 'build
            (lambda _
              (invoke "python3" #$(under-sea-script "build-hermes-source-map.py")
                      #$output
                      #$(file-append source-map-wasm-for-hermes-browser "/share/source-map/mappings.wasm")
                      #$version)))
          (replace 'install (lambda _ #t)))))
    (home-page "https://github.com/mozilla/source-map")
    (synopsis "Authored source-map API with source-built mappings WASM")
    (description "This package provides the full source-map JavaScript API,
UMD browser bundle and types with mappings WASM compiled from its matching Rust
sources.  Releases 0.7.4 and 0.8.0-beta.0 originally ship identical mappings WASM;
their JavaScript sources remain separately pinned.  Published prebuilt WASM is
not installed.")
    (license (list license:bsd-3 license:expat license:asl2.0))))

(define-public source-map-074-for-hermes-browser
  (make-hermes-source-map
   "0.7.4" "a999ec31686810d8a6aa2e8ff76c5df9bc3bfdcd"
   "c1ca90d24e0a4373b9f46545c9fd05224b34095c7168eaae0cfd78b446a07461"))

(define-public source-map-073-for-hermes-ncc
  (make-hermes-source-map
   "0.7.3" "b2171d58e90e64472b0e858013c0cc5f6772a83d"
   "6d4af7a94ed05057000c4ab36588bdbc0d5762e0160949be0417f3475331b934"))

(define-public source-map-08-for-hermes-browser
  (make-hermes-source-map
   "0.8.0-beta.0" "11cecea2b64ead3f93cde37a5789dc7683685a7c"
   "5a659d8c20b7f1d6286cb9580c125bb3ed4e7a3fb856ec646e5ce58cf7d64a45"))
