;;; System service for the Seafile sync client: run `seaf-daemon` in the
;;; foreground under Shepherd as an unprivileged 'seafile' account.  The
;;; configuration directory (seafile.ini) and the data/worktree directories
;;; live under the account's home, so a single state directory can be backed
;;; up or moved as a unit.  No server account is configured here: the daemon
;;; starts and serves its RPC socket without one.
(define-module (under-sea services seafile)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (gnu system shadow)
  #:use-module (gnu packages admin)
  #:use-module (under-sea packages seafile)
  #:export (seafile-configuration
            seafile-configuration?
            seafile-client-service-type))

(define-record-type* <seafile-configuration>
  seafile-configuration make-seafile-configuration
  seafile-configuration?
  (package seafile-configuration-package (default seafile))
  ;; Holds conf/ (seafile.ini) and data/ (seafile-data, the default worktree).
  (state-directory seafile-configuration-state-directory
                   (default "/var/lib/seafile"))
  (user seafile-configuration-user (default "seafile"))
  (group seafile-configuration-group (default "seafile"))
  ;; Extra arguments appended to the seaf-daemon invocation.
  (extra-arguments seafile-configuration-extra-arguments (default '()))
  (log-file seafile-configuration-log-file (default "/var/log/seafile.log")))

(define (seafile-conf-directory config)
  (string-append (seafile-configuration-state-directory config) "/conf"))

(define (seafile-data-directory config)
  (string-append (seafile-configuration-state-directory config) "/data"))

(define (seafile-data-store config)
  (string-append (seafile-data-directory config) "/seafile-data"))

(define (seafile-worktree config)
  (string-append (seafile-data-directory config) "/seafile"))

(define (seafile-accounts config)
  (list (user-group (name (seafile-configuration-group config))
                    (system? #t))
        (user-account
         (name (seafile-configuration-user config))
         (group (seafile-configuration-group config))
         (system? #t)
         (comment "Seafile sync client")
         (home-directory (seafile-configuration-state-directory config))
         (shell (file-append shadow "/sbin/nologin")))))

(define (seafile-activation config)
  (let* ((state (seafile-configuration-state-directory config))
         (conf (seafile-conf-directory config))
         (data (seafile-data-directory config))
         (seafile-data (seafile-data-store config))
         (worktree (seafile-worktree config))
         (package (seafile-configuration-package config))
         (user (seafile-configuration-user config))
         (group (seafile-configuration-group config)))
    #~(begin
        (use-modules (guix build utils) (ice-9 ftw))
        (let* ((state #$state)
               (conf #$conf)
               (data #$data)
               (seafile-data #$seafile-data)
               (worktree #$worktree)
               (ini (string-append conf "/seafile.ini")))
          (mkdir-p state)
          (mkdir-p data)
          (mkdir-p seafile-data)
          (mkdir-p worktree)
          (unless (file-exists? ini)
            ;; `seaf-cli init' refuses to run when its config directory
            ;; already exists, so remove an empty placeholder and let it
            ;; create the directory itself.
            (when (file-exists? conf)
              (if (null? (scandir conf (lambda (entry)
                                         (not (member entry '("." ".."))))))
                  (rmdir conf)
                  (error "seafile: refusing to initialize non-empty config directory"
                         conf)))
            ;; The wrapper already carries the Python module search path;
            ;; HOME keeps any incidental user-config lookups inside the state
            ;; tree.
            (setenv "HOME" state)
            (setenv "PATH" (string-append #$package "/bin:"
                                          (or (getenv "PATH") "")))
            (invoke #$(file-append package "/bin/seaf-cli")
                    "init" "-c" conf "-d" data))
          (mkdir-p conf)
          ;; Accounts may be activated after this script, so only chown when
          ;; the user is already known; the shepherd start re-checks anyway.
          (let ((pw (getpwnam #$user))
                (gr (getgrnam #$group)))
            (when (and pw gr)
              (let ((uid (passwd:uid pw))
                    (gid (group:gid gr)))
                (for-each (lambda (file)
                            (false-if-exception (chown file uid gid)))
                          (find-files state #:directories? #t))
                (chown state uid gid))))))))

(define (seafile-shepherd-service config)
  (let* ((package (seafile-configuration-package config))
         (state (seafile-configuration-state-directory config))
         (conf (seafile-conf-directory config))
         (data (seafile-data-directory config))
         (seafile-data (seafile-data-store config))
         (worktree (seafile-worktree config))
         (user (seafile-configuration-user config))
         (group (seafile-configuration-group config))
         (args (seafile-configuration-extra-arguments config))
         (log-file (seafile-configuration-log-file config)))
    (list
     (shepherd-service
      (provision '(seafile))
      (requirement '(networking user-processes))
      (documentation "Run the Seafile sync client daemon in the foreground.")
      (start
       #~(begin
           (use-modules (guix build utils) (srfi srfi-1))
           (let* ((pw (getpwnam #$user))
                  (gr (getgrnam #$group))
                  (uid (passwd:uid pw))
                  (gid (group:gid gr))
                  (essential (list #$state #$conf #$data
                                   #$seafile-data #$worktree
                                   (string-append #$conf "/seafile.ini"))))
             (mkdir-p #$state)
             (mkdir-p #$conf)
             (mkdir-p #$data)
             (mkdir-p #$seafile-data)
             (mkdir-p #$worktree)
             ;; Activation normally owns the whole tree already.  On the
             ;; first boot it can run before the account is created, so make
             ;; sure the directories the daemon must write are usable.
             (unless (every (lambda (file)
                              (and (file-exists? file)
                                   (= (stat:uid (stat file)) uid)
                                   (= (stat:gid (stat file)) gid)))
                            essential)
               (for-each (lambda (file)
                           (false-if-exception (chown file uid gid)))
                         (find-files #$state #:directories? #t))
               (chown #$state uid gid)))
           (make-forkexec-constructor
            (list #$(file-append package "/bin/seaf-daemon")
                  "-c" #$conf
                  "-d" #$seafile-data
                  "-w" #$worktree
                  #$@args)
            #:user #$user
            #:group #$group
            #:directory #$state
            #:environment-variables
            (cons* (string-append "HOME=" #$state)
                   (string-append "USER=" #$user)
                   (string-append "LOGNAME=" #$user)
                   (default-environment-variables))
            #:log-file #$log-file)))
      (stop #~(make-kill-destructor))
      (respawn? #t)))))

(define seafile-client-service-type
  (service-type
   (name 'seafile)
   (extensions
    (list
     (service-extension account-service-type seafile-accounts)
     (service-extension shepherd-root-service-type seafile-shepherd-service)
     (service-extension activation-service-type seafile-activation)))
   (default-value (seafile-configuration))
   (description "Run the Seafile sync client daemon (@command{seaf-daemon})
as the unprivileged @code{seafile} account, with its configuration and data
under @file{/var/lib/seafile}.  The daemon listens on a local RPC socket; no
server account is required for it to start.")))
