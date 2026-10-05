(define-module (under-sea packages hermes-next-rspack)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (under-sea packages hermes-node-native)
  #:use-module (under-sea packages hermes-next-rspack-lock)
  #:use-module ((under-sea packages hermes-next-1608-rspack-lock) #:prefix bootstrap:))

(define (rspack-source-binding name version source crates git-sources)
  (let ((base
         (native-binding name version source crates
                         "rspack_node" "librspack_node.so"
                         "@rspack/binding-linux-x64-gnu" license:expat)))
    (package
      (inherit base)
      (arguments
       (substitute-keyword-arguments (package-arguments base)
         ((#:phases phases)
          #~(modify-phases #$phases
              (add-before 'prepare-native-sources 'declare-owned-dependency-lifetime
                (lambda _
                  (invoke "python3" #$(local-file "../../scripts/patch-hermes-rspack.py")
                          ".")))
              (add-before 'prepare-native-sources 'prepare-locked-git-inputs
                (lambda _
                  ;; Keep upstream's unstable language features on the pinned
                  ;; Guix source-built compiler; do not remove plugin code.
                  (setenv "RUSTC_BOOTSTRAP" "1")
                  (call-with-output-file "git-sources.tsv"
                    (lambda (port)
                      (for-each
                       (match-lambda
                         ((identity name archive)
                          (format port "~a\t~a\t~a~%" identity name archive)))
                       '#$git-sources)))))
              (replace 'build
                (lambda _
                  ;; Match the native release's plugin and logging features.
                  ;; Guix supplies its source-built standard library rather
                  ;; than upstream's additional size-optimized std rebuild.
                  (invoke "cargo" "build" "--release" "--offline" "--locked"
                          "-p" "rspack_node" "--no-default-features"
                          "--features" "plugin,info-level"))))))))))

(define-public rspack-binding-for-hermes-next
  (rspack-source-binding "rspack-binding-for-hermes-next" "1.6.7"
                         %hermes-rspack-source %hermes-rspack-crates
                         %hermes-rspack-git-sources))

(define-public rspack-binding-for-hermes-next-1608
  (rspack-source-binding "rspack-binding-for-hermes-next-1608" "1.6.0"
                         bootstrap:%hermes-rspack-source bootstrap:%hermes-rspack-crates
                         bootstrap:%hermes-rspack-git-sources))
