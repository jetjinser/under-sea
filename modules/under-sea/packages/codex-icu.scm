;;; Build V8's ICU data archive from the ICU resource sources.
(define-module (under-sea packages codex-icu)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (under-sea gexp)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages python))

(define-public codex-icu-data
  (package
    (name "codex-icu-data")
    (version "78.1")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/unicode-org/icu/tar.gz/refs/tags/release-78.1")
       (file-name "icu-78.1-source.tar.gz")
       (sha256 (base16-string->bytevector
                "813f6c02009f608be69dad8184ff4feab561b1ac45fed45b57e4345ad4298a71"))))
    (build-system gnu-build-system)
    (native-inputs (list python-minimal))
    (arguments
     (list
      #:substitutable? #f
      #:tests? #f
      #:configure-flags #~(list "--disable-tests" "--disable-samples"
                                "--with-data-packaging=archive")
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'configure-data-sources
            (lambda _
              (chdir "icu4c/source")
              (copy-file "../../LICENSE" "LICENSE")
              ;; Force resource generation rather than accepting a packaged
              ;; release icudt archive. Unicode's individual property tables
              ;; remain upstream data inputs, not executable libraries.
              (for-each delete-file (find-files "data/in" "icudt.*\\.dat$"))
              (setenv "ICU_DATA_FILTER_FILE"
                      #$(under-sea-repo-file "modules/under-sea/resources/v8-icu-common.json"))))
          (replace 'install
            (lambda _
              (let ((files (find-files "data/out" "^icudt78l\\.dat$"))
                    (share (string-append #$output "/share/codex-icu")))
                (unless (= (length files) 1)
                  (error "Expected one source-generated ICU data archive" files))
                (mkdir-p share)
                (copy-file (car files) (string-append share "/icudtl.dat"))))))))
    (home-page "https://icu.unicode.org/")
    (synopsis "ICU data generated for the Codex V8 host")
    (description "This package compiles ICU resource sources with the common
Chromium ICU filter bundled by the locked rusty_v8 source.  The data generator
is built locally; no prepackaged V8 ICU data archive is used.")
    (license license:unicode)))
