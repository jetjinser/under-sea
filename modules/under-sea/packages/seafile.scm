;;; Seafile sync client daemon and its libsearpc dependency.
(define-module (under-sea packages seafile)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages libevent)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages password-utils)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages sqlite)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages web)
  #:use-module (under-sea packages seafile-pin)
  #:use-module (under-sea packages seafile-lock))

(define %python-site-packages
  (string-append "/lib/python"
                 (version-major+minor (package-version python))
                 "/site-packages"))

(define-public libsearpc
  (package
    (name "libsearpc")
    (version %libsearpc-client-version)
    (properties '((upstream-github "haiwen/libsearpc")))
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://codeload.github.com/haiwen/libsearpc/tar.gz/refs/tags/v"
             version))
       (file-name (string-append "libsearpc-" version ".tar.gz"))
       (sha256
        (base32
         %libsearpc-client-hash))))
    (build-system gnu-build-system)
    (native-inputs
     `(("autoconf" ,autoconf)
       ("automake" ,automake)
       ("libtool" ,libtool)
       ("pkg-config" ,pkg-config)
       ("python" ,python)
       ("glib:bin" ,glib "bin")))
    (inputs
     `(("glib" ,glib)
       ("jansson" ,jansson)))
    (propagated-inputs
     (list python-future))
    (arguments
     (list
      #:tests? #f
      #:configure-flags #~(list "--disable-compile-demo")
      #:phases
      #~(modify-phases %standard-phases
          (replace 'bootstrap
            (lambda _
              (invoke "bash" "autogen.sh")))
          (add-after 'install 'patch-codegen-shebang
            (lambda _
              ;; patch-shebangs cannot resolve the bare "python" interpreter.
              (substitute* (string-append #$output "/bin/searpc-codegen.py")
                (("#!/usr/bin/env python")
                 (string-append "#!" #$(file-append python "/bin/python3")))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/haiwen/libsearpc")
    (synopsis "Simple C RPC library used by Seafile")
    (description
     "libsearpc is a simple C RPC library based on GObject and JSON.  It
provides the C RPC runtime, code-generation helpers, and the pure-Python
@code{pysearpc} modules used by the Seafile client.")
    (license license:asl2.0)))

;;; libsearpc 3.3 adds the epoll-based named-pipe server API used by
;;; seafile-server 14.x; the 3.2 release is kept for the 9.0 client.
(define-public libsearpc-3.3
  (package
    (inherit libsearpc)
    (name "libsearpc-3.3")
    (version %libsearpc-server-version)
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://codeload.github.com/haiwen/libsearpc/tar.gz/"
             %libsearpc-server-commit))
       (file-name "libsearpc-3.3.0.tar.gz")
       (sha256
        (base32 %libsearpc-server-hash))))))


(define-public seafile
  (package
    (name "seafile")
    (version %seafile-version)
    (properties '((upstream-github "haiwen/seafile")))
    (source %seafile-source)
    (build-system gnu-build-system)
    (native-inputs
     `(("autoconf" ,autoconf)
       ("automake" ,automake)
       ("intltool" ,intltool)
       ("libtool" ,libtool)
       ("pkg-config" ,pkg-config)
       ("vala" ,vala)
       ("glib:bin" ,glib "bin")))
    (inputs
     `(("argon2" ,argon2)
       ("bash-minimal" ,bash-minimal)
       ("curl" ,curl)
       ("glib" ,glib)
       ("jansson" ,jansson)
       ("libevent" ,libevent)
       ("libsearpc" ,libsearpc)
       ("libwebsockets" ,libwebsockets)
       ("openssl" ,openssl)
       ("python" ,python)
       ("sqlite" ,sqlite)
       ("util-linux:lib" ,util-linux "lib")
       ("zlib" ,zlib)))
    (arguments
     (list
      #:tests? #f
      #:configure-flags #~(list "--with-python3" "--enable-ws")
      #:phases
      #~(modify-phases %standard-phases
          (replace 'bootstrap
            (lambda _
              (invoke "bash" "autogen.sh")))
          (add-after 'unpack 'patch-libwebsockets
            (lambda _
              ;; libwebsockets exposes the SOCKS5 proxy fields only when it
              ;; is built with SOCKS5 support.  Guix's build does not enable
              ;; that feature, so keep the assignments conditional instead of
              ;; failing to compile.
              (substitute* "daemon/notif-mgr.c"
                (("info\\.socks_proxy_address = socks_proxy_addr;")
                 (string-append "#if defined(LWS_WITH_SOCKS5)\n"
                                "info.socks_proxy_address = socks_proxy_addr;"))
                ((": 1080\\);")
                 ": 1080);\n#endif"))))
          (add-after 'install 'wrap-seaf-cli
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (searpc (assoc-ref inputs "libsearpc"))
                     (future (assoc-ref inputs "python-future"))
                     (site (string-append out #$%python-site-packages))
                     (searpc-site
                      (string-append searpc #$%python-site-packages))
                     (future-site
                      (string-append future #$%python-site-packages)))
                (wrap-program (string-append out "/bin/seaf-cli")
                  `("PYTHONPATH" ":" prefix (,site ,searpc-site ,future-site))
                  `("PATH" ":" prefix (,(string-append out "/bin")))))))
          (add-after 'wrap-seaf-cli 'check-installed
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (daemon (string-append out "/bin/seaf-daemon"))
                     (cli (string-append out "/bin/seaf-cli")))
                ;; seaf-daemon's --help/--version exit with status 1, so
                ;; check the usage text rather than the exit status.
                (invoke "bash" "-c"
                        (string-append daemon
                                       " --help 2>&1 | grep -q 'usage: seaf-daemon'"))
                (invoke "bash" "-c"
                        (string-append cli
                                       " --help 2>&1 | grep -q 'usage:.*seaf-cli'"))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/haiwen/seafile")
    (synopsis "File synchronization client daemon")
    (description
     "Seafile is a file synchronization and sharing client.  This package
provides the @command{seaf-daemon} sync daemon and the @command{seaf-cli}
command-line interface, together with the Python client modules they use.")
    (license license:gpl2)))
