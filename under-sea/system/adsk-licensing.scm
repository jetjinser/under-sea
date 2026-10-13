;;; Minimal operating-system declaration that instantiates the under-sea
;;; Autodesk Licensing Service, so VM system tests can exercise it under a real
;;; init (Shepherd) without needing host privileges.

(define-module (under-sea system adsk-licensing)
  #:use-module (gnu)
  #:use-module (gnu system)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (under-sea services adsk-licensing)
  #:export (%under-sea-adsk-licensing-service
            %under-sea-adsk-licensing-os))

;; Satisfies the daemon's (networking) requirement without touching real
;; interfaces; safe inside a VM that shares the host network namespace.
(define %under-sea-adsk-networking
  (service static-networking-service-type
           (list (static-networking (addresses '())
                                    (routes '())
                                    (requirement '())
                                    (provision '(networking))))))

(define-public %under-sea-adsk-licensing-service
  (service adsk-licensing-service-type))

(define-public %under-sea-adsk-licensing-os
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
    (services (cons* %under-sea-adsk-licensing-service
                     %under-sea-adsk-networking
                     %base-services))))
