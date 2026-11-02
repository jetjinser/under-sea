#!/usr/bin/env bash
# Run the packaging-quality checks: lint, lock integrity and the precompiled
# exception manifest.  Set VERIFY_PACKAGING_ELF=1 to also scan built runtime
# outputs for executable-stack shared objects (slow; needs the outputs built).
set -u
set -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0
VERIFY_TMP="$(mktemp -d "${TMPDIR:-/tmp}/verify-packaging.XXXXXX")"
trap 'rm -rf -- "$VERIFY_TMP"' EXIT

run() { # name script
  local name="$1" script="$2" log="$VERIFY_TMP/$1.log"
  printf 'RUN   %s: %s\n' "$name" "$script"
  if "$script" 2>&1 | tee "$log"; then
    printf 'PASS  %s\n' "$1"
  else
    printf 'FAIL  %s (last output follows)\n' "$1"
    tail -n 50 "$log"
    fail=$((fail + 1))
  fi
}

run lint scripts/verify-lint.sh
run hygiene scripts/verify-hygiene.sh
run locks scripts/verify-locks.sh
run exceptions scripts/verify-exceptions.sh

if [ "${VERIFY_PACKAGING_ELF:-0}" = 1 ]; then
  run elf scripts/verify-elf.sh
fi

echo "--- verify-packaging: $fail failure(s) ---"
[ "$fail" -eq 0 ]
