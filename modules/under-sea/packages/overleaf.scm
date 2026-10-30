;;; The official overleaf/toolkit (docker-compose deployment of Overleaf
;;; CE with MongoDB / Redis / TeXLive from upstream images).

(define-module (under-sea packages overleaf)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system copy)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages containers)
  #:use-module (gnu packages docker)
  #:use-module (under-sea packages overleaf-pin))

(define-public overleaf-toolkit
  (package
    (name "overleaf-toolkit")
    (version %overleaf-toolkit-version)
    (source %overleaf-toolkit-source)
    (build-system copy-build-system)
    (arguments
     (list
      #:tests? #f
      #:install-plan
      #~'(("bin/" "share/overleaf-toolkit/bin")
          ("lib/" "share/overleaf-toolkit/lib")
          ("lib/config-seed/" "share/overleaf-toolkit/config"))))
    (home-page "https://github.com/overleaf/toolkit")
    (synopsis "Official deployment toolkit for Overleaf Community Edition")
    (description
     "The overleaf/toolkit repository provides the docker-compose based
deployment of Overleaf Community Edition together with MongoDB, Redis and
a full TeXLive, all supplied by the upstream container images.")
    (license license:agpl3+)))

(define overleaf-ctl-template
  (plain-file "overleaf-ctl.sh" "#!@bash@/bin/sh
set -eu

TK=\"@toolkit@/share/overleaf-toolkit\"
ROOT=\"${OVERLEAF_ROOT:-/var/lib/overleaf/toolkit}\"
# Runtime backend podman: docker calls go through shims in $ROOT/shims.

export PATH=\"$ROOT/shims:$ROOT/bin:@docker@/bin:@docker-compose@/bin:$PATH\"

ensure_root() {
  mkdir -p \"$ROOT\"
  rm -rf \"$ROOT/bin\"
  cp -r \"$TK/bin\" \"$ROOT/bin\"
  chmod -R u+w \"$ROOT/bin\"
  # Never touch lib/data (the container volumes).
  mkdir -p \"$ROOT/lib\"
  for entry in \"$TK\"/lib/*; do
    name=$(basename \"$entry\")
    [ \"$name\" = data ] && continue
    rm -rf \"$ROOT/lib/$name\"
    cp -r \"$entry\" \"$ROOT/lib/$name\"
  done
  chmod -R u+w \"$ROOT/lib\"
  if [ ! -f \"$ROOT/config/overleaf.rc\" ]; then
    mkdir -p \"$ROOT/config\"
    cp -r \"$TK/config/\"* \"$ROOT/config/\"
    chmod u+w \"$ROOT/config/\"*
    echo \"overleaf-ctl: generated initial config in $ROOT/config\"
    echo \"overleaf-ctl: edit config/overleaf.rc and config/variables.env,\"
    echo \"overleaf-ctl: then re-run: overleaf-ctl up\"
    exit 0
  fi
}

cmd=${1:-help}
shift 2>/dev/null || true

case \"$cmd\" in
  init|upgrade)
    ensure_root
    echo \"overleaf-ctl: toolkit files refreshed in $ROOT\"
    ;;
  up|start|stop|down|logs|pull|shell|doctor|mongo|images|backup-config)
    ensure_root
    cd \"$ROOT\"
    exec ./bin/\"$cmd\" \"$@\"
  ;;
  *)
    echo \"usage: overleaf-ctl {init|upgrade|up|start|stop|down|logs|pull|shell|doctor|mongo|images|backup-config} [args]\"
    ;;
esac
"))

(define-public overleaf-ctl
  (package
    (name "overleaf-ctl")
    (version (package-version overleaf-toolkit))
    (source overleaf-ctl-template)
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan
      #~'(("overleaf-ctl.sh" "bin/overleaf-ctl"))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'chmod
            (lambda _
              (chmod "overleaf-ctl.sh" #o644)))
          (add-before 'install 'substitute-paths
            (lambda* (#:key inputs #:allow-other-keys)
              (substitute* "overleaf-ctl.sh"
                (("@bash@") (search-input-file inputs "bin/bash"))
                (("@toolkit@") (assoc-ref inputs "overleaf-toolkit"))
                (("@docker@") (string-append
                               (assoc-ref inputs "docker-cli") "/bin"))
                (("@docker-compose@")
                 (string-append (assoc-ref inputs "docker-compose") "/bin")))
              (chmod "overleaf-ctl.sh" #o555))))))
    (inputs (list bash-minimal overleaf-toolkit docker-cli docker-compose))
    (home-page "https://github.com/overleaf/toolkit")
    (synopsis "Control script for a self-hosted Overleaf deployment")
    (description
     "overleaf-ctl manages an Overleaf Community Edition deployment rooted
at OVERLEAF_ROOT (default /var/lib/overleaf/toolkit): first use generates
config/ from the packaged templates, later invocations forward to the
toolkit's docker-compose scripts (up, stop, logs, ...).  The upgrade
subcommand refreshes the toolkit scripts from the newly installed package
while keeping config/ and container data.")
    (license license:agpl3+)))
