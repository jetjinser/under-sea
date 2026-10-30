;;; Strata - a local inference engine for Qwen3.8-Flash-Next on consumer GPUs.
;;;
;;; Upstream ships Windows-only binaries; on Linux the engine is compiled from
;;; source.  `strata' builds the AMD/HIP backend using Guix's ROCm 7 stack
;;; (clang-rocm, rocm-device-libs, rocm-hip-runtime, hipBLAS, rocBLAS), and
;;; `strata-cuda' builds the NVIDIA backend against the CUDA 13.0 toolkit from
;;; the non-free guix-hpc-non-free channel (via guix-science-nonfree).  The
;;; bundled ggml is taken from a pinned llama.cpp checkout instead of being
;;; fetched by CMake, so both builds are fully offline.  The engines need an
;;; AMD Radeon GPU (RDNA2/3/4) or an NVIDIA GPU of compute capability 7.5+
;;; respectively; the model weights (tens of GB) are downloaded at run time and
;;; are not part of these packages.  libcuda.so.1 (the driver library) always
;;; comes from the host's driver, never from the store.
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
  #:use-module (gnu packages python)
  #:use-module ((guix-science-nonfree packages cuda) #:select (cuda-13))
  #:use-module (under-sea packages strata-pin)
  #:use-module (under-sea packages strata-lock))

;;; Build-only part of the HIP toolchain.
(define %hip-build-inputs
  (map specification->package
       '("clang-rocm" "rocm-device-libs" "lld")))
;;; Runtime HIP/ROCm libraries (referenced by the binaries' rpath).
(define %hip-runtime-inputs
  (map specification->package
       '("rocm-hip-runtime" "rocr-runtime" "hipblas" "hipblas-common"
         "rocblas" "hipblaslt" "gcc-toolchain@14")))

;;; Host toolchain for the CUDA build: nvcc 13 supports host GCC up to 14, and
;;; one compiler for .cpp and .cu keeps the binary on a single libstdc++.
(define %cuda-host-toolchain (specification->package "gcc-toolchain@14"))

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
                           %strata-llama-cpp-commit))
       (file-name (string-append "llama.cpp-"
                                 (substring %strata-llama-cpp-commit 0 8) ".tar.gz"))
       (sha256
        (base16-string->bytevector
         %strata-llama-cpp-sha256))))
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
    (source %strata-source)
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
                 (string-append "-DCMAKE_HIP_ARCHITECTURES=" #$%strata-hip-architectures)
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
                   "strata-overlap"))
                (invoke (string-append bin "/strata") "--help")
                (invoke (string-append bin "/strata-device") "--help")
                (invoke (string-append bin "/strata-device")
                        "--list-devices")))))))
    (supported-systems '("x86_64-linux"))
    (properties '((upstream-github "Niko1221/Strata")
                  (max-silent-time . 7200)))
    (home-page "https://github.com/Niko1221/Strata")
    (synopsis "Local Qwen3.8-Flash-Next inference engine (AMD/HIP backend)")
    (description "Strata runs a large Qwen3.8-Flash-Next model on a consumer
PC.  This package builds the engine from source for the AMD HIP backend using
Guix's ROCm stack; it targets AMD Radeon GPUs (RDNA2/3/4).  For NVIDIA GPUs
use the strata-cuda package.  Model weights are downloaded at run time and
are not included.")
    (license license:expat)))

(define-public strata-cuda
  ;; Deliberately not an arguments-inheriting variant of `strata': the HIP
  ;; build phases reference the whole ROCm stack, and splicing them here would
  ;; drag those gexp references into this package's closure.
  (package
    (inherit strata)
    (name "strata-cuda")
    ;; The CUDA toolkit (a non-free NVIDIA .run installer) cannot be
    ;; substituted, so neither can this package.
    (arguments
     (list
      #:substitutable? #f
      #:validate-runpath? #f
      #:modules '((guix build gnu-build-system) (guix build utils)
                  (ice-9 format))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'check)
          (replace 'build
            (lambda* (#:key inputs #:allow-other-keys)
              (define (in name) (assoc-ref inputs name))
              (let ((cuda (in "cuda-toolkit"))
                    (gcc14 (in "gcc-toolchain"))
                    (ggml (in "llama-cpp-for-strata")))
                ;; The wrapped nvcc segfaults when not found in $PATH.
                (setenv "PATH" (string-append cuda "/bin:" (getenv "PATH")))
                (invoke
                 "cmake" "-S" "." "-B" "build" "-G" "Ninja"
                 "-DCMAKE_BUILD_TYPE=Release"
                 ;; nvcc 13 supports host GCC up to 14; keep the whole build
                 ;; on one libstdc++ instead of mixing host compilers.
                 (string-append "-DCMAKE_C_COMPILER=" gcc14 "/bin/gcc")
                 (string-append "-DCMAKE_CXX_COMPILER=" gcc14 "/bin/g++")
                 "-DSTRATA_ENABLE_CUDA=ON" "-DSTRATA_BUILD_TESTS=OFF"
                 "-DSTRATA_Q6K_EXPERTS=ON"
                 (string-append "-DCMAKE_CUDA_COMPILER=" cuda "/bin/nvcc")
                 (string-append "-DCMAKE_CUDA_HOST_COMPILER=" gcc14 "/bin/g++")
                 (string-append "-DCMAKE_CUDA_ARCHITECTURES="
                                #$%strata-cuda-architectures)
                 (string-append "-DCUDAToolkit_ROOT=" cuda)
                 (string-append "-DSTRATA_GGML_DIR=" ggml))
                (invoke "cmake" "--build" "build" "-j"
                        (number->string (parallel-job-count))))))
          (replace 'install
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (define (in name) (assoc-ref inputs name))
              (let* ((bin (string-append #$output "/bin"))
                     (libexec (string-append #$output "/libexec/strata"))
                     (rpath (string-join
                             (map (lambda (n)
                                    (string-append (in n) "/lib"))
                                  '("cuda-toolkit" "gcc-toolchain"))
                             ":"))
                     (sh (string-append (in "bash-minimal") "/bin/sh")))
                (mkdir-p libexec)
                (mkdir-p bin)
                (for-each
                 (lambda (name)
                   (let ((exe (string-append "build/" name))
                         (dst (string-append libexec "/" name))
                         (wrap (string-append bin "/" name)))
                     (when (file-exists? exe)
                       (copy-file exe dst)
                       (chmod dst #o755)
                       (invoke "patchelf" "--set-rpath" rpath dst)
                       ;; libcuda.so.1 is part of the host's driver and never
                       ;; enters the store; the Guix loader searches only
                       ;; RUNPATH, LD_LIBRARY_PATH and its cache, so expose
                       ;; the usual driver locations through LD_LIBRARY_PATH.
                       (call-with-output-file wrap
                         (lambda (port)
                           (format port "#!~a
for d in /run/opengl-driver/lib /run/current-system/profile/lib \\
         \"$HOME/.guix-home/profile/lib\" \"$HOME/.guix-profile/lib\" \\
         /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib /lib
do
  case \":$LD_LIBRARY_PATH:\" in
    *\":$d:\"*) ;;
    *) [ -e \"$d\" ] && LD_LIBRARY_PATH=\"${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$d\" ;;
  esac
done
export LD_LIBRARY_PATH
exec \"~a/~a\" \"$@\"
" sh libexec name)))
                       (chmod wrap #o555))))
                 '("strata" "strata-device" "strata-gguf" "strata-dequant"
                   "strata-plan" "strata-load" "strata-concurrent"
                   "strata-overlap"))
                (invoke (string-append bin "/strata") "--help")
                (invoke (string-append bin "/strata-device") "--help")))))))
    (native-inputs
     (list cmake-minimal ninja patchelf binutils pkg-config linux-libre-headers
           llama-cpp-for-strata %cuda-host-toolchain))
    (inputs
     (list bash-minimal cuda-13 %cuda-host-toolchain))
    (synopsis "Local Qwen3.8-Flash-Next inference engine (NVIDIA/CUDA backend)")
    (description "Strata runs a large Qwen3.8-Flash-Next model on a consumer
PC.  This package builds the engine from source for the NVIDIA CUDA backend
using the non-free CUDA 13.0 toolkit from the guix-hpc-non-free channel; it
targets NVIDIA GPUs of compute capability 7.5 or newer (RTX 20/30/40/50), and
by default generates code for sm_120 (RTX 50).  libcuda.so.1 comes from the
host's NVIDIA driver at run time.  Model weights are downloaded at run time
and are not included.")
    (license license:expat)))
