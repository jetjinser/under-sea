;;; Minimal operating-system declaration that instantiates the under-sea
;;; Hermes gateway service, so VM system tests can exercise it under a real
;;; init (Shepherd) without needing host privileges.  A mock
;;; OpenAI-compatible model server runs alongside it for the offline E2E
;;; system test (full agent turns without a real LLM backend).

(define-module (under-sea system hermes)
  #:use-module (gnu)
  #:use-module (gnu system)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu services shepherd)
  #:use-module (guix packages)
  #:use-module (guix build-system trivial)
  #:use-module (under-sea gexp)
  #:use-module (under-sea packages hermes)
  #:use-module (under-sea services hermes)
  #:export (%under-sea-hermes-service
            %under-sea-hermes-mock-model-service
            %under-sea-hermes-os))

;; Satisfies the gateway's (networking) requirement without touching real
;; interfaces; safe inside a VM that shares the host network namespace.
(define %under-sea-hermes-networking
  (service static-networking-service-type
           (list (static-networking (addresses '())
                                    (routes '())
                                    (requirement '())
                                    (provision '(networking))))))

(define %under-sea-hermes-service
  (service hermes-service-type))

;; Offline mock OpenAI-compatible model server for the E2E system test: the
;; gateway's model provider points at it, so full agent turns run without a
;; real LLM backend.
(define hermes-e2e-scripts
  (package
    (name "hermes-e2e-scripts")
    (version "0")
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder #~(begin
                    (use-modules (guix build utils))
                    (let ((out (assoc-ref %outputs "out")))
                      (mkdir-p (string-append out "/share/hermes-e2e"))
                      (copy-file #$(under-sea-script "mock-openai-model.py")
                                 (string-append out
                                                "/share/hermes-e2e/mock-openai-model.py"))
                      (copy-file #$(under-sea-script "hermes-e2e-driver.py")
                                 (string-append out
                                                "/share/hermes-e2e/hermes-e2e-driver.py"))))))
    (home-page "https://github.com/NousResearch/hermes-agent")
    (synopsis "Offline E2E scripts for the Hermes gateway VM test")
    (description "The mock OpenAI-compatible model server and the offline E2E
driver for the Hermes gateway VM system test.")
    (license license:expat)))

(define %under-sea-hermes-mock-model-service
  (simple-service 'hermes-e2e-mock-model shepherd-root-service-type
                  (list (shepherd-service
                         (provision '(hermes-mock-model))
                         (requirement '())
                         (start #~(make-forkexec-constructor
                                   (list #$(file-append hermes-agent
                                                        "/bin/hermes-python")
                                         #$(file-append hermes-e2e-scripts
                                                        "/share/hermes-e2e/mock-openai-model.py"))
                                   #:log-file
                                   "/var/log/hermes-mock-model.log"))))))

(define-public %under-sea-hermes-os
  (operating-system
    (host-name "under-sea")
    (timezone "UTC")
    (locale "en_US.utf8")
    (bootloader (bootloader-configuration
                 (bootloader grub-bootloader)
                 (targets '("/dev/sdX"))))
    (file-systems (cons (file-system
                          (device (file-system-label "under-sea-root"))
                          (mount-point "/")
                          (type "ext4"))
                        %base-file-systems))
    (users (cons (user-account
                  (name "tester")
                  (comment "under-sea test user")
                  (group "users")
                  (supplementary-groups '("wheel")))
                 %base-user-accounts))
    (packages (cons* hermes-e2e-scripts hermes-agent %base-packages))
    (services (cons* %under-sea-hermes-service
                     %under-sea-hermes-mock-model-service
                     %under-sea-hermes-networking
                     %base-services))))
