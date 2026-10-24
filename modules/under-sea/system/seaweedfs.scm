;;; Minimal operating-system declaration that instantiates the under-sea
;;; SeaweedFS service, so container smoke tests and VM system tests can
;;; exercise it under a real init (Shepherd).  Installing the package alone
;;; does not start anything.

(define-module (under-sea system seaweedfs)
  #:use-module (gnu)
  #:use-module (gnu system)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu packages curl)
  #:use-module (under-sea packages seaweedfs)
  #:use-module (under-sea services seaweedfs)
  #:export (%under-sea-seaweedfs-service
            %under-sea-seaweedfs-cluster-service
            %under-sea-seaweedfs-networking
            %under-sea-seaweedfs-os
            %under-sea-seaweedfs-cluster-os))

;; The service depends on the "networking" shepherd provision, which
;; %base-services does not provide (it only brings up loopback).  Add an empty,
;; side-effect-free static-networking: it satisfies the requirement without
;; touching real interfaces.  `guix system container' replaces this with its
;; dummy networking service, so build the container with --network (as the
;; repository's other container smoke tests do).
(define %under-sea-seaweedfs-networking
  (service static-networking-service-type
           (list (static-networking (addresses '())
                                    (routes '())
                                    (requirement '())
                                    (provision '(networking))))))

(define %under-sea-seaweedfs-service
  (service seaweedfs-service-type))

(define %under-sea-seaweedfs-cluster-service
  (service seaweedfs-cluster-service-type))

(define %under-sea-base-os
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
    (packages (cons* seaweedfs curl %base-packages))
    (services (cons* %under-sea-seaweedfs-service
                     %under-sea-seaweedfs-networking
                     %base-services))))

(define-public %under-sea-seaweedfs-os %under-sea-base-os)

(define-public %under-sea-seaweedfs-cluster-os
  (operating-system
    (inherit %under-sea-base-os)
    (services (cons* %under-sea-seaweedfs-cluster-service
                     %under-sea-seaweedfs-networking
                     %base-services))))
