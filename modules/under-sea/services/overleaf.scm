;;; Overleaf service for the under-sea channel.
;;;
;;; Optional shepherd service wrapping overleaf-ctl.  The channel itself
;;; stays independent: instantiating this service in *your* operating
;;; system configuration is entirely up to you, and neither the service
;;; nor the channel modifies any host system service or data --- state
;;; lives under (overleaf-configuration-root), default /var/lib/overleaf.
;;;
;;; Requires the docker daemon, which you run either via docker-service-type
;;; or however you prefer; this module only references the docker package
;;; binaries as inputs.

(define-module (under-sea services overleaf)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (gnu packages docker)
  #:use-module (under-sea packages overleaf)
  #:export (overleaf-configuration
            overleaf-configuration?
            overleaf-configuration-package
            overleaf-configuration-root
            overleaf-service-type))

(define-record-type* <overleaf-configuration>
  overleaf-configuration make-overleaf-configuration
  overleaf-configuration?
  (package overleaf-configuration-package (default overleaf-ctl))
  (root    overleaf-configuration-root    (default "/var/lib/overleaf"))
  (log     overleaf-configuration-log     (default "/var/log/overleaf.log")))

(define (overleaf-shepherd-service config)
  (match-record config <overleaf-configuration>
    (package root log)
    (let ((ctl (file-append package "/bin/overleaf-ctl")))
      (list (shepherd-service
             (documentation "Run the Overleaf Community Edition containers.")
             (provision '(overleaf))
             (requirement '(networking dockerd))
             (one-shot? #t)
             (start #~(make-forkexec-constructor
                       (list #$ctl "up")
                       #:environment-variables
                       (list (string-append "OVERLEAF_ROOT=" #$root))
                       #:log-file #$log)))
            (shepherd-service
             (documentation "Stop the Overleaf Community Edition containers.")
             (provision '(overleaf-stop))
             (requirement '(overleaf))
             (one-shot? #t)
             (start #~(make-forkexec-constructor
                       (list #$ctl "stop")
                       #:environment-variables
                       (list (string-append "OVERLEAF_ROOT=" #$root))
                       #:log-file #$log)))))))

(define overleaf-service-type
  (service-type
   (name 'overleaf)
   (description
    "Overleaf Community Edition via the official docker-compose toolkit.
Before enabling, run @command{overleaf-ctl init} once as root to generate
config/ and set SITE_URL.")
   (extensions
    (list (service-extension shepherd-root-service-type
                             overleaf-shepherd-service)))
   (default-value (overleaf-configuration))))
