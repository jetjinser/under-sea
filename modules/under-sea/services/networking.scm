;;; Optional system integration; installing packages does not start daemons.
(define-module (under-sea services networking)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (under-sea packages dae)
  #:use-module (under-sea packages sing-box)
  #:export (dae-configuration dae-configuration? dae-service-type
            sing-box-configuration sing-box-configuration? sing-box-service-type))

(define-record-type* <dae-configuration>
  dae-configuration make-dae-configuration dae-configuration?
  (package dae-configuration-package (default dae))
  ;; Configuration remains outside the store so credentials need not enter it.
  (config-file dae-configuration-config-file (default "/etc/dae/config.dae"))
  (state-directory dae-configuration-state-directory (default "/var/lib/dae"))
  (asset-directory dae-configuration-asset-directory (default #f)))

(define-record-type* <sing-box-configuration>
  sing-box-configuration make-sing-box-configuration sing-box-configuration?
  (package sing-box-configuration-package (default sing-box))
  (config-file sing-box-configuration-config-file (default "/etc/sing-box/config.json"))
  (state-directory sing-box-configuration-state-directory (default "/var/lib/sing-box")))

(define (daemon-service name executable arguments state environment)
  (list
   (shepherd-service
    (provision (list name))
    (requirement '(networking))
    (documentation "Run the configured proxy daemon.")
    ;; These daemons need kernel networking privileges for TUN/eBPF. The
    ;; configuration controls whether those functions are actually enabled.
    (start #~(make-forkexec-constructor
              (list #$executable #$@arguments)
              #:directory #$state
              #:environment-variables
              (append (list #$@environment) (default-environment-variables))
              #:log-file #$(string-append "/var/log/" (symbol->string name) ".log")))
    (stop #~(make-kill-destructor)))))

(define (state-directory-activation directory)
  #~(begin
      (use-modules (guix build utils))
      (mkdir-p #$directory)
      (chmod #$directory #o700)))

(define (dae-config-file-name directory)
  ;; dae refuses to read a configuration that is world-readable, so it is run
  ;; against a private copy placed in the state directory at activation.
  (string-append directory "/config.dae"))

(define (dae-config-activation directory config-file)
  #~(begin
      (use-modules (guix build utils))
      (mkdir-p #$directory)
      (chmod #$directory #o700)
      (let ((source #$config-file)
            (target #$(dae-config-file-name directory)))
        (when (file-exists? source)
          (copy-file source target)
          (chmod target #o600)))))

(define dae-service-type
  (service-type
   (name 'dae)
   (extensions
    (list
     (service-extension
      shepherd-root-service-type
      (lambda (config)
        (daemon-service
         'dae (file-append (dae-configuration-package config) "/bin/dae")
         (list "run" "--config"
               (dae-config-file-name (dae-configuration-state-directory config))
               "--disable-pidfile" "--disable-sudo")
         (dae-configuration-state-directory config)
         (if (dae-configuration-asset-directory config)
             (list #~(string-append "DAE_LOCATION_ASSET="
                                    #$(dae-configuration-asset-directory config)))
             '()))))
     (service-extension activation-service-type
                        (lambda (config)
                          (dae-config-activation
                           (dae-configuration-state-directory config)
                           (dae-configuration-config-file config))))))
   (default-value (dae-configuration))
   (description "Run dae with an explicit configuration and optional geographic rule data.")))

(define sing-box-service-type
  (service-type
   (name 'sing-box)
   (extensions
    (list
     (service-extension
      shepherd-root-service-type
      (lambda (config)
        (daemon-service
         'sing-box (file-append (sing-box-configuration-package config) "/bin/sing-box")
         (list "run" "-c" (sing-box-configuration-config-file config)
               "-D" (sing-box-configuration-state-directory config))
         (sing-box-configuration-state-directory config) '())))
     (service-extension activation-service-type
                        (lambda (config)
                          (state-directory-activation
                           (sing-box-configuration-state-directory config))))))
   (default-value (sing-box-configuration))
   (description "Run sing-box with an explicit configuration and persistent state directory.")))
