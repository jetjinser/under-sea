#!/usr/bin/env bash
# Focused smoke matrix for the standalone packages added by the
# standalone-packages plan.  It avoids the long Hermes/agent-browser matrices
# and the stuck substitute queries in the full phase-7 run.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GVX=(guix time-machine -C channels.scm --)
SUBSTITUTE_FLAGS=()
if [ -n "${VERIFY_SUBSTITUTE_URLS:-}" ]; then
  SUBSTITUTE_FLAGS=(--substitute-urls="$VERIFY_SUBSTITUTE_URLS")
fi

pass=0; fail=0
declare -a rows
resolve() { "${GVX[@]}" build "${SUBSTITUTE_FLAGS[@]}" -L "$ROOT/modules" -e "$1" 2>/dev/null | tail -1; }
check() { # name cmd...
  local name="$1"; shift
  if "$@" >/tmp/verify-standalone.out 2>&1; then
    rows+=("PASS|$name"); pass=$((pass+1))
  else
    rows+=("FAIL|$name: $(tail -1 /tmp/verify-standalone.out)"); fail=$((fail+1))
  fi
}

SF="$(resolve '(@ (under-sea packages seafile) seafile)')"
[ -n "$SF" ] && check "seafile CLI" "$SF/bin/seaf-cli" --help

SFS="$(resolve '(@ (under-sea packages seafile-server) seafile-server)')"
[ -n "$SFS" ] && check "seafile-server" test -x "$SFS/bin/seaf-server"

REA="$(resolve '(@ (under-sea packages rea) rea)')"
[ -n "$REA" ] && check "rea" "$REA/bin/rea" --version

SW="$(resolve '(@ (under-sea packages seaweedfs) seaweedfs)')"
[ -n "$SW" ] && check "seaweedfs" "$SW/bin/weed" version

SWR="$(resolve '(@ (under-sea packages seaweedfs) seaweedfs-rocksdb)')"
[ -n "$SWR" ] && check "seaweedfs rocksdb" bash -c "\"$SWR/bin/weed\" filer --help 2>&1 | grep -q rocksdb"

SWF="$(resolve '(@ (under-sea packages seaweedfs) seaweedfs-full)')"
[ -n "$SWF" ] && check "seaweedfs full stores" bash -c "for s in rocksdb sqlite tikv ydb tarantool; do \"$SWF/bin/weed\" filer --help 2>&1 | grep -q \"\$s\" || exit 1; done"

MAR="$(resolve '(@ (under-sea packages marimo) marimo)')"
[ -n "$MAR" ] && check "marimo" "$MAR/bin/marimo" --help
MARX="$(resolve '(@ (under-sea packages marimo) marimo-with-extras)')"
[ -n "$MARX" ] && check "marimo extras" "$MARX/bin/marimo" --help
LENS="$(resolve '(@ (under-sea packages marimo-lens) marimo-lens)')"
[ -n "$LENS" ] && check "marimo-lens module" test -d "$LENS/lib/python3.12/site-packages/marimo_lens"

PAI="$(resolve '(@ (under-sea packages pydantic-ai) python-pydantic-ai-slim)')"
[ -n "$PAI" ] && check "pydantic-ai module" test -d "$PAI/lib/python3.12/site-packages/pydantic_ai"

LORO="$(resolve '(@ (under-sea packages loro) loro)')"
[ -n "$LORO" ] && check "loro module" test -d "$LORO/lib/python3.12/site-packages/loro"

OC1="$(resolve '(@ (under-sea packages opencode-v1) opencode-v1)')"
[ -n "$OC1" ] && check "opencode v1" "$OC1/bin/opencode-v1" --version

OC2="$(resolve '(@ (under-sea packages opencode-v2) opencode-v2)')"
[ -n "$OC2" ] && check "opencode v2" "$OC2/bin/opencode-v2" --version

echo "=== standalone package verification ==="
for r in "${rows[@]}"; do printf '%-6s %s\n' "${r%%|*}" "${r#*|}"; done
echo "--- pass=$pass fail=$fail ---"
[ "$fail" -eq 0 ]
