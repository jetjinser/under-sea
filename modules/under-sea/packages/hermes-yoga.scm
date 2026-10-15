(define-module (under-sea packages hermes-yoga)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (under-sea gexp)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages python)
  #:use-module (under-sea packages hermes-node)
  #:use-module (under-sea packages hermes-emscripten-tools)
  #:use-module ((guix licenses) #:prefix license:))

(define %yoga-cpp-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/facebook/yoga/tar.gz/c09405d58c624fd26d5e0a7ed98bd10c5cc4c05b")
    (file-name "yoga-c09405d-source.tar.gz")
    (sha256
     (base16-string->bytevector
      "ba45196671d8c7ce92303f674bb9620375dfb047615f01865faa6c54c7baf1d3"))))

(define-public yoga-wasm-web-for-hermes-browser
  (package
    (name "yoga-wasm-web-for-hermes-browser")
    (version "0.3.3")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/shuding/yoga-wasm-web/tar.gz/964bd6b7c5f30f4d5cbb50ec7ea51afa429ce541")
       (file-name "yoga-wasm-web-0.3.3-source.tar.gz")
       (sha256
        (base16-string->bytevector
         "5fdc623005005e04d6b6c1da259ac4f01895b399058f269eeba1bbff87d8c9d6"))))
    (build-system gnu-build-system)
    (native-inputs (list python-minimal esbuild-for-hermes emscripten-for-hermes-yoga))
    (arguments
     (list
      #:substitutable? #f
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          (add-after 'unpack 'unpack-matching-yoga
            (lambda _
              (invoke "tar" "xf" #$%yoga-cpp-source "--strip-components=1" "-C" "yoga")))
          (replace 'build
            (lambda _
              (invoke "python3" #$(under-sea-script "build-hermes-yoga.py") #$output)))
          (replace 'install (lambda _ #t)))))
    (home-page "https://github.com/shuding/yoga-wasm-web")
    (synopsis "Source-built Yoga WASM and asm.js with complete module APIs")
    (description "This package builds Yoga's pinned C++ source with matching
Emscripten, including both upstream WASM and asm.js targets, Closure optimization
and the complete JavaScript wrappers and type declarations.  C/C++ system
libraries are generated from source in a private writable build cache.  No
precompiled npm WASM or emsdk binaries are used.")
    (license license:expat)))
