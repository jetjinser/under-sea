;;; System service for the Hermes Agent messaging gateway: run `hermes
;;; gateway` under Shepherd as an unprivileged 'hermes' account with its home
;;; at /var/lib/hermes (HERMES_HOME), so conversations, skills and the state
;;; database persist across restarts.  Messaging channels (Telegram, Discord,
;;; ...) are configured through credentials in the environment, not through
;;; this record; without any channel the gateway still runs and serves the
;;; built-in cron scheduler.
(define-module (under-sea services hermes)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (gnu system shadow)
  #:use-module (gnu packages admin)
  #:use-module (under-sea packages hermes)
  #:export (hermes-configuration
            hermes-configuration?
            hermes-service-type))

(define-record-type* <hermes-configuration>
  hermes-configuration make-hermes-configuration
  hermes-configuration?
  (hermes hermes-configuration-hermes (default hermes-agent))
  ;; Hermes persists everything (state database, skills, memory) under
  ;; HERMES_HOME; it also honours HOME, which the service points at the same
  ;; directory.
  (state-directory hermes-configuration-state-directory
                   (default "/var/lib/hermes"))
  (user hermes-configuration-user (default "hermes"))
  (group hermes-configuration-group (default "hermes"))
  ;; Extra arguments passed to `hermes gateway`.
  (gateway-arguments hermes-configuration-gateway-arguments (default '()))
  ;; Extra environment variables as (key . value) string pairs, for channel
  ;; credentials such as ("TELEGRAM_BOT_TOKEN" . "…").
  (environment hermes-configuration-environment (default '())))

(define (hermes-accounts config)
  (list (user-group (name (hermes-configuration-group config))
                    (system? #t))
        (user-account
         (name (hermes-configuration-user config))
         (group (hermes-configuration-group config))
         (system? #t)
         (comment "Hermes Agent gateway")
         (home-directory (hermes-configuration-state-directory config))
         (shell (file-append shadow "/sbin/nologin")))))

(define (hermes-shepherd-service config)
  (let* ((executable (file-append (hermes-configuration-hermes config)
                                  "/bin/hermes"))
         (state (hermes-configuration-state-directory config))
         (user (hermes-configuration-user config))
         (group (hermes-configuration-group config))
         (args (hermes-configuration-gateway-arguments config))
         (environment (hermes-configuration-environment config))
         (env-list (map (lambda (pair)
                          (string-append (car pair) "=" (cdr pair)))
                        environment))
         ;; Never empty: HOME/HERMES_HOME are always present, so the quoted
         ;; gexp splice below is always valid syntax.
         (full-env (append (list (string-append "HOME=" state)
                                 (string-append "HERMES_HOME=" state))
                           env-list)))
    (list
     (shepherd-service
      (provision '(hermes))
      (requirement '(networking user-processes))
      (documentation "Run the Hermes Agent messaging gateway.")
      (start
       #~(begin
           (use-modules (guix build utils))
           ;; Accounts exist by the time services start; make the state
           ;; directory writable by the unprivileged gateway account.
           (let ((pw (getpwnam #$user))
                 (gr (getgrnam #$group)))
             (mkdir-p #$state)
             (chown #$state (passwd:uid pw) (group:gid gr))
             (chmod #$state #o755))
           (make-forkexec-constructor
            (list #$executable "gateway" "start" #$@args)
            #:user #$user
            #:group #$group
            #:log-file "/var/log/hermes.log")))
      (stop #~(make-kill-destructor))
      (respawn? #t)))))

(define (hermes-activation config)
  (let ((state (hermes-configuration-state-directory config)))
    #~(begin
        (use-modules (guix build utils))
        (mkdir-p #$state))))

(define hermes-service-type
  (service-type
   (name 'hermes)
   (extensions
    (list
     (service-extension account-service-type hermes-accounts)
     (service-extension shepherd-root-service-type hermes-shepherd-service)
     (service-extension activation-service-type hermes-activation)))
   (default-value (hermes-configuration))
   (description "Run the Hermes Agent messaging gateway (@command{hermes
gateway}) as the unprivileged @code{hermes} account with its state under
@file{/var/lib/hermes}.  Messaging channels are configured through
credentials in @code{environment}; without any channel the gateway still
serves its built-in cron scheduler.")))
