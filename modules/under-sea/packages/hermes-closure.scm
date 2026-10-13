;;; Source-built Closure Compiler for the Hermes browser WASM toolchain.
(define-module (under-sea packages hermes-closure)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages java)
  #:use-module (gnu packages python)
  #:use-module (gnu packages bash)
  #:use-module (under-sea packages hermes-java-tools)
  #:use-module ((guix licenses) #:prefix license:)
  #:export (%closure-runtime-libraries %closure-processor-libraries))

(define %closure-runtime-libraries
  (list java-args4j java-gson-for-hermes-closure
        java-guava-for-hermes-closure java-failureaccess-for-hermes-closure
        java-protobuf-for-hermes-closure java-re2j-for-hermes-closure
        java-auto-value-annotations-for-hermes-closure
        java-error-prone-annotations-for-hermes-closure java-jsr305
        java-jsr305-for-hermes-guava java-checker-qual-for-hermes-guava
        java-j2objc-annotations-for-hermes-guava
        java-error-prone-annotations-for-hermes-guava))

(define %closure-processor-libraries
  (list java-auto-value-processor-for-hermes-closure
        java-auto-common-for-hermes-autovalue java-guava-for-hermes-autovalue
        java-javapoet-for-hermes-closure
        java-auto-service-annotations-for-hermes-autovalue
        java-jsr305-for-hermes-guava
        java-j2objc-annotations-for-hermes-autovalue
        java-error-prone-annotations-for-hermes-autovalue
        java-animal-sniffer-annotations-for-hermes-autovalue))

(define-public closure-compiler-for-hermes-browser
  (package
    (name "closure-compiler-for-hermes-browser")
    (version "20220502")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/google/closure-compiler/tar.gz/refs/tags/v20220502")
       (file-name "closure-compiler-v20220502-source.tar.gz")
       (sha256
        (base16-string->bytevector
         "edb6c9df7ce6b3b06b6ab170d4d24b12eabd6f876856da4adcf6b470d02298f8"))))
    (build-system gnu-build-system)
    (native-inputs (list python-minimal (list openjdk11 "jdk")
                         protobuf-for-hermes-closure))
    (inputs
     (append (list bash-minimal ant-for-hermes-closure)
             %closure-runtime-libraries %closure-processor-libraries))
    (arguments
     (list
      #:substitutable? #f
      #:modules '((guix build gnu-build-system) (guix build utils) (srfi srfi-1))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          (replace 'build
            (lambda _
              (apply invoke "python3" #$(local-file "../../../scripts/build-hermes-closure.py")
                     (append
                      (list "--output" #$output
                            "--java" #$(file-append (gexp-input openjdk11 "jdk") "/bin/java")
                            "--javac" #$(file-append (gexp-input openjdk11 "jdk") "/bin/javac")
                            "--jar" #$(file-append (gexp-input openjdk11 "jdk") "/bin/jar")
                            "--protoc" #$(file-append protobuf-for-hermes-closure "/bin/protoc")
                            "--shell" #$(file-append bash-minimal "/bin/sh")
                            "--ant-input" #$ant-for-hermes-closure)
                      (append-map (lambda (directory) (list "--runtime-input" directory))
                                  (list #$@%closure-runtime-libraries))
                      (append-map (lambda (directory) (list "--processor-input" directory))
                                  (list #$@%closure-processor-libraries))))))
          (replace 'install (lambda _ #t)))))
    (supported-systems '("x86_64-linux"))
    (properties '((max-silent-time . 7200)))
    (home-page "https://github.com/google/closure-compiler")
    (synopsis "Source-built Closure Compiler and complete runtime resources")
    (description "This package compiles Closure Compiler v20220502 from its
authored Java and protocol sources using a source-built, isolated AutoValue
processor.  It regenerates the runtime typed AST from the original JavaScript
sources and includes the complete runtime, properties and externs resources.
The compiler, linter and instrumentation reporter have explicit Guix Java
classpath wrappers.  No precompiled Maven compiler jar is used.")
    (license license:asl2.0)))
