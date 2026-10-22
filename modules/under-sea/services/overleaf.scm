;;; Overleaf Community Edition via the official docker-compose toolkit,
;;; wrapped as overleaf-ctl.  State lives under (root); the rc/env files
;;; are regenerated on reconfigure — use extra-env for anything else.

(define-module (under-sea services overleaf)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (ice-9 match)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages containers)
  #:use-module (under-sea packages overleaf)
  #:export (overleaf-configuration
            overleaf-configuration?
            overleaf-service-type))

(define-record-type* <overleaf-configuration>
  overleaf-configuration make-overleaf-configuration
  overleaf-configuration?
  (package         overleaf-configuration-package         (default overleaf-ctl))
  (root            overleaf-configuration-root            (default "/var/lib/overleaf"))
  (log             overleaf-configuration-log             (default "/var/log/overleaf.log"))
  (listen-ip       overleaf-configuration-listen-ip       (default "0.0.0.0"))
  (port            overleaf-configuration-port            (default 8420))
  (app-name        overleaf-configuration-app-name        (default "Overleaf"))
  (site-url        overleaf-configuration-site-url        (default ""))
  (secure-cookies? overleaf-configuration-secure-cookies? (default #f))
  ;; 'docker (default) or 'podman (via generated shims).
  (runtime         overleaf-configuration-runtime         (default 'docker))
  ;; (KEY . value) pairs for variables.env.
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
                   "OVERLEAF_DATA_PATH=" (overleaf-configuration-root config) "/data/sharelatex\n"
                   "MONGO_DATA_PATH=" (overleaf-configuration-root config) "/data/mongo\n"
                   "REDIS_DATA_PATH=" (overleaf-configuration-root config) "/data/redis\n"
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
        (mkdir-p (string-append #$root "/config"))
        (mkdir-p (string-append #$root "/shims"))
        #$@(if (eq? runtime 'podman)
               (list
                #~(let ((shims (string-append #$root "/shims")))
                    (call-with-output-file (string-append shims "/docker")
                      (lambda (port)
                        (format port "#!~a/bin/sh~%exec ~a/podman \"$@\"~%"
                                #$bash #$(file-append podman "/bin"))))
                    (call-with-output-file
                        (string-append shims "/docker-compose")
                      (lambda (port)
                        (format port "#!~a/bin/sh~%exec ~a \"$@\"~%"
                                #$bash
                                #$(file-append podman-compose
                                               "/bin/podman-compose"))))
                    (chmod (string-append shims "/docker") #o555)
                    (chmod (string-append shims "/docker-compose") #o555)))
               '()))))

(define (overleaf-shepherd-service config)
  (match-record config <overleaf-configuration>
    (package root log runtime)
    (let* ((ctl (file-append package "/bin/overleaf-ctl"))
           (config-dir (overleaf-config-dir config))
           (env (list (string-append "OVERLEAF_ROOT=" root)))
           ;; dockerd only for the docker runtime.
           (requirements (match runtime
                           ('docker '(networking dockerd))
                           (_ '(networking)))))
      (list (shepherd-service
             (documentation "Run the Overleaf Community Edition containers.")
             (provision '(overleaf))
             (requirement requirements)
             (one-shot? #t)
                        (start #~(make-forkexec-constructor
                                  (list "/bin/sh" "-c"
                                        (string-append
                                         "mkdir -p " #$root "/config && "
                                         "cp " #$config-dir "/overleaf.rc "
                                         #$config-dir "/variables.env "
                                         #$root "/config/ && "
                                         #$ctl " up"))
                                  #:environment-variables '#$env
                                  #:log-file #$log)))
            (shepherd-service
             (documentation "Stop the Overleaf Community Edition containers.")
             (provision '(overleaf-stop))
             (requirement '(overleaf))
             (one-shot? #t)
             (start #~(make-forkexec-constructor
                       (list #$ctl "stop")
                       #:environment-variables '#$env
                       #:log-file #$log)))))))

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
