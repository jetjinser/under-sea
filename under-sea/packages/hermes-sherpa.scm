;;; Sherpa ONNX CPU engine; Python binding integration is separate.
(define-module (under-sea packages hermes-sherpa)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system cmake)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages python-build)
  #:use-module (under-sea packages hermes)
  #:use-module (under-sea packages hermes-onnx)
  #:use-module (under-sea packages hermes-sherpa-lock))

(define-public sherpa-onnx-for-hermes
  (package
    (name "sherpa-onnx-for-hermes")
    (version "1.13.4")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/k2-fsa/sherpa-onnx/tar.gz/refs/tags/v1.13.4")
       (file-name "sherpa-onnx-1.13.4-full-source.tar.gz")
       (sha256 (base16-string->bytevector
                "3243cb386d3a4ac87596adf7d2c89fddf23e2948b154942b987b4d91c1fee295"))))
    (build-system cmake-build-system)
    (native-inputs (list python-for-hermes-wrapper pkg-config))
    (inputs (list onnxruntime-for-hermes alsa-lib))
    (arguments
     (list #:tests? #f #:build-type "Release"
           #:modules '((guix build cmake-build-system) (guix build utils) (ice-9 match))
           #:configure-flags
           #~(list "-DBUILD_SHARED_LIBS=ON" "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
                   "-DSHERPA_ONNX_ENABLE_BINARY=ON" "-DSHERPA_ONNX_ENABLE_C_API=ON"
                   "-DSHERPA_ONNX_ENABLE_TTS=ON"
                   "-DSHERPA_ONNX_ENABLE_SPEAKER_DIARIZATION=ON"
                   "-DSHERPA_ONNX_ENABLE_PORTAUDIO=ON" "-DPA_USE_ALSA=ON"
                   "-DSHERPA_ONNX_ENABLE_WEBSOCKET=ON"
                   "-DSHERPA_ONNX_ENABLE_TESTS=OFF"
                   "-C" "../sherpa-offline-cache.cmake")
           #:phases
           #~(modify-phases %standard-phases
               (add-after 'unpack 'prepare-offline-sources
                 (lambda _
                   (setenv "GUIX_SHERPA_SOURCE_ROOT" (getcwd))
                   (call-with-output-file "sources.tsv"
                     (lambda (port)
                       (for-each (match-lambda
                                   ((name source) (format port "~a\t~a~%" name source)))
                                 '#$%hermes-sherpa-sources)))
                   (invoke "python" #$(local-file "../../scripts/prepare-hermes-sherpa.py")
                           (getcwd) "sources.tsv" "guix-deps")
                   (copy-file "guix-deps/offline-cache.cmake"
                              "../sherpa-offline-cache.cmake")
                   (setenv "SHERPA_ONNXRUNTIME_INCLUDE_DIR"
                           #$(file-append onnxruntime-for-hermes "/include/onnxruntime"))
                   (setenv "SHERPA_ONNXRUNTIME_LIB_DIR"
                           #$(file-append onnxruntime-for-hermes "/lib")))))))
    (supported-systems '("x86_64-linux"))
    (properties '((max-silent-time . 7200)))
    (home-page "https://github.com/k2-fsa/sherpa-onnx")
    (synopsis "Source-built Sherpa ONNX CPU audio engine for Hermes")
    (description "Sherpa ONNX supports speech recognition, keyword spotting,
voice activity detection, speech synthesis and speaker diarization.  This CPU
engine uses fixed source dependencies and a source-built ONNX Runtime.  Python
bindings, models and Hermes private-runtime integration are separate.")
    (license license:asl2.0)))

(define-public python-sherpa-onnx-for-hermes
  (package
    (inherit sherpa-onnx-for-hermes)
    (name "python-sherpa-onnx-for-hermes")
    (native-inputs
     (modify-inputs (package-native-inputs sherpa-onnx-for-hermes)
       (append python-setuptools python-wheel python-installer)))
    (arguments
     (substitute-keyword-arguments (package-arguments sherpa-onnx-for-hermes)
       ((#:configure-flags flags)
        #~(append #$flags
                  (list "-DSHERPA_ONNX_ENABLE_PYTHON=ON"
                        (string-append "-DPYTHON_EXECUTABLE="
                                       #$(file-append python-for-hermes-wrapper "/bin/python")))))
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-after 'install 'install-python-binding
              (lambda _
                (let ((extensions (find-files (string-append #$output "/lib")
                                               "^_sherpa_onnx.*\\.so$")))
                  (unless (= (length extensions) 1)
                    (error "Expected one source-built Sherpa Python extension" extensions))
                  (invoke "python"
                          #$(local-file "../../scripts/package-hermes-sherpa-python.py")
                          (getenv "GUIX_SHERPA_SOURCE_ROOT")
                          (car extensions) #$output))))))))
    (synopsis "Source-built Sherpa ONNX engine and Python bindings for Hermes")
    (description "This package compiles Sherpa ONNX's CPU engine and Python
bindings with the same fixed source dependencies and Hermes Python ABI.  It
preserves upstream Python package metadata and CLI entry points.  Model assets
and integration into Hermes's private Python environment are separate.")))
