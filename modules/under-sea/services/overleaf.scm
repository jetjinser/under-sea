;;; Overleaf service for the under-sea channel.
;;;
;;; Optional shepherd service wrapping overleaf-ctl.  The channel itself
;;; stays independent: instantiating this service in *your* operating
;;; system configuration is entirely up to you, and neither the service
;;; nor the channel modifies any host system service or data --- state
;;; lives under (overleaf-configuration-root), default /var/lib/overleaf.
;;;
;;; Configuration is declarative: the fields of overleaf-configuration
;;; generate config/overleaf.rc and config/variables.env at service start;
;;; hand edits to those files are overwritten on reconfigure + restart.
;;; Use extra-env for anything not covered by the fields.
;;;
;;; Requires the docker daemon, which you run either via docker-service-type
;;; or however you prefer; this module only references the docker package
;;; binaries as inputs.

(define-module (under-sea services overleaf)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (ice-9 match)
  #:use-module (guix packages)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages containers)
  #:use-module (under-sea packages overleaf)
  #:export (overleaf-configuration
            overleaf-configuration?
            overleaf-configuration-package
            overleaf-configuration-root
            overleaf-configuration-log
            overleaf-configuration-port
            overleaf-configuration-listen-ip
            overleaf-configuration-app-name
            overleaf-configuration-site-url
            overleaf-configuration-secure-cookies?
            overleaf-configuration-runtime
            overleaf-configuration-extra-env
            overleaf-config-dir
            overleaf-variables-env
            overleaf-overleaf-rc
            overleaf-shepherd-service
            overleaf-service-type))

(define-record-type* <overleaf-configuration>
  overleaf-configuration make-overleaf-configuration
  overleaf-configuration?
  (package         overleaf-configuration-package         (default overleaf-ctl))
  (root            overleaf-configuration-root            (default "/var/lib/overleaf"))
  (log             overleaf-configuration-log             (default "/var/log/overleaf.log"))
  (listen-ip       overleaf-configuration-listen-ip       (default "0.0.0.0"))
  (port            overleaf-configuration-port            (default 8080))
  (app-name        overleaf-configuration-app-name        (default "Overleaf"))
  (site-url        overleaf-configuration-site-url        (default ""))
  (secure-cookies? overleaf-configuration-secure-cookies? (default #f))
  ;; Container runtime backend: 'docker (default, the toolkit's officially
  ;; supported path) or 'podman (rootful podman; the service then generates
  ;; $root/shims/docker and docker-compose so the toolkit's docker calls
  ;; run through podman).
  (runtime         overleaf-configuration-runtime         (default 'docker))
  ;; Extra environment variables for the sharelatex container, as a list
  ;; of (KEY . value) pairs rendered into variables.env verbatim.
  (extra-env       overleaf-configuration-extra-env       (default '())))

(define (overleaf-variables-env config)
  "Return a file-like object containing the variables.env contents for
CONFIG."
  (define (render-extra kvs)
    (if (null? kvs)
        ""
        (let ((kv (car kvs)))
          (string-append (symbol->string (car kv)) "="
                         (if (string? (cdr kv)) (cdr kv)
                             (format #f "~a" (cdr kv)))
                         "\n"
                         (render-extra (cdr kvs))))))
  (mixed-text-file "variables.env"
                   "OVERLEAF_APP_NAME="
                   (overleaf-configuration-app-name config) "\n"
                   (if (string-null? (overleaf-configuration-site-url config))
                       ""
                       (string-append "SITE_URL="
                                      (overleaf-configuration-site-url config)
                                      "\n"))
                   "OVERLEAF_SECURE_COOKIES="
                   (if (overleaf-configuration-secure-cookies? config)
                       "true" "false")
                   "\n"
                   (render-extra (overleaf-configuration-extra-env config))))

(define (overleaf-overleaf-rc config)
  "Return a file-like object containing the overleaf.rc contents for
CONFIG."
  (mixed-text-file "overleaf.rc"
                   "OVERLEAF_LISTEN_IP=" (overleaf-configuration-listen-ip config) "\n"
                   "OVERLEAF_PORT=" (number->string (overleaf-configuration-port config)) "\n"
                   "NGINX_ENABLED=false\n"
                   "TEXLIVE_IMAGE=quay.io/overleaf/texlive-full\n"))

(define (overleaf-config-dir config)
  "Return a directory containing the generated overleaf.rc and
variables.env for CONFIG."
  (computed-file "overleaf-config"
                 #~(begin
                     (use-modules (guix build utils))
                     (mkdir #$output)
                     (copy-file #$(overleaf-overleaf-rc config)
                                (string-append #$output "/overleaf.rc"))
                     (copy-file #$(overleaf-variables-env config)
                                (string-append #$output "/variables.env")))
                 #:options '(#:modules ((guix build utils)))))

(define (overleaf-activation config)
  "Return an activation gexp for CONFIG.  When the runtime backend is
'podman, it generates docker / docker-compose shims in $root/shims so the
toolkit's docker calls run through podman.  (With the default 'docker
backend, shims/ is left empty and the PATH entry is harmless.)"
  (let* ((root (overleaf-configuration-root config))
         (runtime (overleaf-configuration-runtime config)))
    #~(begin
        (use-modules (guix build utils))
        (let* ((shims (string-append #$root "/shims"))
               (podman-bin #$(file-append podman "/bin"))
               (podman-compose-bin
                #$(file-append podman-compose "/bin/podman-compose")))
          (mkdir-p shims)
          (call-with-output-file (string-append shims "/docker")
            (lambda (port)
              (format port "#!~a/bin/sh~%exec ~a/podman \"$@\"~%"
                      #$bash podman-bin)))
          (call-with-output-file (string-append shims "/docker-compose")
            (lambda (port)
              (format port "#!~a/bin/sh~%exec ~a \"$@\"~%"
                      #$bash podman-compose-bin)))
          (chmod (string-append shims "/docker") #o555)
          (chmod (string-append shims "/docker-compose") #o555)
          (mkdir-p (string-append #$root "/config"))))))

(define (overleaf-shepherd-service config)
  (match-record config <overleaf-configuration>
    (package root log runtime)
    (let* ((ctl (file-append package "/bin/overleaf-ctl"))
           (config-dir (overleaf-config-dir config))
           (env (list (string-append "OVERLEAF_ROOT=" root))))
      (list (shepherd-service
             (documentation "Run the Overleaf Community Edition containers.")
             (provision '(overleaf))
             (requirement '(networking dockerd))
             (one-shot? #t)
             (start #~(make-forkexec-constructor
                       (list "/bin/sh" "-c"
                             (string-append
                              "mkdir -p " #$root "/config && "
                              "cp " #$config-dir "/overleaf.rc "
                              #$config-dir "/variables.env "
                              #$root "/config/ && "
                              #$ctl " up")
                             )
                       #:environment-variables env
                       #:log-file log)))
            (shepherd-service
             (documentation "Stop the Overleaf Community Edition containers.")
             (provision '(overleaf-stop))
             (requirement '(overleaf))
             (one-shot? #t)
             (start #~(make-forkexec-constructor
                       (list #$ctl "stop")
                       #:environment-variables env
                       #:log-file log)))))))

(define overleaf-service-type
  (service-type
   (name 'overleaf)
   (description
    "Overleaf Community Edition via the official docker-compose toolkit.
Configuration is declarative: fields of @code{overleaf-configuration}
generate config/overleaf.rc and config/variables.env at service start;
hand edits to those files are overwritten.  Use
@code{overleaf-configuration-extra-env} for variables without a field.
Before first use, run @command{overleaf-ctl init} once as root to seed
config/ if you prefer interactive generation, or just start the service.")
   (extensions
    (list (service-extension shepherd-root-service-type
                             overleaf-shepherd-service)
          (service-extension activation-service-type
                             overleaf-activation)))
   (default-value (overleaf-configuration))))
