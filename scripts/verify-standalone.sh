#!/usr/bin/env bash
# Focused smoke matrix for the standalone packages added by the
# standalone-packages plan.  It avoids the long Hermes/agent-browser matrices
# and the stuck substitute queries in the full phase-7 run.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
. "$ROOT/scripts/verify-common.sh"

GVX=(guix time-machine -C channels.scm --)
SUBSTITUTE_FLAGS=()
if [ -n "${VERIFY_SUBSTITUTE_URLS:-}" ]; then
  SUBSTITUTE_FLAGS=(--substitute-urls="$VERIFY_SUBSTITUTE_URLS")
fi

pass=0; fail=0
declare -a rows
resolved_path=
VERIFY_TMP="$(mktemp -d "${TMPDIR:-/tmp}/verify-standalone.XXXXXX")"
trap 'rm -rf -- "$VERIFY_TMP"' EXIT

resolve() { # name expression
  local name="$1" expression="$2" output path
  printf 'RESOLVE %s: asking Guix for the package output\n' "$name" >&2
  if ! output=$("${GVX[@]}" build "${SUBSTITUTE_FLAGS[@]}" \
      -L "$ROOT/modules" -e "$expression" 2> >(tee /dev/stderr)); then
    rows+=("FAIL|$name resolve")
    fail=$((fail+1))
    printf 'FAIL    %s resolve (Guix build did not return an output)\n' "$name" >&2
    return 1
  fi
  if ! path="$(printf '%s\n' "$output" | verify_store_path_from_output)"; then
    rows+=("FAIL|$name resolve: no store output path in Guix output")
    fail=$((fail+1))
    printf 'FAIL    %s resolve (could not identify store output path)\n' "$name" >&2
    printf '%s\n' "$output" >&2
    return 1
  fi
  resolved_path="$path"
  printf 'READY   %s: %s\n' "$name" "$path" >&2
}
check() { # name cmd...
  local name="$1"; shift
  printf 'CHECK   %s\n' "$name" >&2
  if "$@" >"$VERIFY_TMP/check.out" 2>&1; then
    rows+=("PASS|$name"); pass=$((pass+1))
    printf 'PASS    %s\n' "$name" >&2
  else
    rows+=("FAIL|$name: $(tail -1 "$VERIFY_TMP/check.out")"); fail=$((fail+1))
    printf 'FAIL    %s\n' "$name" >&2
    tail -n 30 "$VERIFY_TMP/check.out" >&2
  fi
}
has_python_module() { # prefix module
  local candidate
  for candidate in "$1"/lib/python*/site-packages/"$2"; do
    [ -e "$candidate" ] && return 0
  done
  return 1
}

if resolve "seafile" '(@ (under-sea packages seafile) seafile)'; then
  SF="$resolved_path"
  check "seafile CLI" "$SF/bin/seaf-cli" --help
fi

if resolve "seafile-server" '(@ (under-sea packages seafile-server) seafile-server)'; then
  SFS="$resolved_path"
  check "seafile-server" test -x "$SFS/bin/seaf-server"
fi

if resolve "rea" '(@ (under-sea packages rea) rea)'; then
  REA="$resolved_path"
  check "rea" "$REA/bin/rea" --version
fi

if resolve "seaweedfs" '(@ (under-sea packages seaweedfs) seaweedfs)'; then
  SW="$resolved_path"
  check "seaweedfs" "$SW/bin/weed" version
fi

if resolve "seaweedfs rocksdb" '(@ (under-sea packages seaweedfs) seaweedfs-rocksdb)'; then
  SWR="$resolved_path"
  check "seaweedfs rocksdb" bash -c "\"$SWR/bin/weed\" filer --help 2>&1 | grep -q rocksdb"
fi

if resolve "seaweedfs full stores" '(@ (under-sea packages seaweedfs) seaweedfs-full)'; then
  SWF="$resolved_path"
  check "seaweedfs full stores" bash -c "for s in rocksdb sqlite tikv ydb tarantool; do \"$SWF/bin/weed\" filer --help 2>&1 | grep -q \"\$s\" || exit 1; done"
fi

if resolve "marimo" '(@ (under-sea packages marimo) marimo)'; then
  MAR="$resolved_path"
  check "marimo" "$MAR/bin/marimo" --help
fi
if resolve "marimo extras" '(@ (under-sea packages marimo) marimo-with-extras)'; then
  MARX="$resolved_path"
  check "marimo extras" "$MARX/bin/marimo" --help
fi
if resolve "marimo-lens" '(@ (under-sea packages marimo-lens) marimo-lens)'; then
  LENS="$resolved_path"
  check "marimo-lens module" has_python_module "$LENS" marimo_lens
fi

if resolve "pydantic-ai" '(@ (under-sea packages pydantic-ai) python-pydantic-ai-slim)'; then
  PAI="$resolved_path"
  check "pydantic-ai module" has_python_module "$PAI" pydantic_ai
fi

if resolve "loro" '(@ (under-sea packages loro) loro)'; then
  LORO="$resolved_path"
  check "loro module" has_python_module "$LORO" loro
fi

if resolve "opencode v1" '(@ (under-sea packages opencode-v1) opencode-v1)'; then
  OC1="$resolved_path"
  check "opencode v1" "$OC1/bin/opencode-v1" --version
fi

if resolve "opencode v2" '(@ (under-sea packages opencode-v2) opencode-v2)'; then
  OC2="$resolved_path"
  check "opencode v2" "$OC2/bin/opencode-v2" --version
fi

echo "=== standalone package verification ==="
for r in "${rows[@]}"; do printf '%-6s %s\n' "${r%%|*}" "${r#*|}"; done
echo "--- pass=$pass fail=$fail ---"
exit $((fail != 0))
