;;; Optional system integration for the Autodesk Licensing Service: run the
;;; AdskLicensingService daemon so Autodesk products (Moldflow) can check out
;;; licenses.  As upstream does, the daemon runs as an unprivileged 'adsklic'
;;; account and writes its state under /var/opt/Autodesk/AdskLicensingService;
;;; only creating that fixed system directory needs privilege.  Installing the
;;; package does not start anything.
(define-module (under-sea services adsk-licensing)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (gnu system shadow)
  #:use-module (gnu packages admin)
  #:use-module (under-sea packages adsk-licensing)
  #:export (adsk-licensing-configuration
            adsk-licensing-configuration?
            adsk-licensing-service-type))

(define-record-type* <adsk-licensing-configuration>
  adsk-licensing-configuration make-adsk-licensing-configuration
  adsk-licensing-configuration?
  (adsk-licensing adsk-licensing-configuration-adsk-licensing (default adsk-licensing))
  ;; The Autodesk tools look for the service data at this fixed path.
  (state-directory adsk-licensing-configuration-state-directory
                   (default "/var/opt/Autodesk/AdskLicensingService"))
  (user adsk-licensing-configuration-user (default "adsklic"))
  (group adsk-licensing-configuration-group (default "adsklic")))

(define (adsk-licensing-accounts config)
  (list (user-group (name (adsk-licensing-configuration-group config))
                    (system? #t))
        (user-account
         (name (adsk-licensing-configuration-user config))
         (group (adsk-licensing-configuration-group config))
         (system? #t)
         (comment "Autodesk Licensing Service")
         (home-directory "/var/lib/adsklic")
         (shell (file-append shadow "/sbin/nologin")))))

(define (adsk-licensing-shepherd-service config)
  (let* ((executable
          (file-append (adsk-licensing-configuration-adsk-licensing config)
                       "/bin/AdskLicensingService"))
         (state (adsk-licensing-configuration-state-directory config))
         (log-dir (string-append state "/Log"))
         (user (adsk-licensing-configuration-user config))
         (group (adsk-licensing-configuration-group config)))
    (list
     (shepherd-service
      (provision '(adsk-licensing))
      (requirement '(networking))
      (documentation "Run the Autodesk Licensing Service daemon.")
      (start
       #~(begin
           (use-modules (guix build utils))
           ;; Accounts exist by the time services start; make the fixed data
           ;; directory writable by the unprivileged daemon account.
           (let ((pw (getpwnam #$user))
                 (gr (getgrnam #$group)))
             (mkdir-p #$state)
             (mkdir-p #$log-dir)
             (chown #$state (passwd:uid pw) (group:gid gr))
             (chown #$log-dir (passwd:uid pw) (group:gid gr))
             (chmod #$state #o755)
             (chmod #$log-dir #o755))
           (make-forkexec-constructor
            (list #$executable "--run")
            #:user #$user
            #:group #$group
            #:log-file "/var/log/adsk-licensing.log")))
      (stop #~(make-kill-destructor))
      (respawn? #t)))))

(define (adsk-licensing-activation config)
  (let ((state (adsk-licensing-configuration-state-directory config)))
    #~(begin
        (use-modules (guix build utils))
        (mkdir-p #$state)
        (mkdir-p #$(string-append state "/Log")))))

(define adsk-licensing-service-type
  (service-type
   (name 'adsk-licensing)
   (extensions
    (list
     (service-extension account-service-type adsk-licensing-accounts)
     (service-extension shepherd-root-service-type adsk-licensing-shepherd-service)
     (service-extension activation-service-type adsk-licensing-activation)))
   (default-value (adsk-licensing-configuration))
   (description "Run the Autodesk Licensing Service as the unprivileged
@code{adsklic} account, which Autodesk products (Moldflow Insight) use to check
out network or named-user licenses.  It writes its state under
@file{/var/opt/Autodesk/AdskLicensingService}.")))
