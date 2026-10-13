;;; Source-only sing-box package for the pinned channels.scm.
(define-module (under-sea packages sing-box)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages golang)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages base)
  #:use-module (gnu packages elf)
  #:use-module (under-sea packages sing-box-lock))

(define-public sing-box
  (package
    (name "sing-box")
    (version %sing-box-version)
    (source %sing-box-source)
    ;; Go modules are assembled into a local module proxy. Each archive and
    ;; metadata file is a separately hashed origin, fetched before the build.
    (build-system gnu-build-system)
    (native-inputs (list go-1.25 gcc patchelf))
    (inputs (list glibc (list gcc "lib")))
    (arguments
     (list
      #:substitutable? #f
      #:modules '((guix build gnu-build-system)
                  (guix build utils)
                  (ice-9 match)
                  (srfi srfi-1)
                  (srfi srfi-13))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (add-before 'build 'prepare-go
            (lambda _
              (let ((proxy (string-append (getcwd) "/module-proxy")))
                (for-each
                 (match-lambda
                   ((relative source)
                    (let ((destination (string-append proxy "/" relative)))
                      (mkdir-p (dirname destination))
                      (copy-file source destination))))
                 '#$%sing-box-module-files)
                (setenv "GOPROXY" (string-append "file://" proxy)))
              (setenv "GOSUMDB" "off")
              (setenv "GOTOOLCHAIN" "local")
              (setenv "GOWORK" "off")
              ;; NaiveProxy (cronet-go) and Tailscale need cgo; the prebuilt
              ;; cronet library ships inside its hash-pinned Go module.
              (setenv "CGO_ENABLED" "1")
              (setenv "CC" "gcc")
              (setenv "CXX" "g++")
              (setenv "GOPATH" (string-append (getcwd) "/gopath"))
              (setenv "GOCACHE" (string-append (getcwd) "/go-cache"))
              (setenv "GOMODCACHE" (string-append (getcwd) "/go-modules"))))
          (replace 'build
            (lambda* (#:key parallel-build? #:allow-other-keys)
              (invoke "go" "build" "-mod=readonly" "-buildvcs=false"
                      "-p" (if parallel-build?
                               (number->string (parallel-job-count)) "1")
                      (string-append "-tags="
                                     (string-join '#$%sing-box-tags ","))
                      (string-append
                       "-ldflags="
                       (string-join '#$%sing-box-ldflags " ")
                       " -X github.com/sagernet/sing-box/constant.Version="
                       #$version " -buildid=")
                      "-o" "sing-box" "./cmd/sing-box")))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                ;; Network/privileged integration tests are unsuitable for a
                ;; Guix build container. Exercise the installed CLI's parser.
                (invoke "./sing-box" "version")
                (call-with-output-file "smoke.json"
                  (lambda (port)
                    (display "{\"outbounds\":[{\"type\":\"direct\"}]}" port)))
                (invoke "./sing-box" "check" "-c" "smoke.json")
                (call-with-output-file "invalid.json"
                  (lambda (port)
                    (display "{\"outbounds\":[{\"type\":\"invalid-protocol\"}]}"
                             port)))
                (when (zero? (system* "./sing-box" "check" "-c" "invalid.json"))
                  (error "sing-box accepted an invalid outbound protocol")))))
          (replace 'install
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((bin (string-append #$output "/bin")))
                (install-file "sing-box" bin)
                ;; The purego NaiveProxy binding dlopens libcronet.so from the
                ;; executable's own directory; ship the hash-pinned prebuilt lib
                ;; from the locked module next to the binary and point its
                ;; runpath at the Guix glibc/libgcc it needs.
                (install-file
                 (car (find-files "go-modules/github.com/sagernet/cronet-go"
                                  "^libcronet\\.so$"))
                 bin)
                (make-file-writable (string-append bin "/libcronet.so"))
                (invoke "patchelf" "--set-rpath"
                        (string-append
                         (dirname (search-input-file inputs "lib/libc.so.6")) ":"
                         (dirname (search-input-file inputs "lib/libgcc_s.so.1")))
                        (string-append bin "/libcronet.so")))
              (install-file "LICENSE" (string-append #$output
                                                       "/share/doc/sing-box"))
              (for-each
               (match-lambda
                 ((extension directory name)
                  (let ((source (string-append "release/completions/sing-box."
                                               extension))
                        (target (string-append #$output "/share/" directory)))
                    (mkdir-p target)
                    (copy-file source (string-append target "/" name)))))
               '(("bash" "bash-completion/completions" "sing-box")
                 ("fish" "fish/vendor_completions.d" "sing-box.fish")
                 ("zsh" "zsh/site-functions" "_sing-box"))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://sing-box.sagernet.org/")
    (synopsis "Universal proxy platform")
    (description
     "Sing-box provides proxy protocols, DNS transports, routing and TUN
networking.  This package builds the executable and its Go dependencies from
source with the full upstream default tag set, including NaiveProxy (via
cronet-go's purego binding and a hash-pinned prebuilt libcronet.so) and
Tailscale.")
    (license license:gpl3+)))
