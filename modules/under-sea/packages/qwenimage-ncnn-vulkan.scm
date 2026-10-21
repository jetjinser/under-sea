;;; qwenimage-ncnn-vulkan - Qwen-Image text-to-image and image editing
;;; implemented with ncnn and Vulkan (nihui), packaged from source together
;;; with the ncnn revision its src/ncnn submodule pins.  Apache-2.0 licensed.
;;;
;;; Both halves build offline from pinned Git origins.  ncnn is built for
;;; Vulkan (NCNN_SIMPLEVK, its in-house dlopen-based loader) using Guix's
;;; glslang; qwenimage-ncnn-vulkan links that ncnn and Guix's JPEG/PNG/WebP/
;;; zlib rather than the bundled submodules.

(define-module (under-sea packages qwenimage-ncnn-vulkan)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix gexp)
  #:use-module (guix build-system cmake)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages image)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages vulkan)
  #:export (ncnn
            qwenimage-ncnn-vulkan))

;; Anchor for local-file references next to this module.  In compiled
;; channel contexts current-filename is #f, so fall back to locating this
;; very file through %load-path.
(define %source-directory
  (dirname
   (or (current-filename)
       (search-path %load-path "under-sea/packages/qwenimage-ncnn-vulkan.scm")
       (error "under-sea/packages/qwenimage-ncnn-vulkan.scm not found on %load-path"))))

(define %ncnn-commit "c6b351b56fbe32e0381ae00331e3df649b20d7b7")

(define-public ncnn
  (package
    (name "ncnn")
    (version "20260924")
    (properties '((upstream-github "Tencent/ncnn")))
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/Tencent/ncnn")
             (commit %ncnn-commit)))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "196h61m6axq4z0qr5x8jwyihvq28mz1b1wyv5azwkm127gqjl532"))))
    (build-system cmake-build-system)
    (native-inputs (list glslang pkg-config))
    (inputs (list vulkan-headers))
    (arguments
     (list
      ;; Vulkan compute with the in-house loader (NCNN_SIMPLEVK dlopens
      ;; libvulkan.so.1), and Guix's glslang for the offline shader compile
      ;; instead of the glslang submodule a tarball checkout would lack.
      #:configure-flags
      #~(list "-DNCNN_VULKAN=ON"
              "-DNCNN_SYSTEM_GLSLANG=ON"
              "-DNCNN_SHARED_LIB=ON"
              "-DNCNN_BUILD_TESTS=OFF"
              "-DNCNN_BUILD_BENCHMARK=OFF"
              "-DNCNN_BUILD_EXAMPLES=OFF"
              "-DNCNN_BUILD_TOOLS=OFF")
      #:tests? #f))
    (synopsis "Neural network inference framework for mobile and embedded")
    (description
     "ncnn is a high-performance neural network inference framework optimized
for the mobile platform.  It ships no third-party dependencies, is built
around Vulkan compute for GPU acceleration, and supports a large set of CNN
layers through a compact model format.")
    (home-page "https://github.com/Tencent/ncnn")
    (license license:bsd-3)))

(define-public qwenimage-ncnn-vulkan
  (package
    (name "qwenimage-ncnn-vulkan")
    (version "20261010")
    (properties '((upstream-github "nihui/qwenimage-ncnn-vulkan")))
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/nihui/qwenimage-ncnn-vulkan")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "101yyd87z5xdq0f2bqa8v23ibvf2fpzsvnlzdz62fgvadqqcdh3k"))
       (patches
        (list
         (local-file (string-append %source-directory
                                    "/patches/qwenimage-ncnn-vulkan-system-deps.patch"))
         (local-file (string-append %source-directory
                                    "/patches/qwenimage-ncnn-vulkan-find-webp.patch"))))))
    (build-system cmake-build-system)
    (native-inputs (list pkg-config))
    (inputs (list ncnn
                  glslang
                  libjpeg-turbo
                  libpng
                  libwebp
                  vulkan-loader
                  vulkan-headers
                  zlib
                  bash-minimal))
    (arguments
     (list
      #:configure-flags
      #~(list "-DUSE_SYSTEM_NCNN=ON"
              "-DUSE_SYSTEM_JPEG=ON"
              "-DUSE_SYSTEM_ZLIB=ON"
              "-DUSE_SYSTEM_PNG=ON"
              "-DUSE_SYSTEM_WEBP=ON")
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'configure 'chdir-to-src
            (lambda _
              ;; CMakeLists.txt and the dependency cmake modules live in src/.
              (chdir "src")))
          (add-after 'install 'wrap-vulkan-loader
            (lambda* (#:key outputs #:allow-other-keys)
              ;; ncnn's NCNN_SIMPLEVK loader dlopens libvulkan.so.1 at run
              ;; time, which a build input cannot satisfy; make it visible.
              (let ((out (assoc-ref outputs "out")))
                (wrap-program (string-append out "/bin/qwenimage-ncnn-vulkan")
                  `("LD_LIBRARY_PATH" ":" prefix
                    (,(string-append #$vulkan-loader "/lib"))))))))))
    (synopsis "Qwen-Image text-to-image and image editing on ncnn + Vulkan")
    (description
     "qwenimage-ncnn-vulkan is a portable implementation of the Qwen-Image
text-to-image model and its image editing pipeline on ncnn and Vulkan.  A
single executable performs text-to-image generation and instruction-driven
image editing on GPUs supporting Vulkan compute.")
    (home-page "https://github.com/nihui/qwenimage-ncnn-vulkan")
    (license license:asl2.0)))
