;;; System service for SeaweedFS: run the single-process `weed server` mode
;;; (master, volume, filer and S3 in one process) under Shepherd as an
;;; unprivileged 'seaweedfs' account.  Installing the package does not start
;;; anything; the service keeps its state under /var/lib/seaweedfs.
(define-module (under-sea services seaweedfs)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (gnu system shadow)
  #:use-module (gnu packages admin)
  #:use-module (under-sea packages seaweedfs)
  #:export (seaweedfs-configuration
            seaweedfs-configuration?
            seaweedfs-service-type
            seaweedfs-cluster-configuration
            seaweedfs-cluster-configuration?
            seaweedfs-cluster-service-type
            seaweedfs-mini-configuration
            seaweedfs-mini-configuration?
            seaweedfs-mini-service-type))

(define-record-type* <seaweedfs-configuration>
  seaweedfs-configuration make-seaweedfs-configuration
  seaweedfs-configuration?
  (package seaweedfs-configuration-package (default seaweedfs))
  ;; Master metadata, volume data and the default filer store all live here.
  (data-directory seaweedfs-configuration-data-directory
                  (default "/var/lib/seaweedfs"))
  ;; Advertised address and bind address.  Loopback keeps the defaults safe in
  ;; a VM or an unprivileged container; set "0.0.0.0" for a real deployment.
  (ip seaweedfs-configuration-ip (default "127.0.0.1"))
  (master-port seaweedfs-configuration-master-port (default 9333))
  (volume-port seaweedfs-configuration-volume-port (default 8080))
  (filer-port seaweedfs-configuration-filer-port (default 8888))
  (s3-port seaweedfs-configuration-s3-port (default 8333))
  (filer? seaweedfs-configuration-filer? (default #t))
  (s3? seaweedfs-configuration-s3? (default #t))
  ;; Extra arguments appended verbatim to `weed server`.
  (extra-arguments seaweedfs-configuration-extra-arguments (default '()))
  (user seaweedfs-configuration-user (default "seaweedfs"))
  (group seaweedfs-configuration-group (default "seaweedfs"))
  (log-file seaweedfs-configuration-log-file
            (default "/var/log/seaweedfs.log")))

(define (seaweedfs-accounts config)
  (list (user-group (name (seaweedfs-configuration-group config))
                    (system? #t))
        (user-account
         (name (seaweedfs-configuration-user config))
         (group (seaweedfs-configuration-group config))
         (system? #t)
         (comment "SeaweedFS storage server")
         (home-directory (seaweedfs-configuration-data-directory config))
         (shell (file-append shadow "/sbin/nologin")))))

(define (seaweedfs-server-arguments config)
  "Return the `weed server' command-line arguments for CONFIG."
  (let ((ip (seaweedfs-configuration-ip config)))
    (append
     (list "server"
           (string-append "-dir="
                          (seaweedfs-configuration-data-directory config))
           (string-append "-ip=" ip)
           (string-append "-ip.bind=" ip)
           (string-append "-master.port="
                          (number->string
                           (seaweedfs-configuration-master-port config)))
           (string-append "-volume.port="
                          (number->string
                           (seaweedfs-configuration-volume-port config)))
           (string-append "-filer.port="
                          (number->string
                           (seaweedfs-configuration-filer-port config)))
           (string-append "-s3.port="
                          (number->string
                           (seaweedfs-configuration-s3-port config)))
           ;; Keep the volume size and count bounded for small disks.
           "-master.volumeSizeLimitMB=1024"
           "-volume.max=5"
           ;; Upstream spells the opt-out flag -master.telemetry; there is no
           ;; plain -telemetry flag in `weed server --help' (4.49).
           "-master.telemetry=false")
     (if (seaweedfs-configuration-filer? config) '("-filer") '())
     (if (seaweedfs-configuration-s3? config) '("-s3") '())
     (seaweedfs-configuration-extra-arguments config))))

(define (seaweedfs-shepherd-service config)
  (let* ((executable (file-append (seaweedfs-configuration-package config)
                                  "/bin/weed"))
         (data (seaweedfs-configuration-data-directory config))
         (user (seaweedfs-configuration-user config))
         (group (seaweedfs-configuration-group config))
         (log-file (seaweedfs-configuration-log-file config))
         (arguments (seaweedfs-server-arguments config)))
    (list
     (shepherd-service
      (provision '(seaweedfs))
      (requirement '(networking user-processes))
      (documentation "Run SeaweedFS (master, volume, filer and S3) in one process.")
      (start
       #~(begin
           (use-modules (guix build utils))
           ;; Accounts exist by the time services start; make sure the data
           ;; directory is writable by the unprivileged server account even if
           ;; the activation snippet ran before the accounts were created.
           (let ((pw (getpwnam #$user))
                 (gr (getgrnam #$group)))
             (mkdir-p #$data)
             (when (and pw gr)
               (chown #$data (passwd:uid pw) (group:gid gr)))
             (chmod #$data #o755))
           (make-forkexec-constructor
            (list #$executable #$@arguments)
            #:user #$user
            #:group #$group
            #:directory #$data
            #:log-file #$log-file)))
      (stop #~(make-kill-destructor))
      (respawn? #t)))))

(define (seaweedfs-activation config)
  (let ((data (seaweedfs-configuration-data-directory config))
        (user (seaweedfs-configuration-user config))
        (group (seaweedfs-configuration-group config)))
    #~(begin
        (use-modules (guix build utils))
        (mkdir-p #$data)
        (let ((pw (getpwnam #$user))
              (gr (getgrnam #$group)))
          (when (and pw gr)
            (chown #$data (passwd:uid pw) (group:gid gr))))
        (chmod #$data #o755))))

(define seaweedfs-service-type
  (service-type
   (name 'seaweedfs)
   (extensions
    (list
     (service-extension account-service-type seaweedfs-accounts)
     (service-extension shepherd-root-service-type
                        seaweedfs-shepherd-service)
     (service-extension activation-service-type seaweedfs-activation)))
   (default-value (seaweedfs-configuration))
   (description "Run SeaweedFS in single-process @command{weed server} mode as
the unprivileged @code{seaweedfs} account, with master, volume, filer and S3
listening on the configured addresses.  State is kept under
@file{/var/lib/seaweedfs}.")))

;;; A multi-process cluster: one Shepherd service per role.  The single-process
;;; service above is convenient for a workstation; this variant makes the
;;; master, volume, filer and S3 roles independent so they can be restarted,
;;; logged and (with non-loopback addresses) placed on different hosts.

(define-record-type* <seaweedfs-cluster-configuration>
  seaweedfs-cluster-configuration make-seaweedfs-cluster-configuration
  seaweedfs-cluster-configuration?
  (package seaweedfs-cluster-configuration-package (default seaweedfs))
  (data-directory seaweedfs-cluster-configuration-data-directory
                  (default "/var/lib/seaweedfs"))
  (ip seaweedfs-cluster-configuration-ip (default "127.0.0.1"))
  ;; Addresses used by the volume/filer/S3 clients.  They may point at other
  ;; hosts when the roles are split across machines.
  (master-address seaweedfs-cluster-configuration-master-address
                  (default "127.0.0.1:9333"))
  (filer-address seaweedfs-cluster-configuration-filer-address
                 (default "127.0.0.1:8888"))
  (master-port seaweedfs-cluster-configuration-master-port (default 9333))
  (volume-port seaweedfs-cluster-configuration-volume-port (default 8080))
  (filer-port seaweedfs-cluster-configuration-filer-port (default 8888))
  (s3-port seaweedfs-cluster-configuration-s3-port (default 8333))
  (user seaweedfs-cluster-configuration-user (default "seaweedfs"))
  (group seaweedfs-cluster-configuration-group (default "seaweedfs"))
  (log-directory seaweedfs-cluster-configuration-log-directory
                 (default "/var/log/seaweedfs")))

(define (seaweedfs-cluster-directory config role)
  (string-append (seaweedfs-cluster-configuration-data-directory config)
                 "/" role))

(define (seaweedfs-cluster-log config role)
  (string-append (seaweedfs-cluster-configuration-log-directory config)
                 "/" role ".log"))

(define (seaweedfs-cluster-accounts config)
  (seaweedfs-accounts
   (seaweedfs-configuration
    (package (seaweedfs-cluster-configuration-package config))
    (data-directory (seaweedfs-cluster-configuration-data-directory config))
    (user (seaweedfs-cluster-configuration-user config))
    (group (seaweedfs-cluster-configuration-group config)))))

(define (seaweedfs-cluster-activation config)
  (let ((data (seaweedfs-cluster-configuration-data-directory config))
        (log (seaweedfs-cluster-configuration-log-directory config))
        (user (seaweedfs-cluster-configuration-user config))
        (group (seaweedfs-cluster-configuration-group config)))
    #~(begin
        (use-modules (guix build utils))
        (for-each (lambda (role)
                    (mkdir-p (string-append #$data "/" role)))
                  '("master" "volume" "filer"))
        (mkdir-p #$log)
        (let ((pw (getpwnam #$user))
              (gr (getgrnam #$group)))
          (when (and pw gr)
            (let ((uid (passwd:uid pw))
                  (gid (group:gid gr)))
              (for-each (lambda (file)
                          (false-if-exception (chown file uid gid)))
                        (find-files #$data #:directories? #t))
              (chown #$data uid gid))))
        (chmod #$data #o755))))

(define* (seaweedfs-cluster-role-service config name role args
                                          #:key (requirement
                                                 '(networking user-processes)))
  (let* ((package (seaweedfs-cluster-configuration-package config))
         (executable (file-append package "/bin/weed"))
         (data (seaweedfs-cluster-directory config role))
         (user (seaweedfs-cluster-configuration-user config))
         (group (seaweedfs-cluster-configuration-group config))
         (log (seaweedfs-cluster-log config role)))
    (shepherd-service
     (provision (list name))
     (requirement requirement)
     (documentation (string-append "Run the SeaweedFS " role " role."))
     (start
      #~(begin
          (use-modules (guix build utils))
          (let ((pw (getpwnam #$user))
                (gr (getgrnam #$group)))
            (mkdir-p #$data)
            (when (and pw gr)
              (let ((uid (passwd:uid pw))
                    (gid (group:gid gr)))
                (for-each (lambda (file)
                            (false-if-exception (chown file uid gid)))
                          (find-files #$data #:directories? #t))
                (chown #$data uid gid)))
            (chmod #$data #o755))
          (make-forkexec-constructor
           (list #$executable #$@args)
           #:user #$user
           #:group #$group
           #:directory #$data
           #:log-file #$log)))
     (stop #~(make-kill-destructor))
     (respawn? #t))))

(define (seaweedfs-cluster-shepherd-services config)
  (let* ((ip (seaweedfs-cluster-configuration-ip config))
         (master (seaweedfs-cluster-configuration-master-address config))
         (filer (seaweedfs-cluster-configuration-filer-address config))
         (master-port (seaweedfs-cluster-configuration-master-port config))
         (volume-port (seaweedfs-cluster-configuration-volume-port config))
         (filer-port (seaweedfs-cluster-configuration-filer-port config))
         (s3-port (seaweedfs-cluster-configuration-s3-port config)))
    (list
     (seaweedfs-cluster-role-service
      config 'seaweedfs-master "master"
      (list "master"
            "-mdir" (seaweedfs-cluster-directory config "master")
            "-ip" ip "-ip.bind" ip
            "-port" (number->string master-port)
            "-peers=none"
            "-telemetry=false"))
     (seaweedfs-cluster-role-service
      config 'seaweedfs-volume "volume"
      (list "volume"
            "-dir" (seaweedfs-cluster-directory config "volume")
            "-ip" ip "-ip.bind" ip
            "-port" (number->string volume-port)
            "-master" master
            "-max=5")
      #:requirement '(networking user-processes seaweedfs-master))
     (seaweedfs-cluster-role-service
      config 'seaweedfs-filer "filer"
      (list "filer"
            "-master" master
            "-ip" ip "-ip.bind" ip
            "-port" (number->string filer-port)
            "-defaultStoreDir" (seaweedfs-cluster-directory config "filer"))
      #:requirement '(networking user-processes seaweedfs-master))
     (seaweedfs-cluster-role-service
      config 'seaweedfs-s3 "s3"
      (list "s3"
            "-filer" filer
            "-ip" ip "-ip.bind" ip
            "-port" (number->string s3-port))
      #:requirement '(networking user-processes seaweedfs-filer)))))

(define seaweedfs-cluster-service-type
  (service-type
   (name 'seaweedfs-cluster)
   (extensions
    (list
     (service-extension account-service-type seaweedfs-cluster-accounts)
     (service-extension shepherd-root-service-type
                        seaweedfs-cluster-shepherd-services)
     (service-extension activation-service-type
                        seaweedfs-cluster-activation)))
   (default-value (seaweedfs-cluster-configuration))
   (description "Run SeaweedFS as separate @command{weed master},
@command{weed volume}, @command{weed filer} and @command{weed s3} Shepherd
services under one unprivileged account.  The default addresses are loopback;
set @code{master-address} and @code{filer-address} when roles run on different
hosts.  State is kept under @file{/var/lib/seaweedfs}.")))


;;; `weed mini' is the batteries-included single-node mode: master, volume,
;;; filer, S3 and the admin UI in one process.  It is the simplest way to get
;;; the admin interface without a separate Node build.

(define-record-type* <seaweedfs-mini-configuration>
  seaweedfs-mini-configuration make-seaweedfs-mini-configuration
  seaweedfs-mini-configuration?
  (package seaweedfs-mini-configuration-package (default seaweedfs))
  (data-directory seaweedfs-mini-configuration-data-directory
                  (default "/var/lib/seaweedfs-mini"))
  (ip seaweedfs-mini-configuration-ip (default "127.0.0.1"))
  (master-port seaweedfs-mini-configuration-master-port (default 9333))
  (volume-port seaweedfs-mini-configuration-volume-port (default 8080))
  (filer-port seaweedfs-mini-configuration-filer-port (default 8888))
  (s3-port seaweedfs-mini-configuration-s3-port (default 8333))
  (admin-port seaweedfs-mini-configuration-admin-port (default 12535))
  (extra-arguments seaweedfs-mini-configuration-extra-arguments (default '()))
  (user seaweedfs-mini-configuration-user (default "seaweedfs"))
  (group seaweedfs-mini-configuration-group (default "seaweedfs"))
  (log-file seaweedfs-mini-configuration-log-file
            (default "/var/log/seaweedfs-mini.log")))

(define (seaweedfs-mini-accounts config)
  (seaweedfs-accounts
   (seaweedfs-configuration
    (package (seaweedfs-mini-configuration-package config))
    (data-directory (seaweedfs-mini-configuration-data-directory config))
    (user (seaweedfs-mini-configuration-user config))
    (group (seaweedfs-mini-configuration-group config)))))

(define (seaweedfs-mini-activation config)
  (seaweedfs-activation
   (seaweedfs-configuration
    (data-directory (seaweedfs-mini-configuration-data-directory config))
    (user (seaweedfs-mini-configuration-user config))
    (group (seaweedfs-mini-configuration-group config)))))

(define (seaweedfs-mini-shepherd-service config)
  (let* ((package (seaweedfs-mini-configuration-package config))
         (executable (file-append package "/bin/weed"))
         (data (seaweedfs-mini-configuration-data-directory config))
         (user (seaweedfs-mini-configuration-user config))
         (group (seaweedfs-mini-configuration-group config))
         (log (seaweedfs-mini-configuration-log-file config))
         (ip (seaweedfs-mini-configuration-ip config))
         (args
          (append
           (list "mini"
                 (string-append "-dir=" data)
                 (string-append "-ip=" ip)
                 (string-append "-ip.bind=" ip)
                 (string-append "-master.port="
                               (number->string
                                (seaweedfs-mini-configuration-master-port config)))
                 (string-append "-volume.port="
                               (number->string
                                (seaweedfs-mini-configuration-volume-port config)))
                 (string-append "-filer.port="
                               (number->string
                                (seaweedfs-mini-configuration-filer-port config)))
                 (string-append "-s3.port="
                               (number->string
                                (seaweedfs-mini-configuration-s3-port config)))
                 (string-append "-admin.port="
                               (number->string
                                (seaweedfs-mini-configuration-admin-port config)))
                 "-admin.ui=true"
                 "-master.volumeSizeLimitMB=1024"
                 "-volume.max=5"
                 "-master.telemetry=false")
           (seaweedfs-mini-configuration-extra-arguments config))))
    (list
     (shepherd-service
      (provision '(seaweedfs-mini))
     (requirement '(networking user-processes))
     (documentation "Run SeaweedFS mini with the admin UI.")
     (start
      #~(begin
          (use-modules (guix build utils))
          (let ((pw (getpwnam #$user))
                (gr (getgrnam #$group)))
            (mkdir-p #$data)
            (when (and pw gr)
              (chown #$data (passwd:uid pw) (group:gid gr)))
            (chmod #$data #o755))
          (make-forkexec-constructor
           (list #$executable #$@args)
           #:user #$user
           #:group #$group
           #:directory #$data
           #:log-file #$log)))
      (stop #~(make-kill-destructor))
      (respawn? #t)))))

(define seaweedfs-mini-service-type
  (service-type
   (name 'seaweedfs-mini)
   (extensions
    (list
     (service-extension account-service-type seaweedfs-mini-accounts)
     (service-extension shepherd-root-service-type
                        seaweedfs-mini-shepherd-service)
     (service-extension activation-service-type
                        seaweedfs-mini-activation)))
   (default-value (seaweedfs-mini-configuration))
   (description "Run SeaweedFS in the single-node @command{weed mini} mode:
master, volume, filer, S3 and the admin UI in one process under the
unprivileged @code{seaweedfs} account.  State is kept under
@file{/var/lib/seaweedfs-mini}; the admin UI listens on port 12535 by
default.")))
