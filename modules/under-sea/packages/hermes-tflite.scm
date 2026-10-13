;;; TensorFlow Lite CPU runtime compiled from fixed source archives.
(define-module (under-sea packages hermes-tflite)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system cmake)
  #:use-module (guix build-system pyproject)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-xyz)
  #:use-module (under-sea packages hermes)
  #:use-module (under-sea packages hermes-audio-native)
  #:use-module (under-sea packages hermes-tflite-lock))

(define-public python-tflite-runtime-for-hermes
  (package
    (name "python-tflite-runtime-for-hermes")
    (version "2.14.0")
    (source %hermes-tflite-source)
    (build-system cmake-build-system)
    (native-inputs (list python-for-hermes-wrapper pybind11
                         python-setuptools python-wheel))
    (propagated-inputs (list python-numpy))
    (arguments
     (list
      #:tests? #f
      #:build-type "Release"
      #:modules '((guix build cmake-build-system) (guix build utils)
                  (ice-9 match) (ice-9 textual-ports)
                  ((guix build pyproject-build-system) #:prefix py:))
      #:imported-modules (append %cmake-build-system-modules
                                 %pyproject-build-system-modules)
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'prepare-offline-sources
            (lambda _
              (call-with-output-file "tflite-sources.tsv"
                (lambda (port)
                  (for-each (match-lambda
                              ((name source) (format port "~a\t~a~%" name source)))
                            '#$%hermes-tflite-sources)))
              (setenv "GUIX_TFLITE_SOURCES" (string-append (getcwd) "/guix-deps"))
              (invoke "python" #$(local-file "../../../scripts/prepare-hermes-tflite.py")
                      "tflite-sources.tsv" (getenv "GUIX_TFLITE_SOURCES"))
              (invoke "python" "-c"
                      "import sysconfig,pybind11,numpy,pathlib; pathlib.Path('guix-includes.txt').write_text(' '.join('-I'+p for p in [sysconfig.get_path('include'),pybind11.get_include(),numpy.get_include()]))")
              (setenv "GUIX_TFLITE_INCLUDES"
                      (call-with-input-file "guix-includes.txt" get-string-all))
              (setenv "GUIX_TFLITE_ROOT" (getcwd))
              (chdir "tensorflow/lite")))
          (replace 'configure
            (lambda _
              (let ((root (getenv "GUIX_TFLITE_ROOT")))
                (mkdir-p (string-append root "/guix-build"))
                (chdir (string-append root "/guix-build"))
                (invoke "cmake" "-S" (string-append root "/tensorflow/lite")
                        "-B" "." "-DCMAKE_BUILD_TYPE=Release"
                        "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
                        "-DTFLITE_ENABLE_XNNPACK=ON"
                        "-C" (string-append (getenv "GUIX_TFLITE_SOURCES")
                                             "/offline-cache.cmake")
                        (string-append "-DCMAKE_CXX_FLAGS="
                                       (getenv "GUIX_TFLITE_INCLUDES"))))))
          (replace 'build
            (lambda* (#:key parallel-build? #:allow-other-keys)
              (invoke "cmake" "--build" "." "--target"
                      "_pywrap_tensorflow_interpreter_wrapper" "--parallel"
                      (if parallel-build? (number->string (parallel-job-count)) "1"))))
          (replace 'install
            (lambda* (#:key inputs #:allow-other-keys)
              (let* ((root (getenv "GUIX_TFLITE_ROOT"))
                     (lite (string-append root "/tensorflow/lite"))
                     (extension (string-append (getcwd)
                                 "/_pywrap_tensorflow_interpreter_wrapper.so")))
                (mkdir-p "wheel-source/tflite_runtime")
                (copy-file (string-append lite "/tools/pip_package/setup_with_binary.py")
                           "wheel-source/setup.py")
                (for-each
                 (lambda (file)
                   (copy-file (string-append lite "/python/" file)
                              (string-append "wheel-source/tflite_runtime/" (basename file))))
                 '("interpreter.py" "metrics/metrics_interface.py" "metrics/metrics_portable.py"))
                (copy-file extension "wheel-source/tflite_runtime/_pywrap_tensorflow_interpreter_wrapper.so")
                (copy-file (string-append root "/LICENSE") "wheel-source/LICENSE")
                (install-file (string-append root "/LICENSE")
                              (string-append #$output "/share/doc/"
                                             #$(package-name this-package)))
                (call-with-output-file "wheel-source/tflite_runtime/__init__.py"
                  (lambda (port)
                    (display "__version__ = '2.14.0'\n__git_version__ = 'v2.14.0'\n" port)))
                (setenv "PROJECT_NAME" "tflite_runtime")
                (setenv "PACKAGE_VERSION" "2.14.0")
                (chdir "wheel-source")
                (invoke "python" "setup.py" "bdist_wheel")
                ((assoc-ref py:%standard-phases 'install)
                 #:inputs inputs #:outputs `(("out" . ,#$output)))))))))
    (supported-systems '("x86_64-linux"))
    (properties '((max-silent-time . 7200)))
    (home-page "https://www.tensorflow.org/lite")
    (synopsis "Source-built TensorFlow Lite Python runtime for Hermes")
    (description "This package compiles TensorFlow Lite's Python interpreter
extension and CPU engine with XNNPACK from fixed local source inputs.  Models
and integration into the Hermes private Python runtime are separate.")
    (license license:asl2.0)))
