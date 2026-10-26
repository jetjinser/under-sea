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
  #:use-module (under-sea packages seafile))

(define-public seafile-server
  (package
    (name "seafile-server")
    (version "14.0.9")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://codeload.github.com/haiwen/seafile-server/tar.gz/"
             "refs/tags/v" version "-server"))
       (file-name (string-append "seafile-server-" version ".tar.gz"))
       (sha256
        (base32 "0jjq5cr29cc7n7h317lhqi8g9al6gvrlz6i621xj9p1qva81fg13"))))
    (build-system gnu-build-system)
    (native-inputs (list autoconf automake libtool pkg-config gettext-minimal
                         which python vala))
    (inputs (list libsearpc-3.3
                  jansson
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
              "--disable-httpserver")))
    (synopsis "Seafile server core daemon")
    (description "This package builds the Seafile server core, the C daemon
that provides the RPC and HTTP APIs used by Seahub and the desktop clients.
The optional FUSE, Python bindings and bundled HTTP server are disabled; the
separate Seahub web front-end is not included.")
    (home-page "https://www.seafile.com/")
    (license license:agpl3)))
