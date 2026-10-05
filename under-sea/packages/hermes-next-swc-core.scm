(define-module (under-sea packages hermes-next-swc-core)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (under-sea packages hermes-node-native)
  #:use-module (under-sea packages hermes-next-swc-binding-lock))

(define-public swc-core-binding-for-hermes-next
  (let ((base
         (native-binding "swc-core-binding-for-hermes-next" "1.11.24"
                         %hermes-swc-source %hermes-swc-crates
                         "binding_core_node" "libbinding_core_node.so"
                         "@swc/core-linux-x64-gnu" license:asl2.0)))
    (package
      (inherit base)
      (arguments
       (substitute-keyword-arguments (package-arguments base)
         ((#:phases phases)
          #~(modify-phases #$phases
              ;; The Node binding has its own authored workspace and lock.
              ;; Vendor paths in CARGO_HOME remain absolute after chdir.
              (add-before 'build 'enter-binding-workspace
                (lambda _ (chdir "bindings"))))))))))
