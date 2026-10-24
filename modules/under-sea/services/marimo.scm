;;; System service for marimo, the reactive Python notebook server.  The
;;; service runs `marimo run` under Shepherd as an unprivileged 'marimo'
;;; account, with its state and home under /var/lib/marimo.  Authentication is
;;; disabled by default, which is safe for the loopback-only default host; a
;;; non-loopback deployment can enable the token or point at a password file
;;; outside the store.
(define-module (under-sea services marimo)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (gnu system shadow)
  #:use-module (gnu packages admin)
  #:use-module (under-sea packages marimo)
  #:export (marimo-configuration
            marimo-configuration?
            marimo-service-type))

(define-record-type* <marimo-configuration>
  marimo-configuration make-marimo-configuration
  marimo-configuration?
  (package marimo-configuration-package (default marimo))
  ;; Required: a plain-file/local-file (or another file-like object) is
  ;; resolved to its store path, while a string is passed through as a host
  ;; path.  There is deliberately no default, so an omitted notebook is an
  ;; error at configuration time.
  (notebook marimo-configuration-notebook
            (sanitize (lambda (value)
                        (unless (or (string? value) (file-like? value))
                          (error "marimo notebook must be a file-like object \
or a path string" value))
                        value)))
  (host marimo-configuration-host (default "127.0.0.1"))
  (port marimo-configuration-port (default 2718))
  (token? marimo-configuration-token? (default #f))
  ;; A host path (not a file-like object): the secret stays outside the store.
  (token-password-file marimo-configuration-token-password-file
                       (default #f)
                       (sanitize (lambda (value)
                                   (unless (or (not value) (string? value))
                                     (error "marimo token-password-file must \
be a host path string, not a file-like object" value))
                                   value)))
  (working-directory marimo-configuration-working-directory
                     (default "/var/lib/marimo"))
  (user marimo-configuration-user (default "marimo"))
  (group marimo-configuration-group (default "marimo"))
  (extra-arguments marimo-configuration-extra-arguments (default '()))
  (log-file marimo-configuration-log-file (default "/var/log/marimo.log")))

(define (marimo-accounts config)
  (list (user-group (name (marimo-configuration-group config))
                    (system? #t))
        (user-account
         (name (marimo-configuration-user config))
         (group (marimo-configuration-group config))
         (system? #t)
         (comment "marimo notebook server")
         (home-directory (marimo-configuration-working-directory config))
         (shell (file-append shadow "/sbin/nologin")))))

;; The notebook element is left as a file-like object or a string in this
;; list; the #$@ splice in the start gexp resolves a file-like object to its
;; store path and leaves a plain path string untouched.
(define (marimo-arguments config)
  (let ((notebook (marimo-configuration-notebook config))
        (host (marimo-configuration-host config))
        (port (marimo-configuration-port config))
        (token? (marimo-configuration-token? config))
        (token-password-file
         (marimo-configuration-token-password-file config))
        (extra (marimo-configuration-extra-arguments config)))
    (append
     (list "run" notebook
           "--headless"
           "--host" host
           "--port" (number->string port))
     (cond
      (token? '("--token"))
      (token-password-file '())
      (else '("--no-token")))
     (if token-password-file
         (list "--token-password-file" token-password-file)
         '())
     extra)))

(define (marimo-working-directory-activation config)
  (let ((directory (marimo-configuration-working-directory config))
        (user (marimo-configuration-user config))
        (group (marimo-configuration-group config)))
    #~(begin
        (use-modules (guix build utils))
        (mkdir-p #$directory)
        ;; Accounts are normally created before activation runs; keep this
        ;; tolerant of ordering so the activation script never aborts a boot.
        (let ((pw (getpwnam #$user))
              (gr (getgrnam #$group)))
          (when (and pw gr)
            (chown #$directory (passwd:uid pw) (group:gid gr))))
        (chmod #$directory #o755))))

(define (marimo-shepherd-service config)
  (let* ((executable (file-append (marimo-configuration-package config)
                                  "/bin/marimo"))
         (directory (marimo-configuration-working-directory config))
         (user (marimo-configuration-user config))
         (group (marimo-configuration-group config))
         (log-file (marimo-configuration-log-file config))
         (arguments (marimo-arguments config)))
    (list
     (shepherd-service
      (provision '(marimo))
      (requirement '(networking user-processes))
      (documentation "Run the marimo notebook server.")
      (start
       #~(begin
           (use-modules (guix build utils))
           ;; Make sure the directory exists and belongs to the service
           ;; account even if activation ran before the account was created.
           (let ((pw (getpwnam #$user))
                 (gr (getgrnam #$group)))
             (mkdir-p #$directory)
             (chown #$directory (passwd:uid pw) (group:gid gr))
             (chmod #$directory #o755))
           (make-forkexec-constructor
            (list #$executable #$@arguments)
            #:user #$user
            #:group #$group
            #:directory #$directory
            #:log-file #$log-file
            #:environment-variables
            (cons* (string-append "HOME=" #$directory)
                   (string-append "USER=" #$user)
                   (string-append "LOGNAME=" #$user)
                   (default-environment-variables)))))
      (stop #~(make-kill-destructor))
      (respawn? #t)))))

(define marimo-service-type
  (service-type
   (name 'marimo)
   (extensions
    (list
     (service-extension account-service-type marimo-accounts)
     (service-extension shepherd-root-service-type marimo-shepherd-service)
     (service-extension activation-service-type
                        marimo-working-directory-activation)))
   (description "Run the marimo notebook server (@command{marimo run}) as the
unprivileged @code{marimo} account with its state under
@file{/var/lib/marimo}.  The default binds to loopback with authentication
disabled; set @code{token?} or @code{token-password-file} for non-loopback
deployments.")))
