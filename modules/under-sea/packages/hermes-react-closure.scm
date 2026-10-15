(define-module (under-sea packages hermes-react-closure)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (under-sea gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system trivial)
  #:use-module (gnu packages python)
  #:use-module (gnu packages java)
  #:use-module (gnu packages bash)
  #:use-module (srfi srfi-1)
  #:use-module (under-sea packages hermes-closure)
  #:use-module (under-sea packages hermes-java-tools)
  #:use-module (under-sea packages hermes-react-java-tools))

(define %react-closure-runtime
  (append
   (list java-gson-for-hermes-react-closure
         java-protobuf-for-hermes-react-closure
         java-jspecify-for-hermes-react
         java-error-prone-annotations-for-hermes-react)
   (filter
    (lambda (p)
      (not (memq p (list java-gson-for-hermes-closure
                         java-protobuf-for-hermes-closure
                         java-error-prone-annotations-for-hermes-closure
                         java-error-prone-annotations-for-hermes-guava))))
    %closure-runtime-libraries)))

(define-public closure-compiler-for-hermes-react
  (package
    (inherit closure-compiler-for-hermes-browser)
    (name "closure-compiler-for-hermes-react")
    (version "20230206")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/google/closure-compiler/tar.gz/refs/tags/v20230206")
       (file-name "closure-compiler-v20230206-react-source.tar.gz")
       (sha256 (base16-string->bytevector
                "07f403c7622e4ce677f4a66ecd3d365d7f3be455610e66ed33e1c8fef8077ace"))))
    (native-inputs (list python-minimal (list openjdk11 "jdk")
                         protobuf-for-hermes-react-closure))
    (inputs
     (append (list bash-minimal ant-for-hermes-closure)
             %react-closure-runtime %closure-processor-libraries))
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
              (apply invoke "python3" #$(under-sea-script "build-hermes-closure.py")
                     (append
                      (list "--output" #$output "--compiler-version" "20230206"
                            "--java" #$(file-append (gexp-input openjdk11 "jdk") "/bin/java")
                            "--javac" #$(file-append (gexp-input openjdk11 "jdk") "/bin/javac")
                            "--jar" #$(file-append (gexp-input openjdk11 "jdk") "/bin/jar")
                            "--protoc" #$(file-append protobuf-for-hermes-react-closure "/bin/protoc")
                            "--shell" #$(file-append bash-minimal "/bin/sh")
                            "--ant-input" #$ant-for-hermes-closure)
                      (append-map (lambda (directory) (list "--runtime-input" directory))
                                  (list #$@%react-closure-runtime))
                      (append-map (lambda (directory) (list "--processor-input" directory))
                                  (list #$@%closure-processor-libraries))))))
          (replace 'install (lambda _ #t)))))
    (synopsis "Source-built Closure Compiler matching the React release build")
    (description "This package compiles the authored Closure 20230206 Java
compiler and protocols with matching source-built runtime libraries.  It regenerates
the typed AST from JavaScript sources and installs externs, runtime resources and
compiler/linter/reporter wrappers.  Functional validation is deferred.")))

(define-public closure-java-node-for-hermes-react
  (package
    (name "closure-java-node-for-hermes-react")
    (version "20230206.0.0")
    (source
     (origin
       (method url-fetch)
       (uri "https://registry.npmjs.org/google-closure-compiler-java/-/google-closure-compiler-java-20230206.0.0.tgz")
       (sha256 (base16-string->bytevector
                "7fff1d9b5f552568197ffbfc46a12b9f9211a59321e0cd94dbe13c7026ca8d81"))))
    (build-system trivial-build-system)
    (native-inputs (list python-minimal))
    (inputs (list closure-compiler-for-hermes-react))
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (invoke #$(file-append python-minimal "/bin/python3")
                  #$(under-sea-script "build-closure-java-node-provider.py")
                  #$source #$closure-compiler-for-hermes-react
                  (string-append #$output
                                 "/lib/node_modules/google-closure-compiler-java")))))
    (home-page "https://github.com/google/closure-compiler-npm")
    (synopsis "Closure npm Java provider backed by source-built Java libraries")
    (description "This package preserves the authored npm Java provider interface
and replaces its bundled binary compiler with a deterministic launcher manifest.
The launcher refers to the complete source-built Closure compiler and Java runtime
classpath.  No compiled classes from the npm archive are installed.  Functional
validation is deferred until the final component combination is complete.")
    (license license:asl2.0)))

(define-public closure-node-for-hermes-react
  (package
    (inherit closure-java-node-for-hermes-react)
    (name "closure-node-for-hermes-react")
    (source
     (origin
       (method url-fetch)
       (uri "https://registry.npmjs.org/google-closure-compiler/-/google-closure-compiler-20230206.0.0.tgz")
       (sha256 (base16-string->bytevector
                "1e3c803e052cf32ad89302987463e2667339c4d45ee8ebcdb3a57b63c0d01d4a"))))
    (inputs (list closure-java-node-for-hermes-react))
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (invoke #$(file-append python-minimal "/bin/python3")
                  #$(under-sea-script "build-closure-node-provider.py")
                  #$source #$closure-java-node-for-hermes-react #$output))))
    (synopsis "Authored Closure Node API with a fixed source-built JVM")
    (description "This package installs the authored Closure Node API and fixes
its default Java executable to the source-built Java provider.  The original API,
JVM argument handling and package metadata are retained.  JavaScript dependencies
are supplied by the consuming source module graph; optional native acceleration
is tracked separately.  Functional validation is deferred.")))
