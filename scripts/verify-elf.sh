#!/usr/bin/env bash
# Scan built runtime outputs for shared objects with an executable-stack
# (PT_GNU_STACK RWE) marker, which fails to load on kernels that refuse
# executable stacks.  Exits non-zero if any is found.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GVX=(guix time-machine -C channels.scm --)
READELF="$(command -v readelf || ls /gnu/store/*binutils*/bin/readelf 2>/dev/null | head -1)"
if [ -z "$READELF" ]; then
  echo "verify-elf: readelf not found" >&2
  exit 2
fi

EXPRS=(
  '(@ (under-sea packages hermes-onnx) onnxruntime-for-hermes)'
  '(@ (under-sea packages hermes-audio) hermes-agent-audio)'
  '(@ (under-sea packages hermes-browser-use) hermes-agent-browser-use)'
  '(@ (under-sea packages hermes-camoufox) hermes-agent-camoufox)'
  '(@ (under-sea packages hermes) hermes-agent-integrations)'
)

fail=0
for expr in "${EXPRS[@]}"; do
  out="$("${GVX[@]}" build --no-grafts -L "$ROOT/modules" -e "$expr" 2>/dev/null | tail -1)"
  if [ -z "$out" ] || [ ! -e "$out" ]; then
    printf 'SKIP  %s (could not resolve)\n' "$expr"
    continue
  fi
  found="$(find "$out" -name '*.so*' -type f 2>/dev/null | while read -r so; do
    if "$READELF" -l "$so" 2>/dev/null | grep -A1 GNU_STACK | grep -q RWE; then
      echo "$so"
    fi
  done)"
  if [ -n "$found" ]; then
    fail=$((fail + 1))
    printf 'FAIL  %s\n' "$out"
    printf '      %s\n' $found
  else
    printf 'PASS  %s\n' "$out"
  fi
done

echo "--- verify-elf: $fail output(s) with executable-stack objects ---"
[ "$fail" -eq 0 ]
