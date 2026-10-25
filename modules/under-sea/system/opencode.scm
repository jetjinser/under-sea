;;; Minimal operating-system declaration for the OpenCode v1/v2 coexistence
;;; smoke test.

(define-module (under-sea system opencode)
  #:use-module (gnu)
  #:use-module (gnu system)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu packages curl)
  #:use-module (under-sea packages opencode-v1)
  #:use-module (under-sea packages opencode-v2)
  #:export (%under-sea-opencode-os))

(define-public %under-sea-opencode-os
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
    (packages (cons* opencode-v1 opencode-v2 curl %base-packages))
    (services %base-services)))
