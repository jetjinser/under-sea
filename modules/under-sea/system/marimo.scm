;;; Minimal operating-system declaration that instantiates the under-sea
;;; marimo service, so VM system tests and container smoke tests can exercise
;;; it under a real init without host privileges.

(define-module (under-sea system marimo)
  #:use-module (gnu)
  #:use-module (gnu system)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu packages curl)
  #:use-module (guix gexp)
  #:use-module (under-sea packages marimo)
  #:use-module (under-sea services marimo)
  #:export (%under-sea-marimo-notebook
            %under-sea-marimo-token
            %under-sea-marimo-service
            %under-sea-marimo-os
            %under-sea-marimo-auth-os))

;; A minimal but valid marimo notebook.  The app title is a distinctive
;; marker that the HTTP system test can look for in the served page.
(define-public %under-sea-marimo-notebook
  (plain-file "under-sea-marimo-notebook.py"
              (string-append
               "import marimo\n"
               "\n"
               "__generated_with = \"0.25.2\"\n"
               "app = marimo.App(app_title=\"under-sea-notebook-marker\")\n"
               "\n"
               "\n"
               "@app.cell\n"
               "def _():\n"
               "    import marimo as mo\n"
               "    return (mo,)\n"
               "\n"
               "\n"
               "@app.cell\n"
               "def _(mo):\n"
               "    mo.md(\"under-sea-notebook-marker\")\n"
               "    return\n"
               "\n"
               "\n"
               "if __name__ == \"__main__\":\n"
               "    app.run()\n")))

;; The marimo service requires the "networking" shepherd provision, which
;; %base-services does not provide (it only brings up loopback).  An empty,
;; side-effect-free static-networking satisfies the requirement without
;; touching real interfaces, so it is safe inside an unprivileged container
;; that shares the host network namespace.
(define %under-sea-marimo-networking
  (service static-networking-service-type
           (list (static-networking (addresses '())
                                    (routes '())
                                    (requirement '())
                                    (provision '(networking))))))

(define %under-sea-marimo-token
  (plain-file "under-sea-marimo-token" "under-sea-secret\n"))

(define %under-sea-marimo-service
  (service marimo-service-type
           (marimo-configuration
            (notebook %under-sea-marimo-notebook))))

(define-public %under-sea-marimo-os
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
    (packages (cons* marimo curl %base-packages))
    (services (cons* %under-sea-marimo-service
                     %under-sea-marimo-networking
                     %base-services))))


;;; Token-authenticated variant.  The password file lives outside the store
;;; and is created by the OS; the service only receives its path.
(define-public %under-sea-marimo-auth-os
  (operating-system
    (inherit %under-sea-marimo-os)
    (services
     (cons* (service marimo-service-type
                     (marimo-configuration
                      (notebook %under-sea-marimo-notebook)
                      (token-password-file "/etc/marimo-token")))
            (extra-special-file "/etc/marimo-token"
                                %under-sea-marimo-token)
            %under-sea-marimo-networking
            %base-services))))
