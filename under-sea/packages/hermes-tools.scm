;;; Optional authored-skill CLI resources; no services are started here.
(define-module (under-sea packages hermes-tools)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system trivial)
  #:use-module (gnu packages imagemagick)
  #:use-module (gnu packages video)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages node)
  #:use-module (gnu packages pdf)
  #:use-module (gnu packages libreoffice)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages lsof)
  #:use-module (gnu packages pulseaudio)
  #:use-module (gnu packages docker)
  #:use-module (gnu packages build-tools))

(define %skill-programs
  (list
   (list "convert" (file-append imagemagick "/bin/convert"))
   (list "ffmpeg" (file-append ffmpeg "/bin/ffmpeg"))
   (list "ffprobe" (file-append ffmpeg "/bin/ffprobe"))
   (list "git" (file-append git "/bin/git"))
   (list "node" (file-append node "/bin/node"))
   (list "npm" (file-append node "/bin/npm"))
   (list "pdftocairo" (file-append poppler "/bin/pdftocairo"))
   (list "pdftoppm" (file-append poppler "/bin/pdftoppm"))
   (list "soffice" (file-append libreoffice "/bin/soffice"))
   (list "ss" (file-append iproute "/sbin/ss"))
   (list "netstat" (file-append net-tools "/bin/netstat"))
   (list "lsof" (file-append lsof "/bin/lsof"))
   (list "pactl" (file-append pulseaudio "/bin/pactl"))
   (list "paplay" (file-append pulseaudio "/bin/paplay"))
   (list "docker" (file-append docker-cli "/bin/docker"))
   (list "uv" (file-append uv "/bin/uv"))))

(define-public hermes-linux-skill-tools
  (package
    (name "hermes-linux-skill-tools")
    (version "0.21.5")
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let ((bin (string-append #$output "/bin"))
                (share (string-append #$output "/share/hermes-agent")))
            (mkdir-p bin)
            (mkdir-p share)
            (for-each
             (lambda (entry)
               (unless (file-exists? (cadr entry))
                 (error "Missing fixed skill CLI resource" entry))
               (symlink (cadr entry) (string-append bin "/" (car entry))))
             '#$%skill-programs)
            (call-with-output-file (string-append share "/skill-cli-resources.scm")
              (lambda (port)
                (write '#$%skill-programs port)
                (newline port)))
            (call-with-output-file (string-append share "/external-conditions.txt")
              (lambda (port)
                (display "Optional common Linux skill tools only.\nDocker requires a separately configured daemon and socket access.\nPulseAudio clients require a user audio session and devices.\nModel files, service credentials and specialist clients remain separate.\nHermes runtime integration and functional validation are pending.\n" port)))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/NousResearch/hermes-agent")
    (synopsis "Fixed common Linux command resources for Hermes skills")
    (description "This optional resource package exposes common skill CLI
programs from the pinned Guix channel's source-defined packages.  It creates
only references to their original outputs, preserving their libraries and
licensing.  Services, user configuration, models and credentials are separate.
It does not exhaust the dynamically discovered plugin dependency inventory.")
    (license license:expat)))
