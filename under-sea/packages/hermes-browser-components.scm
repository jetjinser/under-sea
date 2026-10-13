;;; Source-built components reusing fixed-channel recipes for the Hermes
;;; browser runtimes.
(define-module (under-sea packages hermes-browser-components)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages compression))

;; camoufox accepts any orjson release, and the fixed channel's source-built
;; python-orjson (3.9.7) matches the Rust toolchain available here, unlike the
;; latest release which requires rustc 1.95.
(define-public orjson-for-hermes
  (package
    (inherit python-orjson)
    (name "orjson-for-hermes")))

;; Camoufox installs fpgen's model into its own package directory at runtime,
;; which is read-only in the store.  Bake the pinned release in at build time
;; (files plus the .pinned-model stamp) so no write is attempted.
(define-public fpgen-model-for-hermes
  (package
    (name "fpgen-model-for-hermes")
    (version "model-2-2026")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/scrapfly/fingerprint-generator/releases/download/"
             "model-2/2026/model-release.zip"))
       (sha256
        (base16-string->bytevector
         "6530b8322cdaa4ec042921c8d9a0369a0e6e0269ba636c01a7203e4a2f109936"))))
    (build-system gnu-build-system)
    (native-inputs (list unzip))
    (arguments
     (list
      #:substitutable? #f
      #:validate-runpath? #f
      #:modules '((guix build gnu-build-system) (guix build utils))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'build)
          (delete 'check)
          (replace 'unpack (lambda _ (invoke "unzip" #$source)))
          ;; Camoufox expects the compressed members (fpgen's extract_json and
          ;; indexed-zstd reader consume the .zst files directly) and forbids
          ;; decompressed fingerprint-network.json/values.json.
          (replace 'install
            (lambda _
              (let ((dir (string-append #$output "/share/fpgen-model"))
                    (files '("fingerprint-network.json.zst" "values.dat.zst"
                             "values.json.zst")))
                (mkdir-p dir)
                (for-each (lambda (f) (install-file f dir)) files)
                (call-with-output-file (string-append dir "/.pinned-model")
                  (lambda (port)
                    (display "6530b8322cdaa4ec042921c8d9a0369a0e6e0269ba636c01a7203e4a2f109936\n" port)))
                (for-each
                 (lambda (f)
                   (utime (string-append dir "/" f) 4102444800 4102444800))
                 (append files '(".pinned-model")))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/scrapfly/fingerprint-generator")
    (synopsis "Pinned fpgen fingerprint model for Camoufox")
    (description "This package carries the pinned fpgen model release (three
compressed data files plus the .pinned-model stamp) so Camoufox can use it from
the read-only store without downloading at runtime.")
    (license license:expat)))
