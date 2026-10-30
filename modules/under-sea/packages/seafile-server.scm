;;; Seafile Server Core - the C daemon that provides the RPC/HTTP APIs used by
;;; Seahub and the desktop clients.  The web front-end (seahub) is a separate
;;; upstream project and is not part of this package.

(define-module (under-sea packages seafile-server)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages backup)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages databases)
  #:use-module (gnu packages gettext)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages libevent)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages password-utils)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages serialization)
  #:use-module (gnu packages sqlite)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages web)
  #:use-module (under-sea packages seafile)
  #:use-module (under-sea packages seafile-server-pin))

(define-public seafile-server
  (package
    (name "seafile-server")
    (version %seafile-server-version)
    (source %seafile-server-source)
    (build-system gnu-build-system)
    (native-inputs (list autoconf automake libtool pkg-config gettext-minimal
                         which python vala))
    (propagated-inputs (list libsearpc-3.3))
    (inputs (list jansson
                  libevent
                  openssl
                  sqlite
                  curl
                  glib
                  zlib
                  argon2
                  libjwt
                  hiredis
                  libarchive
                  util-linux))
    (arguments
     (list
      #:tests? #f
      #:configure-flags
      #~(list "--disable-fuse"
              "--disable-httpserver")
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'install 'smoke
            (lambda _
              (invoke (string-append #$output "/bin/seaf-fsck")
                      "--help"))))))
    (synopsis "Seafile server core daemon")
    (description "This package builds the Seafile server core, the C daemon
that provides the RPC and HTTP APIs used by Seahub and the desktop clients.
The optional FUSE and bundled HTTP server are disabled; the Python
`seafile`/`seaserv` bindings are installed and libsearpc is propagated for
them.  The separate Seahub web front-end is not included.")
    (home-page "https://www.seafile.com/")
    (license license:agpl3)))
