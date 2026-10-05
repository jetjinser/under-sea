;;; Java source dependencies of the Hermes browser WASM build tools.
(define-module (under-sea packages hermes-java-tools)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix build-system ant)
  #:use-module (guix build-system cmake)
  #:use-module (gnu packages java)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages python)
  #:use-module ((guix licenses) #:prefix license:)
  #:export (make-java-source-annotations))

(define* (make-java-source-annotations name version maven-path checksum license
                                      #:optional (dependencies '()))
  (package
    (name name)
    (version version)
    (source
     (origin
       (method url-fetch)
       ;; This is an archive of Java source files, not the binary Maven jar.
       (uri (string-append "https://repo.maven.apache.org/maven2/"
                           maven-path "-sources.jar"))
       (file-name (string-append name "-" version "-sources.jar"))
       (sha256 (base16-string->bytevector checksum))))
    (build-system ant-build-system)
    (arguments
     (list
      #:jar-name (string-append name ".jar")
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'check-source-only-archive
            (lambda _
              (unless (null? (find-files "src" "\\.(class|so|dll|exe)$"))
                (error "Binary payload in Java source archive"))
              (when (file-exists? "src/META-INF/LICENSE.txt")
                (copy-file "src/META-INF/LICENSE.txt" "LICENSE.txt")))))))
    (propagated-inputs dependencies)
    (home-page "https://central.sonatype.com")
    (synopsis "Source-built annotations for the Hermes compiler toolchain")
    (description "This package compiles the complete published Java annotation
sources needed by the Guava and Closure build tools.  The authenticated input
is a source-only archive; no precompiled Maven classes are installed.")
    (license license)))

(define-public java-jsr305-for-hermes-guava
  (make-java-source-annotations
   "java-jsr305-for-hermes-guava" "3.0.2"
   "com/google/code/findbugs/jsr305/3.0.2/jsr305-3.0.2"
   "1c9e85e272d0708c6a591dc74828c71603053b48cc75ae83cce56912a2aa063b"
   license:asl2.0))

(define-public java-checker-qual-for-hermes-guava
  (make-java-source-annotations
   "java-checker-qual-for-hermes-guava" "3.12.0"
   "org/checkerframework/checker-qual/3.12.0/checker-qual-3.12.0"
   "fd99a45195ed893803624d1030387056a96601013f5e61ccabd79abb4ddfa876"
   license:expat))

(define-public java-j2objc-annotations-for-hermes-guava
  (make-java-source-annotations
   "java-j2objc-annotations-for-hermes-guava" "1.3"
   "com/google/j2objc/j2objc-annotations/1.3/j2objc-annotations-1.3"
   "ba4df669fec153fa4cd0ef8d02c6d3ef0702b7ac4cabe080facf3b6e490bb972"
   license:asl2.0))

(define-public java-error-prone-annotations-for-hermes-guava
  (make-java-source-annotations
   "java-error-prone-annotations-for-hermes-guava" "2.7.1"
   "com/google/errorprone/error_prone_annotations/2.7.1/error_prone_annotations-2.7.1"
   "e38921f918b8ad8eabd12bc61de426fa96c72de077054e9147d2f9fe7c648923"
   license:asl2.0 (list java-jsr305-for-hermes-guava)))

(define-public java-error-prone-annotations-for-hermes-closure
  (make-java-source-annotations
   "java-error-prone-annotations-for-hermes-closure" "2.3.2"
   "com/google/errorprone/error_prone_annotations/2.3.2/error_prone_annotations-2.3.2"
   "7ce688ed1582a67097228c050192b7cfd00479a81d2b921f7cd5116994f1402d"
   license:asl2.0 (list java-jsr305)))

(define %guava-31.0.1-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/google/guava/tar.gz/refs/tags/v31.0.1")
    (file-name "guava-31.0.1-source.tar.gz")
    (sha256
     (base16-string->bytevector
      "a65a64870390c021a2fd336f98256966bc11c5400a6aac86e2994c25c0040696"))))

(define-public java-failureaccess-for-hermes-closure
  (package
    (name "java-failureaccess-for-hermes-closure")
    (version "1.0.1")
    (source %guava-31.0.1-source)
    (build-system ant-build-system)
    (arguments
     (list #:jar-name "failureaccess.jar"
           #:source-dir "futures/failureaccess/src"
           #:tests? #f))
    (home-page "https://github.com/google/guava")
    (synopsis "Source-built Guava failure-access runtime")
    (description "This package compiles the failureaccess 1.0.1 sources included
in the fixed Guava tree.  It supplies the shared internal future classes used
by Guava and Closure Compiler.")
    (license license:asl2.0)))

(define-public java-guava-for-hermes-closure
  (package
    (name "java-guava-for-hermes-closure")
    (version "31.0.1-jre")
    (source %guava-31.0.1-source)
    (build-system ant-build-system)
    (arguments
     (list #:jar-name "guava.jar"
           #:source-dir "guava/src"
           #:tests? #f))
    ;; Preserve upstream annotation metadata using source-built dependencies.
    ;; The Maven listenablefuture 9999 artifact is empty; Guava itself supplies
    ;; the class, so there is no missing runtime implementation to compile.
    (propagated-inputs
     (list java-failureaccess-for-hermes-closure
           java-jsr305-for-hermes-guava java-checker-qual-for-hermes-guava
           java-j2objc-annotations-for-hermes-guava
           java-error-prone-annotations-for-hermes-guava))
    (home-page "https://github.com/google/guava")
    (synopsis "Matching source-built Guava library for Closure Compiler")
    (description "This package builds Guava's JRE library from the exact source
release required by Closure Compiler v20220502.  Its annotation dependencies
are compiled from source, retaining the original Java annotation metadata.")
    (license license:asl2.0)))

(define-public java-j2objc-annotations-for-hermes-autovalue
  (make-java-source-annotations
   "java-j2objc-annotations-for-hermes-autovalue" "1.1"
   "com/google/j2objc/j2objc-annotations/1.1/j2objc-annotations-1.1"
   "2cd9022a77151d0b574887635cdfcdf3b78155b602abc89d7f8e62aba55cfb4f"
   license:asl2.0))

(define-public java-error-prone-annotations-for-hermes-autovalue
  (make-java-source-annotations
   "java-error-prone-annotations-for-hermes-autovalue" "2.0.18"
   "com/google/errorprone/error_prone_annotations/2.0.18/error_prone_annotations-2.0.18"
   "dbe7b49dd0584704d5c306b4ac7273556353ea3c0c6c3e50adeeca8df47047be"
   license:asl2.0 (list java-jsr305-for-hermes-guava)))

(define-public java-animal-sniffer-annotations-for-hermes-autovalue
  (make-java-source-annotations
   "java-animal-sniffer-annotations-for-hermes-autovalue" "1.14"
   "org/codehaus/mojo/animal-sniffer-annotations/1.14/animal-sniffer-annotations-1.14"
   "d821ae1f706db2c1b9c88d4b7b0746b01039dac63762745ef3fe5579967dd16b"
   license:expat))

(define-public java-guava-for-hermes-autovalue
  (package
    (inherit java-guava-for-hermes-closure)
    (name "java-guava-for-hermes-autovalue")
    (version "23.5-jre")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/google/guava/tar.gz/refs/tags/v23.5")
       (file-name "guava-23.5-source.tar.gz")
       (sha256
        (base16-string->bytevector
         "4919da78c7861651eeaedb26c2a77f3eaa63058b134235e831898f8568a29ea8"))))
    ;; Guava 23.5 declares JSR305 1.3.9, whose source jar is unpublished.
    ;; Explicitly select source-built 3.0.2 for its annotation interfaces;
    ;; retain all original annotations and register this version adjustment.
    (propagated-inputs
     ;; None of the 560 JRE Java sources references checkerframework.
     ;; Its Maven declaration is unused by this source artifact; unlike
     ;; Guava 31, this version needs no Checker qualifier compile input.
     (list java-jsr305-for-hermes-guava
           java-j2objc-annotations-for-hermes-autovalue
           java-error-prone-annotations-for-hermes-autovalue
           java-animal-sniffer-annotations-for-hermes-autovalue))
    (synopsis "Source-built Guava 23.5 for the AutoValue processor")
    (description "This package builds Guava 23.5's complete JRE library for
AutoValue 1.6.  All original annotations are preserved.  JSR305 is explicitly
updated from 1.3.9 to source-built 3.0.2; the used annotation dependencies use
the upstream declared versions.  The unused Maven Checker qualifier dependency
is not needed to compile this JRE source tree.")))

(define-public java-re2j-for-hermes-closure
  (package
    (name "java-re2j-for-hermes-closure")
    (version "1.3")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/google/re2j/tar.gz/refs/tags/re2j-1.3")
       (file-name "re2j-1.3-source.tar.gz")
       (sha256
        (base16-string->bytevector
         "2b73cc4a42743b006cb3ad891281a91c0ad82672864582f1c0eeee898ff87228"))))
    (build-system ant-build-system)
    (arguments
     (list
      #:jar-name "re2j.jar"
      #:source-dir "java"
      #:tests? #f ; Functional verification follows component completion.
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'remove-gradle-binary
            (lambda _
              ;; Ant compiles the authored Java sources without Gradle's
              ;; binary wrapper or its network-resolved development plugins.
              (delete-file "gradle/wrapper/gradle-wrapper.jar")))
          (add-after 'configure 'select-jvm-sources
            (lambda _
              ;; Match upstream sourceSets.main. The separate GWT supersource
              ;; redefines JVM classes and is not part of Closure's JVM jar.
              (substitute* "build.xml"
                (("srcdir=\"java\"")
                 "srcdir=\"java\" excludes=\"com/google/re2j/super/**\" source=\"1.6\" target=\"1.6\"")))))))
    (home-page "https://github.com/google/re2j")
    (synopsis "Source-built RE2/J dependency for Closure Compiler")
    (description "RE2/J provides linear-time regular expressions for Java.
This package builds the JVM library version required by the Closure Compiler
used in Hermes's browser WebAssembly toolchain.  It does not use Maven jars or
the binary Gradle wrapper supplied in the upstream archive.")
    (license license:bsd-3)))

(define %auto-value-1.6-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/google/auto/tar.gz/refs/tags/auto-value-1.6")
    (file-name "auto-value-1.6-source.tar.gz")
    (sha256
     (base16-string->bytevector
      "48e3d203d6c64c8e25efb0e7a7867ad0f08defbe6eaa79f11af2e4629a708e70"))))

(define-public java-auto-value-annotations-for-hermes-closure
  (package
    (name "java-auto-value-annotations-for-hermes-closure")
    (version "1.6")
    (source %auto-value-1.6-source)
    (build-system ant-build-system)
    (arguments
     (list
      #:jar-name "auto-value-annotations.jar"
      #:source-dir "value/src/main/java"
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'configure 'select-annotation-artifact
            (lambda _
              ;; Exactly the two source patterns of value/annotations/pom.xml.
              ;; The annotation processor is a distinct artifact with its own
              ;; dependencies; this jar does not substitute for that processor.
              (substitute* "build.xml"
                (("srcdir=\"value/src/main/java\"")
                 "srcdir=\"value/src/main/java\" includes=\"com/google/auto/value/*.java,com/google/auto/value/extension/memoized/*.java\"")))))))
    (home-page "https://github.com/google/auto")
    (synopsis "Source-built AutoValue annotations for Closure Compiler")
    (description "This package builds AutoValue 1.6's annotation-only artifact
from the original Google Auto sources.  It includes AutoValue, AutoAnnotation,
AutoOneOf and Memoized.  The separate annotation processor is required at
compiler build time and must be packaged independently.")
    (license license:asl2.0)))

(define %protobuf-3.19.3-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/protocolbuffers/protobuf/tar.gz/refs/tags/v3.19.3")
    (file-name "protobuf-3.19.3-source.tar.gz")
    (sha256
     (base16-string->bytevector
      "390191a0d7884b3e52bb812c440ad1497b9d484241f37bb8e2ccc8c2b72d6c36"))))

(define-public protobuf-for-hermes-closure
  (package
    (name "protobuf-for-hermes-closure")
    (version "3.19.3")
    (source %protobuf-3.19.3-source)
    (build-system cmake-build-system)
    (inputs (list zlib))
    (arguments
     (list
      #:substitutable? #f
      #:tests? #f
      #:configure-flags
      #~(list "-Dprotobuf_BUILD_TESTS=OFF"
              "-Dprotobuf_BUILD_SHARED_LIBS=ON"
              "-Dprotobuf_BUILD_PROTOC_BINARIES=ON"
              "-DCMAKE_POLICY_VERSION_MINIMUM=3.5")
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'enter-cmake-source
            (lambda _ (chdir "cmake"))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/protocolbuffers/protobuf")
    (synopsis "Matching source-built Protobuf generator for Closure Compiler")
    (description "This package provides protoc and the C++ Protocol Buffers
libraries from the exact source version used by Closure Compiler v20220502's
Bazel workspace.  Its matching Java runtime is built separately from the same
source release.  No precompiled protoc or Maven runtime jar is used.")
    (license license:bsd-3)))

(define-public java-protobuf-for-hermes-closure
  (package
    (name "java-protobuf-for-hermes-closure")
    (version "3.19.3")
    (source %protobuf-3.19.3-source)
    (build-system ant-build-system)
    (native-inputs (list protobuf-for-hermes-closure))
    (arguments
     (list
      #:jar-name "protobuf-java.jar"
      #:source-dir "java/core/src/main/java:generated-java"
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'build 'generate-java-protocols
            (lambda _
              ;; Match java/core/generate-sources-build.xml and the resource
              ;; list in java/core/pom.xml, using the matching source protoc.
              (let ((protos
                     '("google/protobuf/any.proto"
                       "google/protobuf/api.proto"
                       "google/protobuf/descriptor.proto"
                       "google/protobuf/duration.proto"
                       "google/protobuf/empty.proto"
                       "google/protobuf/field_mask.proto"
                       "google/protobuf/source_context.proto"
                       "google/protobuf/struct.proto"
                       "google/protobuf/timestamp.proto"
                       "google/protobuf/type.proto"
                       "google/protobuf/wrappers.proto"
                       "google/protobuf/compiler/plugin.proto")))
                (mkdir-p "generated-java")
                (apply invoke "protoc" "--java_out=generated-java"
                       "--proto_path=src"
                       (map (lambda (file) (string-append "src/" file)) protos))
                (for-each
                 (lambda (file)
                   (let ((destination (string-append "build/classes/" file)))
                     (mkdir-p (dirname destination))
                     (copy-file (string-append "src/" file) destination)))
                 protos)))))))
    (home-page "https://github.com/protocolbuffers/protobuf")
    (synopsis "Matching source-built Java Protobuf runtime for Closure")
    (description "This package compiles the complete Java core Protocol Buffers
runtime and its well-known protocol classes from source, using protoc built
from the same 3.19.3 release.  The original protocol resources are included in
the jar.  No precompiled Maven jar or generated binary is downloaded.")
    (license license:bsd-3)))

(define-public java-gson-for-hermes-closure
  (package
    (inherit java-gson)
    (name "java-gson-for-hermes-closure")
    (version "2.7")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/google/gson/tar.gz/refs/tags/gson-parent-2.7")
       (file-name "gson-2.7-source.tar.gz")
       (sha256
        (base16-string->bytevector
         "19fe8fe3b6b59c2ffd78b2086c23c982d1e5b908f3c5b6a4bf980adc53296e2c"))))
    (arguments
     (list #:jar-name "gson.jar"
           #:source-dir "gson/src/main/java"
           #:tests? #f))
    (native-inputs '())))

(define-public java-javapoet-for-hermes-closure
  (package
    (name "java-javapoet-for-hermes-closure")
    (version "1.9.0")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/square/javapoet/tar.gz/refs/tags/javapoet-1.9.0")
       (file-name "javapoet-1.9.0-source.tar.gz")
       (sha256
        (base16-string->bytevector
         "76032d4ca75b71269511f72ccffa904acf88972af9ee0b880c6cc74c5deb7071"))))
    (build-system ant-build-system)
    (arguments
     (list #:jar-name "javapoet.jar"
           #:source-dir "src/main/java"
           #:tests? #f))
    (home-page "https://github.com/square/javapoet")
    (synopsis "Source generation library for the AutoValue build tools")
    (description "JavaPoet provides a Java API for generating Java source files.
This package builds the version declared by the AutoValue 1.6 source tree for
the annotation processor needed to build Closure Compiler.")
    (license license:asl2.0)))

(define-public java-auto-common-for-hermes-autovalue
  (package
    (name "java-auto-common-for-hermes-autovalue")
    (version "0.10")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/google/auto/tar.gz/refs/tags/auto-common-0.10")
       (file-name "auto-common-0.10-source.tar.gz")
       (sha256
        (base16-string->bytevector
         "9e94ceada878571a030e327df894b82b9b6af728b0b41d2f029ac2cfe5421200"))))
    (build-system ant-build-system)
    (arguments
     (list #:jar-name "auto-common.jar"
           #:source-dir "common/src/main/java"
           #:tests? #f))
    (propagated-inputs
     (list java-guava-for-hermes-autovalue java-javapoet-for-hermes-closure))
    (home-page "https://github.com/google/auto")
    (synopsis "Source-built annotation processor utilities for AutoValue")
    (description "Auto Common provides Java annotation processor utilities.
This package builds the exact version declared by AutoValue 1.6, including
the JavaPoet-based generated annotation utilities.")
    (license license:asl2.0)))

(define-public java-auto-service-annotations-for-hermes-autovalue
  (package
    (name "java-auto-service-annotations-for-hermes-autovalue")
    (version "1.0-rc4")
    (source
     (origin
       (method url-fetch)
       (uri "https://repo.maven.apache.org/maven2/com/google/auto/service/auto-service/1.0-rc4/auto-service-1.0-rc4-sources.jar")
       (file-name "auto-service-1.0-rc4-sources.jar")
       (sha256
        (base16-string->bytevector
         "285a6d4bc111255b5c99f5393b833f8b9156c4acb4e6c3f7cdde8493e888dd27"))))
    (build-system ant-build-system)
    (arguments
     (list
      #:jar-name "auto-service-annotations.jar"
      #:source-dir "guix-annotation-source"
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'select-annotation-source
            (lambda _
              (let ((destination "guix-annotation-source/com/google/auto/service"))
                (mkdir-p destination)
                (copy-file "src/com/google/auto/service/AutoService.java"
                           (string-append destination "/AutoService.java")))))
          (add-after 'configure 'disable-annotation-processing-for-annotation-jar
            (lambda _
              ;; The source jar contains the processor's service descriptor,
              ;; but this separate artifact compiles only its annotation type.
              (substitute* "build.xml"
                (("<javac[^>]*>" opening)
                 (string-append opening "<compilerarg value=\"-proc:none\"/>"))))))))
    (home-page "https://github.com/google/auto")
    (synopsis "Source-built AutoService annotation for AutoValue")
    (description "This package builds the AutoService annotation from its exact
source release.  It supplies the annotation type used by AutoValue's processor
sources; service provider resources are generated separately from those sources.
It does not provide or substitute for the AutoService annotation processor.")
    (license license:asl2.0)))

(define-public java-auto-value-processor-for-hermes-closure
  (package
    (name "java-auto-value-processor-for-hermes-closure")
    (version "1.6")
    (source %auto-value-1.6-source)
    (build-system ant-build-system)
    (native-inputs (list python-minimal))
    (propagated-inputs
     (list java-auto-common-for-hermes-autovalue
           java-guava-for-hermes-autovalue java-javapoet-for-hermes-closure
           java-auto-service-annotations-for-hermes-autovalue))
    (arguments
     (list
      #:jar-name "auto-value.jar"
      #:source-dir "value/src/main/java"
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'build 'generate-service-and-template-resources
            (lambda _
              ;; Generate all upstream AutoService registrations from authored
              ;; annotations, without bootstrapping from a precompiled processor.
              (invoke "python3" #$(local-file "../../scripts/prepare-autovalue-services.py")
                      "value/src/main/java" "build/classes")))
          (add-after 'configure 'compile-processor-without-self-discovery
            (lambda _
              (substitute* "build.xml"
                (("<javac[^>]*>" opening)
                 (string-append opening "<compilerarg value=\"-proc:none\"/>"))))))))
    (home-page "https://github.com/google/auto")
    (synopsis "Complete source-built AutoValue annotation processor")
    (description "This package builds AutoValue 1.6's Java sources, including
all five annotation processors, the memoization extension and the source
templates.  Service metadata is generated from the original annotations.
Dependencies are unshaded source-built jars and should be kept on an isolated
processor path when compiling Closure against its newer Guava library.")
    (license license:asl2.0)))

(define-public ant-for-hermes-closure
  (package
    (inherit ant-1.10.14)
    (name "ant-for-hermes-closure")
    (version "1.10.11")
    (source
     (origin
       (inherit (package-source ant-1.10.14))
       (uri "https://archive.apache.org/dist/ant/source/apache-ant-1.10.11-src.tar.bz2")
       (file-name "apache-ant-1.10.11-src.tar.bz2")
       (sha256
        (base16-string->bytevector
         "fee49208ba798be2e4302917a64a89f6756da542a0c2a2673e727182618f79ac"))))
    ;; Retain Guix's source bootstrap and optional-jar removal. This version is
    ;; the Ant runtime explicitly declared by Closure's fixed Bazel workspace.
    (arguments
     (append (list #:substitutable? #f) (package-arguments ant-1.10.14)))))
