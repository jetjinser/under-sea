;;; Source-built / prebuilt providers for the camofox-browser Node closure.
(define-module (under-sea packages camofox-node-providers)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system node)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages node)
  #:use-module (gnu packages node-xyz)
  #:use-module (gnu packages python))

;; camofox-browser's camoufox-js dependency pulls impit, whose Linux addon is
;; only published prebuilt.  Install the upstream .node verbatim (recorded
;; exception) and give it a store rpath so Node can dlopen it.
(define-public impit-linux-x64-gnu-for-hermes
  (package
    (name "impit-linux-x64-gnu-for-hermes")
    (version "0.14.3")
    (source
     (origin
       (method url-fetch)
       (uri "https://registry.npmjs.org/impit-linux-x64-gnu/-/impit-linux-x64-gnu-0.14.3.tgz")
       (sha256
        (base16-string->bytevector
         "f551b4bad339a8c80e4f1e721437ca00ea48e5db1f602741986483bbe7b92681"))))
    (build-system gnu-build-system)
    (native-inputs (list tar patchelf))
    (inputs (list (list gcc "lib")))
    (arguments
     (list
      #:substitutable? #f
      #:validate-runpath? #f
      #:modules '((guix build gnu-build-system) (guix build utils))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'build)
          (delete 'check)
          (replace 'unpack
            (lambda _ (invoke "tar" "xf" #$source)))
          (replace 'install
            (lambda _
              (let ((dir (string-append #$output
                                        "/lib/node_modules/impit-linux-x64-gnu")))
                (mkdir-p dir)
                (copy-recursively "package" dir)
                (invoke "patchelf" "--set-rpath"
                        (string-append #$(file-append glibc "/lib") ":"
                                       (assoc-ref %build-inputs "gcc") "/lib")
                        (string-append dir "/impit-node.linux-x64-gnu.node"))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://www.npmjs.com/package/impit")
    (synopsis "impit Linux addon for camofox-browser (prebuilt exception)")
    (description "This package installs impit's upstream prebuilt Linux Node
addon (only distributed prebuilt) with a store rpath.")
    (license license:expat)))

;; better-sqlite3 has no published Linux prebuild for this release, so it is
;; built from its bundled source with node-gyp.
(define-public node-better-sqlite3-for-hermes
  (package
    (name "node-better-sqlite3-for-hermes")
    (version "13.0.1")
    (source
     (origin
       (method url-fetch)
       (uri "https://registry.npmjs.org/better-sqlite3/-/better-sqlite3-13.0.1.tgz")
       (sha256
        (base16-string->bytevector
         "92935ff8280f933aff78f87e04eb718a21af003aec4e5bd0076f287aa1709da4"))))
    (build-system node-build-system)
    (native-inputs (list python patchelf))
    (inputs (list node node-addon-api (list gcc "lib")))
    (arguments
     (list
      #:tests? #f
      #:modules '((guix build node-build-system) (guix build utils)
                  (ice-9 match) (srfi srfi-1))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'patch-dependencies 'delete-dependencies
            (lambda args
              (modify-json
               (delete-dependencies
                '("chai" "cli-color" "fs-extra" "mocha" "node-gyp"
                  "nodemark" "sqlite" "sqlite3")))))
          (add-after 'configure 'build-addon
            (lambda* (#:key inputs #:allow-other-keys)
              ;; Build the native addon directly from the bundled sqlite3
              ;; amalgamation using npm's bundled node-gyp and the store's
              ;; Node headers.
              (setenv "npm_config_nodedir" (assoc-ref inputs "node"))
              (setenv "CC" "gcc")
              (setenv "CXX" "g++")
              (invoke "node"
                      #$(file-append node "/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js")
                      "rebuild" "--release" "--force_build=1")))
          (add-after 'install 'install-built-addon
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (module (string-append out "/lib/node_modules/better-sqlite3"))
                     (built (car (find-files "build/Release" "\\.node$")))
                     (target (string-append module "/build/Release/better_sqlite3.node")))
                (mkdir-p (string-append module "/build/Release"))
                (install-file built (string-append module "/build/Release"))
                ;; Drop the bundled foreign prebuilds; use the addon we built.
                (delete-file-recursively (string-append module "/prebuilds"))
                (chmod target #o755)
                (invoke "patchelf" "--set-rpath"
                        (string-append #$(file-append glibc "/lib") ":"
                                       (assoc-ref inputs "gcc") "/lib")
                        target)))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/WiseLibs/better-sqlite3")
    (synopsis "better-sqlite3 built from source for camofox-browser")
    (description "This package builds the better-sqlite3 Node addon from its
bundled sqlite3 amalgamation with node-gyp.")
    (license license:expat)))
