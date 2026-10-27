;;; A test-only QEMU wrapper that exposes an SSE4.2-capable CPU model.
;;; The wrapper execs the existing qemu-minimal binary, so it does not rebuild
;;; QEMU; it only changes the guest CPU model used by VM tests.

(define-module (under-sea packages qemu-cpu)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system trivial)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages virtualization)
  #:export (qemu-sse42))

(define-public qemu-sse42
  (package
    (name "qemu-sse42")
    (version (package-version qemu-minimal))
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let* ((out (assoc-ref %outputs "out"))
                 (bin (string-append out "/bin"))
                 (qemu (string-append (assoc-ref %build-inputs "qemu-minimal")
                                      "/bin/qemu-system-x86_64"))
                 (bash (string-append (assoc-ref %build-inputs "bash-minimal")
                                      "/bin/sh")))
            (mkdir-p bin)
            (call-with-output-file
                (string-append bin "/qemu-system-x86_64")
              (lambda (port)
                ;; Put -cpu last so it wins over any model supplied by the
                ;; caller; QEMU uses the last -cpu option.
                (format port "#!~a~%exec ~a \"$@\" -cpu max~%" bash qemu)))
            (chmod (string-append bin "/qemu-system-x86_64") #o555)))))
    (inputs (list qemu-minimal bash-minimal))
    (home-page "https://www.qemu.org")
    (synopsis "QEMU test wrapper with an SSE4.2-capable CPU model")
    (description "This test-only package wraps QEMU's x86_64 system emulator
and appends @code{-cpu max}, so guests expose SSE4.2 to binaries that require
it (for example Bun standalone builds).")
    (license license:gpl2)))
