;;; ONNX Runtime built with reviewed, offline source archives.
(define-module (under-sea packages hermes-onnx)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (under-sea gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system cmake)
  #:use-module (guix build-system pyproject)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages protobuf)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-xyz)
  #:use-module (under-sea packages hermes)
  #:use-module (under-sea packages hermes-audio-native)
  #:use-module (under-sea packages hermes-onnx-lock))

(define-public onnxruntime-for-hermes
  (package
    (name "onnxruntime-for-hermes")
    (version "1.27.0")
    (source %hermes-onnxruntime-source)
    (build-system cmake-build-system)
    (outputs '("out" "python"))
    (native-inputs (list python-for-hermes-wrapper python-numpy
                         python-setuptools python-wheel protobuf unzip))
    (inputs (list zlib))
    (propagated-inputs (list python-coloredlogs python-protobuf python-sympy
                             python-flatbuffers-for-hermes))
    (arguments
     (list
      #:tests? #f
      #:build-type "Release"
      #:modules '((guix build cmake-build-system) (guix build utils)
                  (ice-9 match)
                  ((guix build pyproject-build-system) #:prefix py:))
      #:imported-modules (append %cmake-build-system-modules
                                 %pyproject-build-system-modules)
      #:configure-flags
      #~(list "-Donnxruntime_BUILD_UNIT_TESTS=OFF"
              "-Donnxruntime_BUILD_SHARED_LIB=ON" "-Donnxruntime_ENABLE_PYTHON=ON"
              "-Donnxruntime_ENABLE_LTO=OFF"
              ;; Python's ONNX binding and Sherpa's ORT runtime are separate
              ;; native link units in one process. Full protobuf registers the
              ;; same ONNX descriptors in both units; lite protobuf removes
              ;; that cross-unit global descriptor collision.
              "-Donnxruntime_USE_FULL_PROTOBUF=OFF"
              "-Dprotobuf_BUILD_SHARED_LIBS=OFF" "-Dprotobuf_BUILD_TESTS=OFF"
              "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
              ;; onnxruntime's kernels leave PT_GNU_STACK marked RWE; force a
              ;; non-executable stack so the produced shared objects load on
              ;; kernels that refuse executable stacks.
              "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,-z,noexecstack"
              "-DCMAKE_EXE_LINKER_FLAGS=-Wl,-z,noexecstack"
              (string-append "-DONNX_CUSTOM_PROTOC_EXECUTABLE="
                             #$(file-append protobuf "/bin/protoc")))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'configure-offline-dependencies
            (lambda _
              (let ((sources '#$%hermes-onnx-sources))
                (call-with-output-file "cmake/deps.txt"
                  (lambda (port)
                    (for-each
                     (match-lambda
                       ((name sha1 source)
                        (format port "~a;~a;~a~%" name source sha1)))
                     sources))))
              ;; CPU/Python dependencies are complete; any newly introduced
              ;; unreviewed dependency must fail instead of downloading.
              (chdir "cmake")))
          (add-after 'install 'build-python-wheel
            (lambda _ (invoke "python" "../setup.py" "bdist_wheel")))
          (add-after 'build-python-wheel 'install-python-wheel
            (lambda* (#:key inputs #:allow-other-keys)
              ((assoc-ref py:%standard-phases 'install)
               #:inputs inputs
               #:outputs `(("out" . ,#$output:python)))))
          (add-after 'install-python-wheel 'install-source-license
            (lambda _
              (for-each
               (lambda (output)
                 (install-file "../LICENSE"
                               (string-append output "/share/doc/onnxruntime-for-hermes")))
               (list #$output #$output:python))))
          (add-after 'install-source-license 'clear-exec-stack
            (lambda _
              ;; Objects that omit the .note.GNU-stack marker make the linker
              ;; record PT_GNU_STACK as RWE; clear the execute bit so the
              ;; shared object loads on kernels that refuse executable stacks.
              (invoke "python"
                      #$(under-sea-script "clear-exec-stack.py")
                      #$output:python))))))
    (supported-systems '("x86_64-linux"))
    (properties '((max-silent-time . 7200)))
    (home-page "https://github.com/microsoft/onnxruntime")
    (synopsis "Source-built ONNX Runtime for Hermes local audio")
    (description "This package builds ONNX Runtime's CPU engine and Python
extension with full operators from fixed upstream source archives.  It uses a
Guix protoc compiler and does not download a prebuilt compiler or native wheel.
GPU providers, models and Hermes private-runtime integration are separate.")
    (license license:expat)))
