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
            seaweedfs-service-type))

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
