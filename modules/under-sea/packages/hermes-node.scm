;;; Native Node build tools at the exact Hermes lock versions.
(define-module (under-sea packages hermes-node)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (under-sea gexp)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages web)
  #:use-module (gnu packages node)
  #:use-module (gnu packages python)
  #:use-module (srfi srfi-1)
  #:use-module (under-sea packages hermes)
  #:use-module (under-sea packages hermes-lock)
  #:use-module (under-sea packages hermes-node-lock)
  #:use-module (under-sea packages hermes-node-native)
  #:use-module ((under-sea packages hermes-esbuild) #:prefix hermes-esbuild:)
  #:use-module (under-sea packages hermes-browser-wasm))

;; Preserve the historical package binding for downstream Hermes components.
(define-public esbuild-for-hermes hermes-esbuild:esbuild-for-hermes)

(define %hermes-three-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/mrdoob/three.js/tar.gz/refs/tags/r180")
    (file-name "three-r180-source.tar.gz")
    (sha256 (base16-string->bytevector
             "a0a5b7d6cb439e93b17a03fc8300118bf9827cff3fa352fb22730a73c9cde76b"))))

(define-public hermes-node-tui
  (package
    (inherit hermes-agent-interfaces)
    (name "hermes-node-tui")
    (source %hermes-source)
    (build-system gnu-build-system)
    (native-inputs (list node python-minimal esbuild-for-hermes))
    (inputs (list node hermes-agent-interfaces oniguruma-wasm-for-hermes-shiki))
    (arguments
     (list
      #:substitutable? #f
      #:modules '((guix build gnu-build-system) (guix build utils) (ice-9 match))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          (add-before 'build 'prepare-node-sources
            (lambda _
              (call-with-output-file "node-sources.tsv"
                (lambda (port)
                  (for-each
                   (match-lambda
                     ((path version source) (format port "~a\t~a~%" path source)))
                   '#$%hermes-node-sources)))
              (setenv "ESBUILD_BINARY_PATH" #$(file-append esbuild-for-hermes "/bin/esbuild"))))
          (replace 'build
            (lambda _
              (invoke "python3" #$(under-sea-script "build-hermes-node.py")
                      "--oniguruma-wasm"
                      #$(file-append oniguruma-wasm-for-hermes-shiki
                                     "/share/oniguruma-wasm/onig.wasm")
                      "--shiki-wasm-audit"
                      #$(under-sea-repo-file "planning/hermes-shiki-inline-wasm-audit.json"))))
          (replace 'install
            (lambda _
              (let ((share (string-append #$output "/share/hermes-node-tui"))
                    (bin (string-append #$output "/bin")))
                (mkdir-p share)
                (mkdir-p bin)
                (install-file "ui-tui/dist/entry.js" share)
                (install-file "hermes-shiki-wasm-source-replacements.json" share)
                (install-file "LICENSE" (string-append share "/doc"))
                (call-with-output-file (string-append bin "/hermes-tui")
                  (lambda (port)
                    (format port "#!~a\nexport HERMES_PYTHON=~s\nexport HERMES_PYTHON_SRC_ROOT=~s\nexec ~s ~s \"$@\"\n"
                            (which "sh")
                            #$(file-append hermes-agent-interfaces "/bin/hermes-python")
                            #$(file-append hermes-agent-interfaces "/lib/python3.12/site-packages")
                            #$(file-append node "/bin/node")
                            (string-append share "/entry.js"))))
                (chmod (string-append bin "/hermes-tui") #o755)))))))
    (synopsis "Source-built Node terminal interface for Hermes")
    (description "This package bundles the Hermes terminal interface and its
local Ink sources using a source-built esbuild executable.  The Python gateway
uses the matching Guix Hermes interface runtime; npm installation scripts and
downloads are not executed.")))

(define-public hermes-web-assets
  (package
    (inherit hermes-node-tui)
    (name "hermes-web-assets")
    (inputs (list oniguruma-wasm-for-hermes-shiki))
    (arguments
     (list #:substitutable? #f
           #:modules '((guix build gnu-build-system) (guix build utils) (ice-9 match))
           #:phases
        #~(modify-phases %standard-phases
            (delete 'bootstrap)
            (delete 'configure)
            (delete 'check)
            (add-before 'build 'prepare-node-sources
              (lambda _
                (call-with-output-file "node-sources.tsv"
                  (lambda (port)
                    (for-each
                     (match-lambda ((path version source)
                                    (format port "~a\t~a~%" path source)))
                     '#$%hermes-node-sources)))
                (setenv "ESBUILD_BINARY_PATH"
                        #$(file-append esbuild-for-hermes "/bin/esbuild"))))
            (replace 'build
              (lambda _
                (call-with-output-file "native-components.tsv"
                  (lambda (port)
                    (format port "@rolldown/binding-linux-x64-gnu\t1.2.1\t~a~%" #$rolldown-for-hermes)
                    (format port "@tailwindcss/oxide-linux-x64-gnu\t4.3.3\t~a~%" #$tailwind-oxide-for-hermes)
                    (format port "lightningcss-linux-x64-gnu\t1.32.0\t~a~%" #$lightningcss-for-hermes)))
                (invoke "python3" #$(under-sea-script "build-hermes-node.py")
                        "--target" "web" "--native-components" "native-components.tsv"
                        "--oniguruma-wasm"
                        #$(file-append oniguruma-wasm-for-hermes-shiki
                                       "/share/oniguruma-wasm/onig.wasm")
                        "--shiki-wasm-audit"
                        #$(under-sea-repo-file "planning/hermes-shiki-inline-wasm-audit.json")
                        "--three-source" #$%hermes-three-source
                        "--three-builder" #$(under-sea-script "build-hermes-three.mjs"))))
            (replace 'install
              (lambda _
                (unless (file-exists? "hermes_cli/web_dist/index.html")
                  (error "Missing compiled Hermes dashboard entry"))
                (copy-recursively "hermes_cli/web_dist"
                                  (string-append #$output "/share/hermes-web"))
                (install-file "hermes-shiki-wasm-source-replacements.json"
                              (string-append #$output "/share/hermes-web"))
                (install-file "LICENSE"
                              (string-append #$output "/share/doc/hermes-web-assets")))))))
    (synopsis "Source-built static web dashboard assets for Hermes")
    (description "This package builds Hermes's web dashboard with locked Node
sources and source-built native CSS and bundler components.  The Python backend
and its static asset discovery are integrated separately.")))

(define-public hermes-dashboard
  (package
    (inherit hermes-web-assets)
    (name "hermes-dashboard")
    (source #f)
    (native-inputs '())
    (inputs (list hermes-agent-integrations hermes-web-assets))
    (arguments
     (list #:substitutable? #f
           #:phases
           #~(modify-phases %standard-phases
               (delete 'unpack)
               (delete 'bootstrap)
               (delete 'configure)
               (delete 'build)
               (delete 'check)
               (replace 'install
                 (lambda _
                   (let ((bin (string-append #$output "/bin"))
                         (assets #$(file-append hermes-web-assets "/share/hermes-web")))
                     (unless (file-exists? (string-append assets "/index.html"))
                       (error "Dashboard assets lack index.html"))
                     (mkdir-p bin)
                     (call-with-output-file (string-append bin "/hermes-dashboard")
                       (lambda (port)
                         (format port "#!~a\nexport HERMES_WEB_DIST=~s\nexec ~s dashboard \"$@\"\n"
                                 (which "sh") assets
                                 #$(file-append hermes-agent-integrations "/bin/hermes"))))
                     (chmod (string-append bin "/hermes-dashboard") #o755)))))))
    (synopsis "Hermes dashboard with its source-built frontend and Python backend")
    (description "This package provides a dashboard launcher combining the
Hermes integration runtime and its source-built static frontend.  It sets the
upstream HERMES_WEB_DIST resource path so startup uses the installed assets
without invoking npm or rebuilding the frontend in the immutable store.")))

(define-public node-pty-for-hermes
  (package
    (inherit esbuild-for-hermes)
    (name "node-pty-for-hermes")
    (version "1.1.0")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/microsoft/node-pty/tar.gz/refs/tags/v1.1.0")
       (file-name "node-pty-1.1.0.tar.gz")
       (sha256 (base16-string->bytevector
                "22351cf7fc9fbc3d87863a47d95810d696af25b354e6a65ed44846e4f47a847d"))))
    (build-system gnu-build-system)
    (native-inputs (list node esbuild-for-hermes))
    (inputs (list node))
    (arguments
     (list
      #:substitutable? #f
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
                                       (string=? (car entry) "node_modules/node-addon-api"))
                                     %hermes-node-sources))
                      "-C" "addon-source")
              (mkdir-p "build/Release")
              ;; Same Linux target, exception policy and hardening as binding.gyp.
              (invoke "g++" "-std=c++17" "-shared" "-fPIC" "-Wall" "-O2"
                      "-D_FORTIFY_SOURCE=2" "-DNAPI_CPP_EXCEPTIONS"
                      "-DNODE_GYP_MODULE_NAME=pty"
                      (string-append "-I" #$(file-append node "/include/node"))
                      "-Iaddon-source/package" "src/unix/pty.cc"
                      "-o" "build/Release/pty.node" "-lutil")
              (apply invoke
                     (append '("esbuild") (find-files "src" "\\.ts$")
                             '("--outdir=lib" "--outbase=src" "--platform=node"
                               "--format=cjs" "--target=node24")))))
          (replace 'install
            (lambda _
              (let ((directory (string-append #$output "/lib/node_modules/node-pty")))
                (mkdir-p directory)
                (copy-recursively "lib" (string-append directory "/lib"))
                (copy-recursively "build/Release" (string-append directory "/build/Release"))
                (copy-recursively "typings" (string-append directory "/typings"))
                (install-file "package.json" directory)
                (install-file "LICENSE" directory)))))))
    (synopsis "Source-built pseudoterminal binding for Hermes desktop")
    (description "This package builds node-pty's Unix C++ binding using Guix
Node headers and the locked node-addon-api headers.  Its TypeScript sources
are compiled locally; npm prebuild download scripts are not executed.")))
