;;; Optional system integration for the Autodesk Moldflow Insight thin-client:
;;; run the Simulation Compute Manager (SCM) daemon.  Licensing is external
;;; (Autodesk Licensing Service); this service only wires the daemon and its
;;; environment.  Installing the package does not start anything.
(define-module (under-sea services moldflow)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (under-sea packages moldflow)
  #:export (moldflow-scm-configuration
            moldflow-scm-configuration?
            moldflow-scm-service-type))

(define-record-type* <moldflow-scm-configuration>
  moldflow-scm-configuration make-moldflow-scm-configuration
  moldflow-scm-configuration?
  (moldflow moldflow-scm-configuration-moldflow (default moldflow-insight-thinclient))
  ;; Writable state (SCM data path); kept outside the store.
  (state-directory moldflow-scm-configuration-state-directory
                   (default "/var/lib/moldflow-scm"))
  ;; "host:port" of the Autodesk network license server, or #f for named-user
  ;; (cloud) licensing via the ADLM thin-client environment.
  (license-server moldflow-scm-configuration-license-server (default #f))
  ;; PID file for the forking daemon.
  (pid-file moldflow-scm-configuration-pid-file (default "/run/moldflow-scm.pid")))

(define (moldflow-scm-environment config)
  (let* ((moldflow (moldflow-scm-configuration-moldflow config))
         (home (file-append moldflow "/autodesk-moldflow-insight-2027"))
         (scm (file-append moldflow "/opt/Autodesk/simulation-compute2")))
    (append
     (list
      #~(string-append "AUTODESK_ADLM_THINCLIENT_ENV="
                       #$moldflow "/AdlmThinClientCustomEnv.xml")
      #~(string-append "MFSYN_HOME=" #$home)
      #~(string-append "SCM_BASE=" #$scm "/bin")
      #~(string-append "SCM_DATAPATH="
                       #$(moldflow-scm-configuration-state-directory config))
      #~(string-append "MFSYN_TMP="
                       #$(moldflow-scm-configuration-state-directory config) "/tmp"))
     (if (moldflow-scm-configuration-license-server config)
         (list #~(string-append "ADSK_SERVICE_ADDRESS="
                                #$(moldflow-scm-configuration-license-server config)))
         '()))))

(define (moldflow-scm-shepherd-service config)
  (let* ((moldflow (moldflow-scm-configuration-moldflow config))
         (executable (file-append moldflow
                                  "/opt/Autodesk/simulation-compute2/bin/SimulationCompute"))
         (state (moldflow-scm-configuration-state-directory config))
         (pid (moldflow-scm-configuration-pid-file config)))
    (list
     (shepherd-service
      (provision '(moldflow-scm))
      (requirement '(networking))
      (documentation "Run the Autodesk Simulation Compute Manager daemon.")
      (start #~(make-forkexec-constructor
                (list #$executable "--daemon" "--pidfilename" #$pid)
                #:directory #$state
                #:environment-variables
                (append (list #$@(moldflow-scm-environment config))
                        (default-environment-variables))
                #:log-file "/var/log/moldflow-scm.log"))
      (stop #~(make-kill-destructor))))))

(define (moldflow-scm-activation config)
  (let ((state (moldflow-scm-configuration-state-directory config)))
    #~(begin
        (use-modules (guix build utils))
        (mkdir-p #$state)
        (chmod #$state #o700)
        (mkdir-p #$(string-append state "/tmp"))
        (chmod #$(string-append state "/tmp") #o700))))

(define moldflow-scm-service-type
  (service-type
   (name 'moldflow-scm)
   (extensions
    (list
     (service-extension shepherd-root-service-type moldflow-scm-shepherd-service)
     (service-extension activation-service-type moldflow-scm-activation)))
   (default-value (moldflow-scm-configuration))
   (description "Run the Autodesk Simulation Compute Manager (SCM) daemon for
the Moldflow Insight thin-client.  Requires a writable state directory and,
for checked-out licenses, either an Autodesk network license server or a
configured named-user (cloud) entitlement.")))
