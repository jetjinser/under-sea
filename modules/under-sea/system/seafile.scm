;;; Minimal operating-system declaration that instantiates the under-sea
;;; Seafile client shepherd service, so container smoke tests and VM system
;;; tests can exercise it in a real init/kernel environment.  The daemon needs
;;; no network access to start, but it requires the "networking" shepherd
;;; provision, which a side-effect-free static-networking satisfies.
(define-module (under-sea system seafile)
  #:use-module (gnu)
  #:use-module (gnu system)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (guix gexp)
  #:use-module (under-sea packages seafile)
  #:use-module (under-sea services seafile)
  #:export (%under-sea-seafile-service
            %under-sea-seafile-os))

(define %under-sea-seafile-networking
  (service static-networking-service-type
           (list (static-networking (addresses '())
                                    (routes '())
                                    (requirement '())
                                    (provision '(networking))))))

(define %under-sea-seafile-service
  (service seafile-client-service-type))

(define-public %under-sea-seafile-os
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
    (packages (cons* seafile %base-packages))
    (services (cons* %under-sea-seafile-service
                     %under-sea-seafile-networking
                     %base-services))))
