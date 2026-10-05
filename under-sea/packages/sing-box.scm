;;; Source-only sing-box package for the pinned channels.scm.
(define-module (under-sea packages sing-box)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages golang)
  #:use-module (under-sea packages sing-box-lock))

(define-public sing-box
  (package
    (name "sing-box")
    (version %sing-box-version)
    (source %sing-box-source)
    ;; Go modules are assembled into a local module proxy. Each archive and
    ;; metadata file is a separately hashed origin, fetched before the build.
    (build-system gnu-build-system)
    (native-inputs (list go-1.25))
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
              (setenv "CGO_ENABLED" "0")
              (setenv "GOPATH" (string-append (getcwd) "/gopath"))
              (setenv "GOCACHE" (string-append (getcwd) "/go-cache"))
              (setenv "GOMODCACHE" (string-append (getcwd) "/go-modules"))))
          (replace 'build
            (lambda* (#:key parallel-build? #:allow-other-keys)
              (invoke "go" "build" "-mod=readonly" "-buildvcs=false" "-trimpath"
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
            (lambda _
              (install-file "sing-box" (string-append #$output "/bin"))
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
source, with NaiveProxy and Tailscale disabled to avoid their precompiled
library and web-client dependencies.")
    (license license:gpl3+)))
