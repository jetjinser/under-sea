;;; Generated pin data for qwenimage-ncnn-vulkan.
(define-module (under-sea packages qwenimage-pin)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix base32)
  #:export (%qwenimage-version %qwenimage-commit %qwenimage-source))

(define-public %qwenimage-version "20261010")
(define-public %qwenimage-commit "20261010")
(define-public %qwenimage-source
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://github.com/nihui/qwenimage-ncnn-vulkan")
          (commit %qwenimage-commit)))
    (file-name "qwenimage-ncnn-vulkan-20261010-checkout")
    (sha256
     (base32 "101yyd87z5xdq0f2bqa8v23ibvf2fpzsvnlzdz62fgvadqqcdh3k"))))
