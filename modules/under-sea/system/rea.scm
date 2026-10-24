;;; Minimal operating-system declaration for the REA real-system smoke test.
;;; REA is a CLI/MCP stdio program rather than a daemon, so it is installed in
;;; the system profile and exercised by (under-sea tests rea) instead of being
;;; wrapped in a shepherd service.

(define-module (under-sea system rea)
  #:use-module (gnu)
  #:use-module (gnu system)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (under-sea packages rea)
  #:export (%under-sea-rea-os))

(define-public %under-sea-rea-os
  (operating-system
    (host-name "under-sea")
    (timezone "UTC")
    (locale "en_US.utf8")
    (bootloader (bootloader-configuration
                 (bootloader grub-bootloader)
                 (targets '("/dev/sdX"))))
    (file-systems (cons (file-system
                          (device (file-system-label "under-sea-root"))
                          (mount-point "/")
                          (type "ext4"))
                        %base-file-systems))
    (users (cons (user-account
                  (name "tester")
                  (comment "under-sea test user")
                  (group "users")
                  (supplementary-groups '("wheel")))
                 %base-user-accounts))
    (packages (cons* rea %base-packages))
    (services %base-services)))
