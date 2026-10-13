;;; Strata - a local inference engine for Qwen3.8-Flash-Next on consumer GPUs.
;;;
;;; Upstream ships Windows-only binaries; on Linux the engine is compiled from
;;; source.  The NVIDIA path needs the CUDA toolkit (not available in Guix or
;;; nonguix), so this package builds the AMD/HIP backend using Guix's ROCm 7
;;; stack (clang-rocm, rocm-device-libs, rocm-hip-runtime, hipBLAS, rocBLAS).
;;; The bundled ggml is taken from a pinned llama.cpp checkout instead of being
;;; fetched by CMake, so the build is fully offline.  The resulting engine needs
;;; an AMD Radeon GPU (RDNA2/3/4); the model weights (tens of GB) are downloaded
;;; at run time and are not part of this package.
(define-module (under-sea packages strata)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages ninja)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python))

(define %strata-version "0.1.43.1")
(define %llama-cpp-commit "3cf03257f219afbe7334045ff7c6a06ac68c627d")
(define %hip-architectures "gfx1100;gfx1201")   ; upstream-validated RDNA3 + RDNA4

;;; Build-only part of the HIP toolchain.
(define %hip-build-inputs
  (map specification->package
       '("clang-rocm" "rocm-device-libs" "lld")))
;;; Runtime HIP/ROCm libraries (referenced by the binaries' rpath).
(define %hip-runtime-inputs
  (map specification->package
       '("rocm-hip-runtime" "rocr-runtime" "hipblas" "hipblas-common"
         "rocblas" "hipblaslt" "gcc-toolchain@14")))

;;; The pinned llama.cpp checkout that provides ggml.  Strata's CMake would
;;; otherwise FetchContent it from the network at configure time.
(define-public llama-cpp-for-strata
  (package
    (name "llama-cpp-for-strata")
    (version "20260920")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://codeload.github.com/ggml-org/llama.cpp/tar.gz/"
                           %llama-cpp-commit))
       (file-name (string-append "llama.cpp-"
                                 (substring %llama-cpp-commit 0 8) ".tar.gz"))
       (sha256
        (base16-string->bytevector
         "c076d7534afa0e5d0ec2a0d425b11e791c16f3de0d727221aea071cef156a280"))))
    (build-system gnu-build-system)
    (arguments
     (list #:phases
           #~(modify-phases %standard-phases
               (delete 'configure)
               (delete 'build)
               (delete 'check)
               (replace 'install
                 (lambda _
                   ;; %standard-phases' unpack enters the single top directory.
                   (copy-recursively (getcwd) #$output))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/ggml-org/llama.cpp")
    (synopsis "Pinned llama.cpp snapshot providing ggml for Strata")
    (description "This package provides the ggml sources from a pinned
llama.cpp checkout, as required by the Strata inference engine.")
    (license license:expat)))

(define-public strata
  (package
    (name "strata")
    (version %strata-version)
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://codeload.github.com/Niko1221/Strata/tar.gz/refs/tags/v"
             %strata-version))
       (file-name (string-append "strata-" %strata-version ".tar.gz"))
       (sha256
        (base16-string->bytevector
         "833d4ade8b1c4079d12d219797c3ccad6a7454bcffb69a9149d3664469ff9bf9"))))
    (build-system gnu-build-system)
    (native-inputs
     (append (list cmake-minimal ninja patchelf llvm linux-libre-headers
                   binutils pkg-config llama-cpp-for-strata)
             %hip-build-inputs))
    (inputs (append (list bash-minimal) %hip-runtime-inputs))
    (arguments
     (list
      #:validate-runpath? #f
      #:modules '((guix build gnu-build-system) (guix build utils)
                  (ice-9 string-fun))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'check)
          (replace 'build
            (lambda* (#:key inputs #:allow-other-keys)
              (define (in name) (assoc-ref inputs name))
              (let ((clang (in "clang-rocm"))
                    (devlib (in "rocm-device-libs"))
                    (hiprt (in "rocm-hip-runtime"))
                    (rocr (in "rocr-runtime"))
                    (hipblas (in "hipblas"))
                    (hbc (in "hipblas-common"))
                    (rocblas (in "rocblas"))
                    (hipblaslt (in "hipblaslt"))
                    (gcc14 (in "gcc-toolchain"))
                    (ggml (in "llama-cpp-for-strata"))
                    (linux (in "linux-libre-headers"))
                    (shims (string-append (getcwd) "/shims")))
                ;; The HIP device-link step invokes bare "lld"; the generic
                ;; driver refuses, so provide "lld" -> ld.lld plus ld/objcopy.
                (mkdir-p shims)
                (symlink (string-append (in "lld") "/bin/ld.lld")
                         (string-append shims "/lld"))
                (symlink (string-append (in "binutils") "/bin/ld")
                         (string-append shims "/ld"))
                (symlink (string-append (in "llvm") "/bin/llvm-objcopy")
                         (string-append shims "/llvm-objcopy"))
                (setenv "PATH"
                        (string-append shims ":" clang "/bin:"
                                       #$(file-append cmake-minimal "/bin") ":"
                                       (getenv "PATH")))
                (invoke
                 "cmake" "-S" "." "-B" "build" "-G" "Ninja"
                 "-DCMAKE_BUILD_TYPE=Release"
                 "-DCMAKE_C_COMPILER=gcc" "-DCMAKE_CXX_COMPILER=g++"
                 "-DSTRATA_ENABLE_HIP=ON" "-DSTRATA_BUILD_TESTS=OFF"
                 "-DHIP_PLATFORM=amd"
                 (string-append "-DCMAKE_HIP_ARCHITECTURES=" #$%hip-architectures)
                 (string-append "-DCMAKE_HIP_COMPILER=" clang "/bin/clang++")
                 (string-append "-DCMAKE_HIP_COMPILER_ROCM_ROOT=" hiprt)
                 (string-append
                  "-DCMAKE_HIP_FLAGS="
                  "--rocm-path=" devlib
                  " -include __clang_hip_runtime_wrapper.h"
                  " -isystem " linux "/include"
                  ;; clang-rocm 20 cannot parse GCC 16's libstdc++: use 14's.
                  " -nostdinc++"
                  " -isystem " gcc14 "/include/c++"
                  " -isystem " gcc14 "/include/c++/x86_64-unknown-linux-gnu")
                 (string-append
                  "-DCMAKE_PREFIX_PATH="
                  (string-join (list hiprt hipblas rocblas hipblaslt
                                     devlib rocr hbc) ";"))
                 (string-append "-DSTRATA_GGML_DIR=" ggml))
                (invoke "cmake" "--build" "build" "-j"
                        (number->string (parallel-job-count))))))
          (replace 'install
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (define (in name) (assoc-ref inputs name))
              (let* ((bin (string-append #$output "/bin"))
                     (rpath (string-join
                             (map (lambda (n) (string-append (in n) "/lib"))
                                  '("rocm-hip-runtime" "rocr-runtime" "hipblas"
                                    "hipblas-common" "rocblas" "hipblaslt"
                                    "gcc-toolchain"))
                             ":")))
                (mkdir-p bin)
                (for-each
                 (lambda (name)
                   (let ((exe (string-append "build/" name))
                         (dst (string-append bin "/" name)))
                     (when (file-exists? exe)
                       (copy-file exe dst)
                       (chmod dst #o755)
                       (invoke "patchelf" "--set-rpath" rpath dst)
                       (chmod dst #o555))))
                 '("strata" "strata-device" "strata-gguf" "strata-dequant"
                   "strata-plan" "strata-load" "strata-concurrent"
                   "strata-overlap"))))))))
    (supported-systems '("x86_64-linux"))
    (properties '((max-silent-time . 7200)))
    (home-page "https://github.com/Niko1221/Strata")
    (synopsis "Local Qwen3.8-Flash-Next inference engine (AMD/HIP backend)")
    (description "Strata runs a large Qwen3.8-Flash-Next model on a consumer
PC.  This package builds the engine from source for the AMD HIP backend using
Guix's ROCm stack; it targets AMD Radeon GPUs (RDNA2/3/4).  The NVIDIA backend
needs the CUDA toolkit and is not built.  Model weights are downloaded at run
time and are not included.")
    (license license:expat)))
