;;; Hermes's source-available Linux audio and integration runtime.
(define-module (under-sea packages hermes-audio)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages video)
  #:use-module (under-sea packages hermes)
  #:use-module (under-sea packages hermes-audio-native)
  #:use-module ((under-sea packages hermes-full-audio-lock) #:prefix audio:))

(define-public hermes-agent-audio
  (let ((base
         (make-hermes-package
          "hermes-agent-audio"
          audio:%hermes-python-sources audio:%hermes-crate-sources #t
          audio:%hermes-git-sources
          (append
           (resolve-hermes-python-components audio:%hermes-python-component-requirements)
           (list (list "pilk" "0.2.4" (gexp-input python-pilk-for-hermes)))))))
    (package
      (inherit base)
      (arguments
       (substitute-keyword-arguments (package-arguments base)
         ((#:phases phases)
          #~(modify-phases #$phases
              (add-after 'install 'install-audio-boundaries
                (lambda _
                  (let ((share (string-append #$output "/share/hermes-agent")))
                    (call-with-output-file (string-append share "/source-unavailable-components.scm")
                      (lambda (port)
                        (write '#$(identity audio:%hermes-source-unavailable-components) port)
                        (newline port))))
                  (for-each
                    (lambda (program)
                      (wrap-program program
                        '("PATH" ":" prefix (#$(file-append ffmpeg "/bin")))))
                    (find-files (string-append #$output "/bin")
                                "^(hermes|hermes-agent|hermes-python|hermes-acp)$"))))))))
      (synopsis "Hermes with source-built Linux audio and integration components")
      (description "Hermes Agent provides an AI assistant with cloud integrations,
local speech recognition and source-built audio engines.  This runtime includes
MCP/ACP and the selected cloud, gateway, memory and monitoring dependencies.
Models and service credentials require configuration.  The Porcupine native
engine is excluded because its corresponding source is unavailable; the package
records that remaining component explicitly.  Node and desktop interfaces are
separate components."))))
