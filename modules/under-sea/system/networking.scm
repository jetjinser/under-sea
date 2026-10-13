;;; Minimal operating-system declarations that instantiate the under-sea
;;; networking shepherd services.  Installing the packages does not start any
;;; daemon; these declarations exist so container smoke tests and VM system
;;; tests can exercise the services in a real init/kernel environment.

(define-module (under-sea system networking)
  #:use-module (gnu)
  #:use-module (gnu system)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (guix gexp)
  #:use-module (under-sea packages dae)
  #:use-module (under-sea packages dae-data)
  #:use-module (under-sea packages sing-box)
  #:use-module (under-sea services networking)
  #:export (%under-sea-sing-box-config
            %under-sea-sing-box-service
            %under-sea-dae-config
            %under-sea-dae-assets
            %under-sea-dae-service
            %under-sea-networking-service
            %under-sea-sing-box-os
            %under-sea-networking-os))

;; A direct-outbound sing-box listening on loopback: valid with no privileges,
;; so it can run inside an unprivileged container as well as a VM guest.
(define-public %under-sea-sing-box-config
  (plain-file "sing-box.json"
              (string-append
               "{\n"
               "  \"log\": { \"level\": \"info\" },\n"
               "  \"inbounds\": [\n"
               "    { \"type\": \"mixed\", \"tag\": \"mixed-in\",\n"
               "      \"listen\": \"127.0.0.1\", \"listen_port\": 2080 }\n"
               "  ],\n"
               "  \"outbounds\": [ { \"type\": \"direct\", \"tag\": \"direct\" } ]\n"
               "}\n")))

;; dae's smallest accepted configuration (the same shape validated during its
;; build).  A real deployment adds routing rules and geographic assets.
(define-public %under-sea-dae-config
  (plain-file "config.dae"
              (string-append
               "global {\n"
               ;; Do not block startup on an internet reachability probe.
               " disable_waiting_network: true\n"
               "}\n"
               "routing {\n fallback: direct\n}\n")))

;; dae reads geoip.dat and geosite.dat from a single directory given by
;; DAE_LOCATION_ASSET, so union the two source-generated data packages.
(define-public %under-sea-dae-assets
  (file-union "dae-assets"
              `(("geoip.dat" ,(file-append dae-geoip "/share/dae/geoip.dat"))
                ("geosite.dat" ,(file-append dae-geosite "/share/dae/geosite.dat")))))

(define %under-sea-sing-box-service
  (service sing-box-service-type
           (sing-box-configuration (config-file %under-sea-sing-box-config))))

(define %under-sea-dae-service
  (service dae-service-type
           (dae-configuration (config-file %under-sea-dae-config)
                              (asset-directory %under-sea-dae-assets))))

;; The daemons depend on the "networking" shepherd provision, which %base-services
;; does not provide (it only brings up loopback).  Add an empty, side-effect-free
;; static-networking: it satisfies the requirement without touching real
;; interfaces, so it is safe inside an unprivileged container that shares the
;; host network namespace.
(define %under-sea-networking-service
  (service static-networking-service-type
           (list (static-networking (addresses '())
                                    (routes '())
                                    (requirement '())
                                    (provision '(networking))))))

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
    (services (cons* %under-sea-sing-box-service
                     %under-sea-networking-service
                     %base-services))))

(define-public %under-sea-sing-box-os %under-sea-base-os)

(define-public %under-sea-networking-os
  (operating-system
    (inherit %under-sea-base-os)
    (services (cons* %under-sea-dae-service
                     %under-sea-sing-box-service
                     %under-sea-networking-service
                     %base-services))))
