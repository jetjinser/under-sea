;;; System tests for the under-sea networking shepherd services.  These boot a
;;; real VM (QEMU, under the daemon) and drive it with a marionette REPL, so
;;; they exercise the service definitions end to end rather than just building
;;; packages.

(define-module (under-sea tests networking)
  #:use-module (gnu tests)
  #:use-module (gnu packages linux)
  #:use-module (gnu system)
  #:use-module (gnu system file-systems)
  #:use-module (gnu system linux-initrd)
  #:use-module (gnu system vm)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (guix gexp)
  #:use-module (under-sea packages sing-box)
  #:use-module (under-sea system networking)
  #:export (%test-under-sea-sing-box
            %test-under-sea-dae))

;; A configuration sing-box must reject, used for the negative case.
(define %bad-sing-box-config
  (plain-file "bad-sing-box.json" "{ this is not valid json\n"))

;; QEMU user-mode networking gives the guest an eth0 with a default route,
;; which the daemons need to auto-detect the WAN interface.
(define (qemu-networking)
  (service static-networking-service-type (list %qemu-static-networking)))

(define (run-sing-box-test)
  (define os
    (marionette-operating-system
     (simple-operating-system (qemu-networking) %under-sea-sing-box-service)
     #:imported-modules '((gnu services herd)
                          (guix combinators))))
  (define vm
    (virtual-machine (operating-system os)))
  (define test
    (with-imported-modules '((gnu build marionette)
                             (guix build utils))
      #~(begin
          (use-modules (gnu build marionette)
                       (guix build utils)
                       (srfi srfi-64))

          (define marionette
            (make-marionette (list #$vm)))

          (test-runner-current (system-test-runner #$output))
          (test-begin "under-sea-sing-box")

          (test-assert "sing-box service can be started"
            (marionette-eval
             '(begin
                (use-modules (gnu services herd))
                (start-service 'sing-box))
             marionette))

          (test-assert "sing-box listens on 127.0.0.1:2080"
            ;; The service reports the listener in its log entry once bound.
            (let loop ((n 0))
              (if (marionette-eval
                   '(begin
                      (use-modules (ice-9 textual-ports))
                      (define (file-contains? file needle)
                        (and (file-exists? file)
                             (call-with-input-file file
                               (lambda (port)
                                 (string-contains (get-string-all port) needle)))))
                      (or (file-contains? "/var/log/sing-box.log"
                                          "tcp server started at 127.0.0.1:2080")
                          (file-contains? "/proc/net/tcp" "0100007F:0820")
                          (file-contains? "/proc/net/tcp6" "0100007F:0820")))
                   marionette)
                  #t
                  (if (>= n 20) #f (begin (usleep 250000) (loop (+ n 1)))))))

          (test-assert "sing-box state directory exists"
            (marionette-eval
             '(file-exists? "/var/lib/sing-box")
             marionette))

          (test-assert "sing-box rejects an invalid configuration"
            (marionette-eval
             '(not (zero? (system* #$(file-append sing-box "/bin/sing-box")
                                   "check" "-c" #$%bad-sing-box-config)))
             marionette))

          (test-end "under-sea-sing-box"))))
  (system-test
   (name "under-sea-sing-box")
   (description "Start sing-box through its shepherd service and verify it listens.")
   (value (gexp->derivation "under-sea-sing-box" test))))

(define (run-dae-test)
  (define base
    (simple-operating-system (qemu-networking)
                             %under-sea-dae-service
                             %under-sea-sing-box-service))
  (define os
    (marionette-operating-system
     (operating-system
       (inherit base)
       ;; dae opens /dev/net/tun (needs the tun module) and pins its eBPF
       ;; objects under /sys/fs/bpf (needs the bpf file system mounted).
       (initrd-modules (cons "tun" (base-initrd-modules linux-libre)))
       (file-systems
        (append (list (file-system
                        (type "bpf")
                        (mount-point "/sys/fs/bpf")
                        (device "none")
                        (create-mount-point? #t)))
                %base-file-systems)))
     #:imported-modules '((gnu services herd)
                          (guix combinators))))
  (define vm
    (virtual-machine (operating-system os)))
  (define test
    (with-imported-modules '((gnu build marionette)
                             (guix build utils))
      #~(begin
          (use-modules (gnu build marionette)
                       (guix build utils)
                       (srfi srfi-64))

          (define marionette
            (make-marionette (list #$vm)))

          (test-runner-current (system-test-runner #$output))
          (test-begin "under-sea-dae")

          (test-assert "dae service can be started"
            (marionette-eval
             '(begin
                (use-modules (gnu services herd))
                (start-service 'dae))
             marionette))

          (test-assert "dae loaded eBPF and built the control plane"
            (let loop ((n 0))
              (if (marionette-eval
                   '(begin
                      (use-modules (ice-9 textual-ports))
                      (define (log-has? needle)
                        (and (file-exists? "/var/log/dae.log")
                             (call-with-input-file "/var/log/dae.log"
                               (lambda (port)
                                 (string-contains (get-string-all port) needle)))))
                      (and (log-has? "Loaded eBPF programs and maps")
                           (log-has? "routing rules into kernel space")))
                   marionette)
                  #t
                  (if (>= n 40) #f (begin (usleep 250000) (loop (+ n 1)))))))

          (test-assert "dae created its datapath interfaces"
            ;; dae creates a veth (or netkit) pair inside its own namespace.
            (marionette-eval
             '(begin
                (use-modules (ice-9 textual-ports))
                (and (file-exists? "/var/log/dae.log")
                     (call-with-input-file "/var/log/dae.log"
                       (lambda (port)
                         (let ((log (get-string-all port)))
                           (or (string-contains log "Created veth device pair")
                               (string-contains log "Created Netkit device")))))))
             marionette))

          (test-end "under-sea-dae"))))
  (system-test
   (name "under-sea-dae")
   (description "Start dae (eBPF/TUN) through its shepherd service and verify it.")
   (value (gexp->derivation "under-sea-dae" test))))

(define %test-under-sea-sing-box (run-sing-box-test))
(define %test-under-sea-dae (run-dae-test))
