#!@bash@/bin/sh
set -eu

TK="@toolkit@/share/overleaf-toolkit"
ROOT="${OVERLEAF_ROOT:-/var/lib/overleaf/toolkit}"
export PATH="@docker@/bin:@docker-compose@/bin:$PATH"

ensure_root() {
  mkdir -p "$ROOT"
  rm -rf "$ROOT/bin" "$ROOT/lib"
  cp -r "$TK/bin" "$TK/lib" "$ROOT/"
  chmod -R u+w "$ROOT/bin" "$ROOT/lib"
  if [ ! -f "$ROOT/config/overleaf.rc" ]; then
    mkdir -p "$ROOT/config"
    cp -r "$TK/share/overleaf-toolkit/config/"* "$ROOT/config/"
    chmod u+w "$ROOT/config/"*
    echo "overleaf-ctl: generated initial config in $ROOT/config"
    echo "overleaf-ctl: edit config/overleaf.rc and config/variables.env,"
    echo "overleaf-ctl: then re-run: overleaf-ctl up"
    exit 0
  fi
}

cmd=${1:-help}
shift 2>/dev/null || true

case "$cmd" in
  init|upgrade)
    ensure_root
    echo "overleaf-ctl: toolkit files refreshed in $ROOT"
    ;;
  up|start|stop|down|logs|pull|shell|doctor|mongo|images|backup-config)
    ensure_root
    cd "$ROOT"
    exec ./bin/"$cmd" "$@"
  ;;
  *)
    echo "usage: overleaf-ctl {init|upgrade|up|start|stop|down|logs|pull|shell|doctor|mongo|images|backup-config} [args]"
    ;;
esac
