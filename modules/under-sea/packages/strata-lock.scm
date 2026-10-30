;;; Reproducibility inputs for the Strata engine source and GPU targets.
(define-module (under-sea packages strata-lock)
  #:export (%strata-llama-cpp-commit
            %strata-llama-cpp-sha256
            %strata-hip-architectures
            %strata-cuda-architectures))

(define-public %strata-llama-cpp-commit
  "3cf03257f219afbe7334045ff7c6a06ac68c627d")

(define-public %strata-llama-cpp-sha256
  "c076d7534afa0e5d0ec2a0d425b11e791c16f3de0d727221aea071cef156a280")

(define-public %strata-hip-architectures "gfx1100;gfx1201")
(define-public %strata-cuda-architectures "120")
