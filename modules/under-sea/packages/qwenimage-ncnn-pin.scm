;;; Generated pin data for the ncnn revision used by qwenimage-ncnn-vulkan.
(define-module (under-sea packages qwenimage-ncnn-pin)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix base32)
  #:export (%ncnn-version %ncnn-commit %ncnn-source))

(define-public %ncnn-version "20260924")
(define-public %ncnn-commit "c6b351b56fbe32e0381ae00331e3df649b20d7b7")
(define-public %ncnn-source
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://github.com/Tencent/ncnn")
          (commit %ncnn-commit)))
    (file-name (git-file-name "ncnn" %ncnn-version))
    (sha256
     (base32 "196h61m6axq4z0qr5x8jwyihvq28mz1b1wyv5azwkm127gqjl532"))))
