;;; dae and its embedded eBPF programs, built entirely from source.
(define-module (under-sea packages dae)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages golang)
  #:use-module (gnu packages llvm)
  #:use-module (under-sea packages dae-lock))

(define-public dae
  (package
    (name "dae")
    (version %dae-version)
    (source %dae-source)
    (build-system gnu-build-system)
    (native-inputs (list go-1.26 clang-15 llvm-15))
    (arguments
     (list
      #:substitutable? #f
      #:modules '((guix build gnu-build-system)
                  (guix build utils)
                  (ice-9 match)
                  (srfi srfi-1))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (add-before 'build 'prepare-sources
            (lambda _
              (let ((proxy (string-append (getcwd) "/module-proxy")))
                (for-each
                 (match-lambda
                   ((relative source)
                    (let ((destination (string-append proxy "/" relative)))
                      (mkdir-p (dirname destination))
                      (copy-file source destination))))
                 '#$%dae-module-files)
                (setenv "GOPROXY" (string-append "file://" proxy)))
              (setenv "GOSUMDB" "off")
              (setenv "GOTOOLCHAIN" "local")
              (setenv "GOWORK" "off")
              (setenv "CGO_ENABLED" "0")
              (setenv "GOFLAGS" "-mod=readonly -buildvcs=false -trimpath")
              (setenv "GOEXPERIMENT" #$%dae-goexperiment)
              (setenv "GOPATH" (string-append (getcwd) "/gopath"))
              (setenv "GOCACHE" (string-append (getcwd) "/go-cache"))
              (setenv "GOMODCACHE" (string-append (getcwd) "/go-modules"))
              ;; Both submodules use the same commit. Extract the hash-pinned
              ;; source without invoking Git or accessing the network.
              (for-each
               (lambda (directory)
                 (mkdir-p directory)
                 (invoke "tar" "xf" #$%dae-headers
                         "--strip-components=1" "-C" directory))
               '("control/kern/headers" "trace/kern/headers"))
              ;; Generator directives must obey the same read-only module
              ;; policy as the final build rather than overriding GOFLAGS.
              (substitute* '("control/control.go" "trace/trace.go")
                (("-mod=mod") "-mod=readonly"))
              (invoke "make" "clean-ebpf")))
          (replace 'build
            (lambda* (#:key parallel-build? #:allow-other-keys)
              (setenv "GOFLAGS"
                      (string-append (getenv "GOFLAGS") " -p="
                                     (if parallel-build?
                                         (number->string (parallel-job-count))
                                         "1")))
              (setenv "BPF_CLANG" (which "clang"))
              (setenv "BPF_STRIP_FLAG"
                      (string-append "-strip=" (which "llvm-strip")))
              (setenv "BPF_CFLAGS" "-DMAX_MATCH_SET_LEN=1024 -O2 -Wall -Werror")
              (setenv "BPF_TARGET" "bpfel,bpfeb")
              (setenv "BPF_TRACE_TARGET" "amd64")
              ;; Use upstream generators, including the Go/C constant sync.
              ;; Generation failures are fatal: never ship an eBPF stub build.
              (invoke "go" "generate" "./common/consts/ebpf.go")
              (invoke "go" "generate" "./control/control.go")
              (invoke "go" "generate" "./trace/trace.go")
              (invoke "go" "build" "-tags=trace"
                      (string-append
                       "-ldflags=-s -w -buildid="
                       " -X github.com/daeuniverse/dae/cmd.Version=" #$version
                       " -X github.com/daeuniverse/dae/common/consts.MaxMatchSetLen_=1024")
                      "-o" "dae" ".")))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (invoke "go" "test" "-count=1" "./config"
                        "./pkg/config_parser" "./pkg/trie" "./common/consts")
                (invoke "./dae" "--version")
                (invoke "./dae" "trace" "--help")
                (call-with-output-file "smoke.dae"
                  (lambda (port)
                    (display "global {}\nrouting {\n fallback: direct\n}\n" port)))
                (chmod "smoke.dae" #o600)
                (invoke "./dae" "validate" "-c" "smoke.dae")
                (call-with-output-file "invalid.dae"
                  (lambda (port)
                    (display "global {}\nrouting {\n domainx(suffix: example.com) -> direct\n fallback: direct\n}\n"
                             port)))
                (chmod "invalid.dae" #o600)
                (when (zero? (system* "./dae" "validate" "-c" "invalid.dae"))
                  (error "dae accepted an invalid routing function")))))
          (replace 'install
            (lambda _
              (install-file "dae" (string-append #$output "/bin"))
              (for-each
               (lambda (file)
                 (install-file file (string-append #$output "/share/doc/dae")))
               '("LICENSE" "example.dae"))
              (for-each
               (match-lambda
                 ((shell directory name)
                  (let ((target (string-append #$output "/share/" directory)))
                    (mkdir-p target)
                    (with-output-to-file (string-append target "/" name)
                      (lambda () (invoke "./dae" "completion" shell))))))
               '(("bash" "bash-completion/completions" "dae")
                 ("fish" "fish/vendor_completions.d" "dae.fish")
                 ("zsh" "zsh/site-functions" "_dae"))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/daeuniverse/dae")
    (synopsis "Transparent proxy with eBPF traffic routing")
    (description
     "Dae provides transparent proxying and traffic routing using Linux eBPF
programs.  Direct traffic can bypass userspace forwarding.  This package
compiles the Go executable, the traffic-routing eBPF programs and the optional
trace diagnostics from their source code.")
    (license license:agpl3)))
