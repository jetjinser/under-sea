;;; Authored JavaScript tools for the source-built Emscripten pipeline.
(define-module (under-sea packages hermes-emscripten-tools)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system cmake)
  #:use-module (guix build-system trivial)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages bash)
  #:use-module (under-sea packages hermes-closure)
  #:use-module (gnu packages node)
  #:use-module (gnu packages python)
  #:use-module (under-sea packages hermes-esbuild)
  #:use-module ((guix licenses) #:prefix license:))

(define-public acorn-for-hermes-emscripten
  (package
    (name "acorn-for-hermes-emscripten")
    (version "8.7.1")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/acornjs/acorn/tar.gz/04bdf9a67ebc38e8de717db5311a5401c8f1b6c5")
       (file-name "acorn-8.7.1-source.tar.gz")
       (sha256
        (base16-string->bytevector
         "f0b23901b5c69ce4de0b71ecc58d33a4e39802d236342e29a31c8e787a5a2e68"))))
    (build-system gnu-build-system)
    (native-inputs (list python-minimal esbuild-for-hermes))
    (inputs (list node))
    (arguments
     (list
      #:substitutable? #f
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          (add-after 'unpack 'expose-parser-license
            (lambda _ (copy-file "acorn/LICENSE" "LICENSE")))
          (replace 'build
            (lambda _
              (invoke "python3" #$(local-file "../../../scripts/build-hermes-acorn.py")
                      #$output #$(file-append node "/bin/node"))))
          (replace 'install (lambda _ #t)))))
    (home-page "https://github.com/acornjs/acorn")
    (synopsis "Source-built Acorn parser for the Guix Emscripten toolchain")
    (description "This package builds Acorn 8.7.1's authored parser sources,
UMD and ESM modules, type declarations and CLI for the modern Guix Node runtime.
It preserves the complete parser API and uses source-built esbuild rather than
shipping a precompiled npm JavaScript bundle.  This toolchain variant targets
Node 16 or newer and does not claim historical Node 0.4 compatibility.")
    (license license:expat)))

(define-public binaryen-for-hermes-emscripten
  (package
    (name "binaryen-for-hermes-emscripten")
    (version "111")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://codeload.github.com/WebAssembly/binaryen/"
                           "tar.gz/refs/tags/version_" version))
       (file-name (string-append "binaryen-" version "-source.tar.gz"))
       (sha256
        (base16-string->bytevector
         "c518b1146713bc2406dd09a1a1b18f31a283f8ac1fe200efa38834dbd95a1997"))))
    (build-system cmake-build-system)
    (arguments
     (list #:tests? #f
           #:substitutable? #f
           #:configure-flags
           #~(list "-DBUILD_TESTS=OFF" "-DBUILD_TOOLS=ON"
                   "-DENABLE_WERROR=OFF"
                   "-DCMAKE_POLICY_VERSION_MINIMUM=3.5")
           #:phases
           #~(modify-phases %standard-phases
               (add-after 'unpack 'include-fixed-width-integer-types
                 (lambda _
                   (substitute* "src/wat-lexer.h"
                     (("#include <optional>")
                      "#include <cstdint>\n#include <optional>")))))))
    (home-page "https://github.com/WebAssembly/binaryen")
    (synopsis "Source-built Binaryen matching Emscripten 3.1.31")
    (description "This package builds the complete Binaryen 111 library and
command-line tools from source for Emscripten 3.1.31 and Yoga.  Test executables
are omitted; the production tools and full DWARF support retain upstream defaults.")
    (license license:asl2.0)))

(define-public llvm-for-hermes-emscripten
  (package
    (name "llvm-for-hermes-emscripten")
    (version (package-version llvm-17))
    (source #f)
    (build-system trivial-build-system)
    (inputs (list llvm-17 clang-17 lld-17 bash-minimal))
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let ((bin (string-append #$output "/bin")))
            (mkdir-p bin)
            (for-each
             (lambda (entry)
               (let ((root (car entry)))
                 (for-each
                  (lambda (tool)
                    (let ((path (string-append root "/bin/" tool)))
                      (unless (file-exists? path)
                        (error "Missing Emscripten LLVM tool" path))
                      (let ((destination (string-append bin "/" tool)))
                        (if (member tool '("clang" "clang++"))
                            (begin
                              (call-with-output-file destination
                                (lambda (port)
                                  (format port "#!~a\ntask_cache=\"${EM_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/hermes-emscripten-3.1.31}\"\nexec ~s -nostdlibinc -isystem \"$task_cache/sysroot/include/c++/v1\" -isystem \"$task_cache/sysroot/include/fakesdl\" -isystem \"$task_cache/sysroot/include/compat\" -isystem \"$task_cache/sysroot/include\" \"$@\"\n"
                                          #$(file-append bash-minimal "/bin/sh") path)))
                              (chmod destination #o755))
                            (symlink path destination)))))
                  (cdr entry))))
             (list (cons #$clang-17 '("clang" "clang++"))
                   (cons #$llvm-17 '("llvm-ar" "llvm-ranlib" "llvm-nm"
                                    "llvm-objcopy" "llvm-readobj" "llvm-dwp"
                                    "llvm-dwarfdump" "llvm-strip"))
                   (cons #$lld-17 '("wasm-ld" "ld.lld"))))))))
    (home-page "https://llvm.org")
    (synopsis "Matching LLVM 17 tool directory for Emscripten")
    (description "This package assembles the source-defined Guix LLVM, Clang
and LLD 17 tools into the single tool directory required by Emscripten 3.1.31.
Each link retains its original Guix runtime closure.  It does not download an
emsdk toolchain.")
    (license license:asl2.0)))

(define-public emscripten-for-hermes-yoga
  (package
    (name "emscripten-for-hermes-yoga")
    (version "3.1.31")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://codeload.github.com/emscripten-core/emscripten/"
                           "tar.gz/refs/tags/" version))
       (file-name (string-append "emscripten-" version "-source.tar.gz"))
       (sha256
        (base16-string->bytevector
         "3c6a76fe179e22dba55cf30fdb9bcee23629491d72df7caf7cbd7816c1acd65d"))))
    (build-system gnu-build-system)
    (native-inputs (list python-minimal))
    (inputs (list bash-minimal python-minimal node llvm-for-hermes-emscripten
                  binaryen-for-hermes-emscripten acorn-for-hermes-emscripten
                  closure-compiler-for-hermes-browser))
    (arguments
     (list
      #:substitutable? #f
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          (replace 'build (lambda _ #t))
          (replace 'install
            (lambda _
              (invoke "python3" #$(local-file "../../../scripts/install-hermes-emscripten.py")
                      "--output" #$output
                      "--python" #$(file-append python-minimal "/bin/python3")
                      "--shell" #$(file-append bash-minimal "/bin/sh")
                      "--node" #$(file-append node "/bin/node")
                      "--llvm" #$llvm-for-hermes-emscripten
                      "--binaryen" #$binaryen-for-hermes-emscripten
                      "--acorn" #$acorn-for-hermes-emscripten
                      "--closure" #$closure-compiler-for-hermes-browser))))))
    (home-page "https://emscripten.org")
    (synopsis "Authored Emscripten compiler and fixed tools for Yoga")
    (description "This package installs Emscripten 3.1.31's authored compiler,
bindings and C/C++ system-library sources with matching source-built tool
providers for Yoga.  System libraries are compiled by consumers in a writable
EM_CACHE.  It omits test fixtures and does not download emsdk binaries.  Optional
HTML minification, wasm2c and downloaded ports are not provided by this Yoga
toolchain variant.")
    (license license:expat)))
