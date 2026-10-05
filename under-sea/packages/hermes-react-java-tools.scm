;;; Exact Java source inputs for React's Closure Compiler release.
(define-module (under-sea packages hermes-react-java-tools)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (under-sea packages hermes-java-tools)
  #:use-module (gnu packages java)
  #:use-module ((guix licenses) #:prefix license:))

(define-public java-jspecify-for-hermes-react
  (let ((base (make-java-source-annotations
   "java-jspecify-for-hermes-react" "0.2.0"
   "org/jspecify/jspecify/0.2.0/jspecify-0.2.0"
   "23410079f602bbe11704a4d883729c8b2c431035b9c0fb1dfcdb3c125d1bf1f4"
   license:asl2.0)))
    (package
      (inherit base)
      (arguments
       (substitute-keyword-arguments (package-arguments base)
         ((#:jdk _ #f) openjdk11))))))

(define %protobuf-react-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/protocolbuffers/protobuf/tar.gz/refs/tags/v21.12")
    (file-name "protobuf-3.21.12-react-source.tar.gz")
    (sha256 (base16-string->bytevector
             "22fdaf641b31655d4b2297f9981fa5203b2866f8332d3c6333f6b0107bb320de"))))

(define-public protobuf-for-hermes-react-closure
  (package
    (inherit protobuf-for-hermes-closure)
    (name "protobuf-for-hermes-react-closure")
    (version "3.21.12")
    (source %protobuf-react-source)
    (description "This package compiles the exact protobuf 3.21.12 protoc and
C++ runtime needed by React's Closure Compiler. Functional validation is deferred.")))

(define-public java-protobuf-for-hermes-react-closure
  (package
    (inherit java-protobuf-for-hermes-closure)
    (name "java-protobuf-for-hermes-react-closure")
    (version "3.21.12")
    (source %protobuf-react-source)
    (native-inputs (list protobuf-for-hermes-react-closure))
    (description "This package compiles the complete matching protobuf Java
runtime and regenerates its well-known protocol classes with source-built protoc
3.21.12. Functional validation is deferred.")))

(define-public java-gson-for-hermes-react-closure
  (package
    (inherit java-gson-for-hermes-closure)
    (name "java-gson-for-hermes-react-closure")
    (version "2.9.1")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/google/gson/tar.gz/refs/tags/gson-parent-2.9.1")
       (file-name "gson-2.9.1-react-source.tar.gz")
       (sha256 (base16-string->bytevector
                "30431afdd99f21b88174459806ce5c86122a5ef73d0205c8746c48e652d2763d"))))
    (arguments
     (substitute-keyword-arguments (package-arguments java-gson-for-hermes-closure)
       ((#:jdk _ #f) openjdk11)
       ((#:phases phases #~%standard-phases)
        #~(modify-phases #$phases
            (add-before 'build 'generate-authored-version-template
              (lambda _
                (let ((template "gson/src/main/java-templates/com/google/gson/internal/GsonBuildConfig.java")
                      (destination "gson/src/main/java/com/google/gson/internal/GsonBuildConfig.java"))
                  (copy-file template destination)
                  (substitute* destination
                    (("\\$\\{project.version\\}") "2.9.1")))))))))
    (description "This package compiles Gson 2.9.1 from its authored Java
sources, generating the upstream version template with the fixed source release
version. It supplies the exact runtime required by React's Closure Compiler;
functional validation is deferred.")))

(define-public java-error-prone-annotations-for-hermes-react
  (make-java-source-annotations
   "java-error-prone-annotations-for-hermes-react" "2.15.0"
   "com/google/errorprone/error_prone_annotations/2.15.0/error_prone_annotations-2.15.0"
   "c1b58a188fb4eca9ccefbaff21209eb07df87751384e694b908a3df0288bef97"
   license:asl2.0 (list java-jsr305)))
