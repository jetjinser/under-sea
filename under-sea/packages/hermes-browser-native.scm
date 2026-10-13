;;; Native bindings matching the agent-browser dashboard's locked versions.
(define-module (under-sea packages hermes-browser-native)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages node)
  #:use-module (gnu packages pkg-config)
  #:use-module (srfi srfi-1)
  #:use-module (gnu packages image-processing)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (under-sea packages hermes-node-native)
  #:use-module (under-sea packages hermes-node-lock)
  #:use-module ((under-sea packages hermes-browser-native-lock) #:prefix browser:))

(define-public vips-for-hermes-browser
  (package
    (inherit vips)
    (name "vips-for-hermes-browser")
    (version "8.17.3")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/libvips/libvips/tar.gz/refs/tags/v8.17.3")
       (file-name "libvips-8.17.3-source.tar.gz")
       (sha256 (base16-string->bytevector
                "c1180d13f33742685c513ac42c0556dd1ce9e2b79cdb248a807576e2d8b63b32"))))))

(define-public tailwind-oxide-for-hermes-browser
  (native-binding "tailwind-oxide-for-hermes-browser" "4.2.2"
                  browser:%hermes-tailwind-source browser:%hermes-tailwind-crates
                  "tailwind-oxide" "libtailwind_oxide.so"
                  "@tailwindcss/oxide-linux-x64-gnu" license:expat))

(define-public sharp-binding-for-hermes-browser
  (package
    (name "sharp-binding-for-hermes-browser")
    (version "0.34.5")
    (source
     (origin
       (method url-fetch)
       (uri "https://registry.npmjs.org/sharp/-/sharp-0.34.5.tgz")
       (sha256 (base16-string->bytevector
                "460712506f9df808cf25bc2ba15be828bfa9179bd31b6ca47a9db624980026c3"))))
    (build-system gnu-build-system)
    (native-inputs (list node pkg-config))
    (inputs (list vips-for-hermes-browser))
    (arguments
     (list
      #:substitutable? #f
      #:modules '((guix build gnu-build-system) (guix build utils)
                  (ice-9 popen) (ice-9 rdelim) (srfi srfi-13))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          (replace 'build
            (lambda _
              (mkdir "addon-source")
              (invoke "tar" "xf"
                #$(caddr (find (lambda (entry)
                                (string=? (car entry)
                                  "node_modules/get-windows/node_modules/node-addon-api"))
                              %hermes-node-sources))
                "-C" "addon-source")
              (define (flags option)
                (let* ((port (open-pipe* OPEN_READ "pkg-config" option
                                         "vips-cpp" "vips" "glib-2.0"))
                       (text (read-string port)))
                  (unless (zero? (close-pipe port))
                    (error "Missing source-built libvips compiler flags"))
                  (string-tokenize text)))
              (apply invoke
                (append '("g++" "-shared" "-fPIC" "-std=c++17" "-fexceptions"
                          "-Wall" "-Os" "-DG_DISABLE_ASSERT" "-DG_DISABLE_CAST_CHECKS"
                          "-DG_DISABLE_CHECKS" "-DNAPI_VERSION=9"
                          "-DNODE_ADDON_API_DISABLE_DEPRECATED"
                          "-DNODE_API_SWALLOW_UNTHROWABLE_EXCEPTIONS"
                          "-DSHARP_USE_GLOBAL_LIBVIPS" "-Iaddon-source/package")
                        (list (string-append "-I" #$(file-append node "/include/node")))
                        (flags "--cflags")
                        '("src/common.cc" "src/metadata.cc" "src/stats.cc"
                          "src/operations.cc" "src/pipeline.cc" "src/utilities.cc"
                          "src/sharp.cc" "-o" "sharp.node")
                        (flags "--libs")))))
          (replace 'install
            (lambda _
              (let ((directory (string-append #$output
                                 "/lib/node_modules/@img/sharp-linux-x64")))
                (mkdir-p directory)
                (copy-file "sharp.node" (string-append directory "/sharp.node"))
                (install-file "LICENSE" directory)
                (call-with-output-file (string-append directory "/package.json")
                  (lambda (port)
                    (display "{\"name\":\"@img/sharp-linux-x64\",\"version\":\"0.34.5\",\"exports\":{\"./sharp.node\":\"./sharp.node\"}}\n" port)))
                ;; The upstream local-build path avoids the platform prebuild's
                ;; x64-v2 restriction for this generic x86_64 source binding.
                (let ((sharp (string-append #$output "/lib/node_modules/sharp")))
                  (mkdir-p (string-append sharp "/src/build/Release"))
                  (copy-recursively "lib" (string-append sharp "/lib"))
                  (install-file "package.json" sharp)
                  (install-file "LICENSE" sharp)
                  (copy-file "sharp.node"
                    (string-append sharp "/src/build/Release/sharp-linux-x64.node")))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/lovell/sharp")
    (synopsis "Source-built Sharp image processing Node binding")
    (description "This package compiles Sharp's Linux C++ binding against
Guix Node headers and source-built libvips.  It includes the matching JavaScript
sources and the upstream local-build layout; JavaScript dependencies are
supplied by the dashboard source lock.")
    (license license:asl2.0)))
