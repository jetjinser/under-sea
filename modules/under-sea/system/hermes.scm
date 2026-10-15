;;; Minimal operating-system declaration that instantiates the under-sea
;;; Hermes gateway service, so VM system tests can exercise it under a real
;;; init (Shepherd) without needing host privileges.

(define-module (under-sea system hermes)
  #:use-module (gnu)
  #:use-module (gnu system)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (under-sea packages hermes)
  #:use-module (under-sea services hermes)
  #:export (%under-sea-hermes-service
            %under-sea-hermes-os))

;; Satisfies the gateway's (networking) requirement without touching real
;; interfaces; safe inside a VM that shares the host network namespace.
(define %under-sea-hermes-networking
  (service static-networking-service-type
           (list (static-networking (addresses '())
                                    (routes '())
                                    (requirement '())
                                    (provision '(networking))))))

(define %under-sea-hermes-service
  (service hermes-service-type))

(define-public %under-sea-hermes-os
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
    (packages (cons* hermes-agent %base-packages))
    (services (cons* %under-sea-hermes-service
                     %under-sea-hermes-networking
                     %base-services))))
