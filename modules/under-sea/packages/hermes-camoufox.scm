;;; Camoufox (stealth Firefox fork) browser for Hermes (prebuilt exception).
(define-module (under-sea packages hermes-camoufox)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system trivial)
  #:use-module (gnu packages python)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages base)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages linux)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-13)
  #:use-module (under-sea packages hermes)
  #:use-module (under-sea packages hermes-browser-components)
  #:use-module ((under-sea packages hermes-camoufox-lock) #:prefix camoufox:))

;; Firefox links against the system GTK3 stack.  Its launcher finds the
;; bundled libraries through $ORIGIN; the GTK3 closure is supplied through
;; LD_LIBRARY_PATH by the wrapper below.
(define-public camoufox-gtk-libs
  (cons* (file-append gtk+ "/lib")
         (file-append alsa-lib "/lib")
         (filter-map (match-lambda
                       ((_ package) (file-append package "/lib"))
                       ((_ package _) (file-append package "/lib")))
                     (package-transitive-inputs gtk+))))

(define-public camoufox-browser-for-hermes
  (package
    (name "camoufox-browser-for-hermes")
    (version "156.0.1-beta.36")
    (source
     (origin
       (method url-fetch/zipbomb)
       (uri (string-append
             "https://github.com/daijro/camoufox/releases/download/v"
             version "/camoufox-" version "-lin.x86_64.zip"))
       (sha256
        (base16-string->bytevector
         "72637885ee67c93466ad377831c647192f8f08fb5c6fd9279de1320b49dd2b53"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (inputs (list (list "gtk+" gtk+)
                  (list "bash-minimal" bash-minimal)
                  (list "gcc:lib" gcc "lib")))
    (arguments
     (list
      #:substitutable? #f
      ;; The upstream Firefox fork ships its own bundled runtime and rpaths;
      ;; it is a prebuilt-only distribution (recorded exception).
      #:validate-runpath? #f
      #:modules '((guix build gnu-build-system) (guix build utils))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'build)
          (delete 'check)
          (replace 'install
            (lambda _
              (let ((directory (string-append #$output "/lib/camoufox")))
                (mkdir-p directory)
                (copy-recursively "." directory))))
          ;; Firefox's launchers target /lib64; point them at the store
          ;; loader (their $ORIGIN rpath already finds the bundled libs).
          (add-after 'install 'patch-interpreter
            (lambda _
              (for-each
               (lambda (name)
                 (let ((binary (string-append #$output "/lib/camoufox/" name)))
                   (chmod binary #o755)
                   (invoke "patchelf" "--set-interpreter"
                           #$(file-append glibc "/lib/ld-linux-x86-64.so.2")
                           binary)))
               '("camoufox" "camoufox-bin"))))
          ;; camoufox-js (used by camofox-browser) requires version.json in the
          ;; bundle; the release archive omits it.
          (add-after 'patch-interpreter 'write-version
            (lambda _
              (call-with-output-file
                  (string-append #$output "/lib/camoufox/version.json")
                (lambda (port)
                  (display "{\"version\":\"156.0.1\",\"release\":\"beta.36\"}\n"
                           port)))))
          (add-after 'patch-interpreter 'install-wrapper
            (lambda* (#:key inputs #:allow-other-keys)
              (let* ((bin (string-append #$output "/bin"))
                     (gcc-lib
                      (dirname (search-input-file inputs
                                                  "lib/libstdc++.so.6"))))
                (mkdir-p bin)
                (copy-file (string-append #$output
                                          "/lib/camoufox/properties.json")
                           (string-append bin "/properties.json"))
                (symlink (string-append #$output "/lib/camoufox/fontconfig")
                         (string-append bin "/fontconfig"))
                (symlink (string-append #$output "/lib/camoufox/fonts")
                         (string-append bin "/fonts"))
                (let ((wrapper (string-append bin "/camoufox")))
                  (call-with-output-file wrapper
                    (lambda (port)
                      (format port
                              "#!~a/bin/bash~%export LD_LIBRARY_PATH=~a:~a~%export MOZ_ENABLE_WAYLAND=0~%export GDK_BACKEND=x11~%exec ~a/bin/camoufox \"$@\"~%"
                              #$(file-append bash-minimal "/bin/bash")
                              (string-join (list #$@camoufox-gtk-libs) ":")
                              gcc-lib
                              #$output)))
                  (chmod wrapper #o555))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://camoufox.com/")
    (synopsis "Camoufox stealth browser for Hermes (prebuilt Firefox fork)")
    (description "This package deploys the prebuilt Camoufox browser (an
anti-detection Firefox fork) used by the Hermes computer-use backend.  The
browser is only distributed prebuilt, so it is recorded as a source-unavailable
exception; the Python controller is packaged separately.")
    (license license:mpl2.0)))

;; Camoufox's Python controller.  playwright and ua-parser-builtins are
;; wheel-only upstream and are injected as source-built wheel components.
(define-public hermes-agent-camoufox
  (let ((base (make-hermes-package "hermes-agent-camoufox"
                                   camoufox:%hermes-python-sources
                                   camoufox:%hermes-crate-sources #t '()
                                   (resolve-hermes-python-components
                                    camoufox:%hermes-python-component-requirements)
                                   #:smoke? #t #:smoke-script? #f
                                   #:smoke-modules '("camoufox" "maxminddb"))))
    (package
      (inherit base)
      (inputs (modify-inputs (package-inputs base)
                (append fpgen-model-for-hermes)))
      (arguments
       (substitute-keyword-arguments (package-arguments base)
         ((#:phases phases)
          #~(modify-phases #$phases
              (add-after 'install 'install-fpgen-model
                (lambda _
                  (let ((dir (string-append #$output
                                            "/lib/python3.12/site-packages/fpgen/data")))
                    (copy-recursively
                     #$(file-append fpgen-model-for-hermes "/share/fpgen-model")
                     dir)
                    ;; fpgen re-stamps files whose mtime is not already the
                    ;; pinned future time; the store is read-only, so set it.
                    (for-each
                     (lambda (f) (utime (string-append dir "/" f) 4102444800 4102444800))
                     '("fingerprint-network.json.zst" "values.dat.zst"
                       "values.json.zst" ".pinned-model")))))
              (add-after 'install 'remove-unused-cli
                (lambda _
                  ;; This is a specialised runtime invoked as
                  ;; `hermes-python -m camoufox`; the general agent CLI is not
                  ;; part of its supported interface (its closure omits many of
                  ;; the CLI's dependencies).
                  (for-each (lambda (name)
                              (let ((path (string-append #$output "/bin/" name)))
                                (when (file-exists? path) (delete-file path))))
                            '("hermes" "hermes-agent" "hermes-acp"))))
              ;; fpgen and Camoufox otherwise write the model into their own
              ;; (read-only) package directory.  Honour CAMOUFOX_FPGEN_DATA so
              ;; the wrapper can point them at a writable per-run directory.
              (add-after 'install-fpgen-model 'patch-fpgen-data-dir
                (lambda _
                  (substitute*
                      (string-append #$output
                                     "/lib/python3.12/site-packages/fpgen/pkgman.py")
                    (("DATA_DIR = Path\\(__file__\\).parent / 'data'")
                     "DATA_DIR = Path(os.environ.get('CAMOUFOX_FPGEN_DATA') or (Path(__file__).parent / 'data'))"))
                  (substitute*
                      (string-append #$output
                                     "/lib/python3.12/site-packages/camoufox/fpgen_model.py")
                    (("return Path\\(spec.origin\\).parent / 'data'")
                     "return Path(os.environ.get('CAMOUFOX_FPGEN_DATA') or (Path(spec.origin).parent / 'data'))")))))))))))

(define-public hermes-browser-backend-camoufox
  (package
    (name "hermes-browser-backend-camoufox")
    (version camoufox:%camoufox-version)
    (source #f)
    (build-system trivial-build-system)
    (inputs (list bash-minimal
                  hermes-agent-camoufox
                  camoufox-browser-for-hermes
                  (list gcc "lib")))
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let ((out (assoc-ref %outputs "out"))
                (rt (assoc-ref %build-inputs "hermes-agent-camoufox"))
                (bash (assoc-ref %build-inputs "bash-minimal"))
                (browser (assoc-ref %build-inputs "camoufox-browser-for-hermes"))
                (gcc-lib (assoc-ref %build-inputs "gcc")))
            (mkdir-p (string-append out "/share/hermes-browser"))
            (call-with-output-file
                (string-append out "/share/hermes-browser/camoufox.json")
              (lambda (port)
                (format port "{\"module\":\"camoufox\",\"browser\":~s,\"python\":~s,\"runtime\":~s}~%"
                        (string-append browser "/lib/camoufox/camoufox")
                        (string-append rt "/bin/hermes-python")
                        rt)))
            (mkdir-p (string-append out "/bin"))
            (let ((wrapper (string-append out "/bin/hermes-camoufox")))
              (call-with-output-file wrapper
                (lambda (port)
                  (display
                   (string-append
                    "#!" bash "/bin/bash\n"
                    "export LD_LIBRARY_PATH="
                    (string-join (append (list #$@camoufox-gtk-libs)
                                         (list (string-append gcc-lib "/lib")))
                                 ":")
                    "${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}\n"
                    "export CAMOUFOX_EXECUTABLE_PATH=" browser "/lib/camoufox/camoufox\n"
                    "site=" rt "/lib/python3.12/site-packages\n"
                    ;; fpgen writes its model into its package directory; the
                    ;; store is read-only, so run from a writable per-run
                    ;; directory whose model files are dated past fpgen's
                    ;; refresh window (no runtime download).
                    "export CAMOUFOX_FPGEN_DATA=$(mktemp -d)\n"
                    "cp -r \"$site/fpgen/data/.\" \"$CAMOUFOX_FPGEN_DATA/\"\n"
                    "chmod -R u+w \"$CAMOUFOX_FPGEN_DATA\"\n"
                    "touch -d @4102444800 \"$CAMOUFOX_FPGEN_DATA\"/*\n"
                    "exec " rt "/bin/hermes-python -m camoufox \"$@\"\n")
                   port)))
              (chmod wrapper #o555))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://camoufox.com/")
    (synopsis "Camoufox browser backend for the Hermes agent")
    (description "This package builds the Camoufox Python controller (and its
locked dependency closure, including the wheel-only playwright and
ua-parser-builtins exceptions) from source and points it at the prebuilt
Camoufox browser package via CAMOUFOX_EXECUTABLE_PATH.")
    (license license:mpl2.0)))
