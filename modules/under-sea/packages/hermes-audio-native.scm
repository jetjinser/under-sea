;;; Source-built native engines for Hermes local audio.
(define-module (under-sea packages hermes-audio-native)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system cmake)
  #:use-module (guix build-system pyproject)
  #:use-module (gnu packages maths)
  #:use-module (gnu packages oneapi)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages serialization)
  #:use-module (under-sea packages hermes))

(define (github-source repository commit name hash)
  (origin
    (method url-fetch)
    (uri (string-append "https://codeload.github.com/" repository "/tar.gz/" commit))
    (file-name name)
    (sha256 (base16-string->bytevector hash))))

(define-public %ctranslate2-source
  (github-source "OpenNMT/CTranslate2" "refs/tags/v4.7.1"
                 "ctranslate2-4.7.1-source.tar.gz"
                 "64beb499c1e33500a691dfbe10cc5def7b914413c7f7c2830b0e0d8d544a9f7e"))

(define-public %hermes-flatbuffers-source
  (github-source "google/flatbuffers" "refs/tags/v25.12.19"
                 "flatbuffers-25.12.19-source.tar.gz"
                 "f81c3162b1046fe8b84b9a0dbdd383e24fdbcf88583b9cb6028f90d04d90696a"))

(define-public %hermes-onnxruntime-source
  (github-source "microsoft/onnxruntime" "refs/tags/v1.27.0"
                 "onnxruntime-1.27.0-source.tar.gz"
                 "b41d09905a3c2f3a25709d1dcce8ef3942a4c2799d1046f74be7b6bbebc45e6a"))

(define-public %hermes-tflite-source
  (github-source "tensorflow/tensorflow" "refs/tags/v2.14.0"
                 "tensorflow-2.14.0-source.tar.gz"
                 "ce357fd0728f0d1b0831d1653f475591662ec5bca736a94ff789e6b1944df19f"))

(define-public python-pilk-for-hermes
  (package
    (name "python-pilk-for-hermes")
    (version "0.2.4")
    (source
     (origin
       (method url-fetch)
       (uri "https://files.pythonhosted.org/packages/66/bb/938dd697b6bc2d851ffec4ffe82ed20078e58bd0ef049e84f4d038d6f991/pilk-0.2.4.tar.gz")
       (sha256 (base16-string->bytevector
                "d4a1bcf93dc6ef5e95e0cfd728ed4ef4d49f9c0476d70816fecbe456cc762e7f"))))
    (build-system pyproject-build-system)
    (arguments
     (list #:python python-for-hermes-wrapper #:tests? #f
           #:phases
           #~(modify-phases %standard-phases
               (add-after 'unpack 'preserve-codec-license
                 (lambda _
                   (copy-file "src/SKP_SILK_SRC/SKP_Silk_dec_API.c"
                              "LICENSE-SILK-source.c"))))))
    (native-inputs (list python-setuptools python-wheel))
    (propagated-inputs (list python-typing-extensions))
    (home-page "https://github.com/foyoux/pilk")
    (synopsis "Source-built SILK audio codec binding for Hermes")
    (description "Pilk provides Python bindings for SILK voice encoding and
decoding.  This package compiles the included codec sources rather than using
a prebuilt native extension.")
    (license (list license:gpl3 license:bsd-3))))

(define-public flatbuffers-for-hermes
  (package
    (inherit flatbuffers)
    (name "flatbuffers-for-hermes")
    (version "25.12.19")
    (source %hermes-flatbuffers-source)
    (arguments
     (substitute-keyword-arguments (package-arguments flatbuffers)
       ((#:tests? tests? #t) #f)))))

(define-public python-flatbuffers-for-hermes
  (package
    (inherit python-flatbuffers)
    (name "python-flatbuffers-for-hermes")
    (version "25.12.19")
    (source %hermes-flatbuffers-source)
    (arguments
     (list
      #:python python-for-hermes-wrapper
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'enter-python-sources
            (lambda _
              (chdir "python")
              (copy-file "../LICENSE" "LICENSE"))))))))

(define-public ctranslate2-for-hermes
  (package
    (name "ctranslate2-for-hermes")
    (version "4.7.1")
    (source %ctranslate2-source)
    (build-system cmake-build-system)
    (inputs (list openblas onednn))
    (arguments
     (list
      #:tests? #f
      #:configure-flags
      #~(list "-DWITH_MKL=OFF" "-DWITH_OPENBLAS=ON" "-DWITH_DNNL=ON"
              "-DOPENMP_RUNTIME=COMP"
              "-DBUILD_CLI=ON" "-DBUILD_TESTS=OFF")
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'unpack-locked-submodules
            (lambda _
              (for-each
               (lambda (entry)
                 (let ((directory (string-append "third_party/" (car entry))))
                   (mkdir-p directory)
                   (invoke "tar" "xf" (cadr entry) "--strip-components=1"
                           "-C" directory)))
               (list
                (list "cpu_features"
                      #$(github-source "google/cpu_features"
                                       "8a494eb1e158ec2050e5f699a504fbc9b896a43b"
                                       "ct2-cpu-features-source.tar.gz"
                                       "9b2019dae7608630ab985129a5c3263fc788e4f82e26965a8d8c33b8c035802e"))
                (list "spdlog"
                      #$(github-source "gabime/spdlog"
                                       "76fb40d95455f249bd70824ecfcae7a8f0930fa3"
                                       "ct2-spdlog-source.tar.gz"
                                       "4530d53b86d45228a5b8982a8f4fe7d95d3ba8e1944858d3f663732c7e949cb7"))
                (list "cxxopts"
                      #$(github-source "jarro2783/cxxopts"
                                       "c74846a891b3cc3bfa992d588b1295f528d43039"
                                       "ct2-cxxopts-source.tar.gz"
                                       "29b618401f6e29ee5a21208c5cf4d8b17e55814cc220e0ada9a798239f1944e3")))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://opennmt.net/CTranslate2/")
    (synopsis "CTranslate2 CPU engine for Hermes local speech recognition")
    (description "This package builds CTranslate2 with CPU dispatch, OpenBLAS,
oneDNN and its command-line clients.  Its exact upstream submodules are source
inputs.  Python binding integration and GPU backends are maintained separately.")
    (license license:expat)))

(define-public python-ctranslate2-for-hermes
  (package
    (name "python-ctranslate2-for-hermes")
    (version "4.7.1")
    (source %ctranslate2-source)
    (build-system pyproject-build-system)
    (native-inputs (list python-setuptools python-wheel pybind11))
    (inputs (list ctranslate2-for-hermes))
    (propagated-inputs (list python-numpy python-pyyaml))
    (arguments
     (list
      #:python python-for-hermes-wrapper
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'configure-native-library
            (lambda _
              (chdir "python")
              (copy-file "../LICENSE" "LICENSE")
              (setenv "CTRANSLATE2_ROOT" #$ctranslate2-for-hermes)
              (setenv "CMAKE_BUILD_PARALLEL_LEVEL"
                      (number->string (min 2 (parallel-job-count))))
              (substitute* "setup.py"
                (("-Wl,-rpath,/usr/local/lib64:/usr/local/lib")
                 (string-append "-Wl,-rpath," #$ctranslate2-for-hermes "/lib"))))))))
    (home-page "https://opennmt.net/CTranslate2/")
    (synopsis "Source-built CTranslate2 Python binding for Hermes")
    (description "This package compiles CTranslate2's Python extension against
the source-built native engine and the Hermes Python ABI.  It does not install
model files or download a native wheel.")
    (license license:expat)))
