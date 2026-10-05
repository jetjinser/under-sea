;;; Reuse one private audio/integration runtime behind both source interfaces.
(define-module (under-sea packages hermes-audio-interfaces)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system trivial)
  #:use-module (gnu packages node)
  #:use-module (gnu packages bash)
  #:use-module (under-sea packages hermes-audio)
  #:use-module (under-sea packages hermes-node)
  #:use-module (under-sea packages hermes-tools))

(define-public hermes-agent-audio-interfaces
  (package
    (inherit hermes-agent-audio)
    (name "hermes-agent-audio-interfaces")
    (source #f)
    (build-system trivial-build-system)
    (native-inputs '())
    (inputs (list hermes-agent-audio node bash-minimal hermes-node-tui hermes-web-assets
                  hermes-linux-skill-tools))
    (arguments
     (list
      #:modules '((guix build utils) (ice-9 ftw))
      #:builder
      #~(begin
          (use-modules (guix build utils) (ice-9 ftw))
          (let* ((bin (string-append #$output "/bin"))
                 (share (string-append #$output "/share/hermes-agent"))
                 (runtime #$hermes-agent-audio)
                 (audio-bin (string-append runtime "/bin"))
                 (tools #$(file-append hermes-linux-skill-tools "/bin"))
                 (python (string-append audio-bin "/hermes-python"))
                 (tui #$(file-append hermes-node-tui "/share/hermes-node-tui/entry.js"))
                 (web #$(file-append hermes-web-assets "/share/hermes-web")))
            (unless (and (file-exists? python) (file-exists? tui)
                         (file-exists? (string-append web "/index.html")))
              (error "Required source-built component resource missing"))
            (mkdir-p bin)
            (mkdir-p share)
            (for-each
             (lambda (name)
               (let ((program (string-append bin "/" name)))
                 (call-with-output-file program
                   (lambda (port)
                     (format port "#!~a\nexport PATH=~s${PATH:+:$PATH}\nexec ~s \"$@\"\n"
                             #$(file-append bash-minimal "/bin/sh") tools
                             (string-append audio-bin "/" name))))
                 (chmod program #o755)))
             (scandir audio-bin (lambda (name) (not (string-prefix? "." name)))))
            (symlink web (string-append share "/web"))
            (symlink tui (string-append share "/tui-entry.js"))
            (symlink (string-append runtime "/share/hermes-agent")
                     (string-append share "/runtime-resources"))
            (call-with-output-file (string-append bin "/hermes-tui")
              (lambda (port)
                (format port "#!~a\nexport PATH=~s${PATH:+:$PATH}\nexport HERMES_CWD=\"${HERMES_CWD:-$PWD}\"\nexport HERMES_PYTHON=~s\nexport HERMES_PYTHON_SRC_ROOT=~s\nexport HERMES_BIN=~s\nexec ~s ~s \"$@\"\n"
                        #$(file-append bash-minimal "/bin/sh") tools python
                        (string-append runtime "/lib/python3.12/site-packages")
                        (string-append audio-bin "/hermes")
                        #$(file-append node "/bin/node") tui)))
            (chmod (string-append bin "/hermes-tui") #o755)
            (call-with-output-file (string-append bin "/hermes-dashboard")
              (lambda (port)
                (format port "#!~a\nexport PATH=~s${PATH:+:$PATH}\nexport HERMES_WEB_DIST=~s\nexec ~s dashboard \"$@\"\n"
                        #$(file-append bash-minimal "/bin/sh") tools web
                        (string-append audio-bin "/hermes"))))
            (chmod (string-append bin "/hermes-dashboard") #o755)
            (call-with-output-file (string-append share "/interface-runtime.scm")
              (lambda (port)
                (write (list (cons 'runtime runtime) (cons 'python python)
                             (cons 'tui tui) (cons 'web web) (cons 'skill-tools tools)
                             (cons 'functional-validation 'deferred)) port)
                (newline port)))))))
    (synopsis "Hermes audio and integrations with matching TUI and dashboard runtime")
    (description "This component combination connects Hermes's source-built
Node TUI and dashboard assets to the same private audio and integration Python
runtime and fixed common Linux skill CLI resources. It reuses independent
component outputs. Desktop, browser tools,
specialist skills, models and external services remain separate. Functional
verification is deferred until the overall component plan is built.")))
