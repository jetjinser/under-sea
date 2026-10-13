#!/usr/bin/env bash
# Run the packaging-quality checks: lint, lock integrity and the precompiled
# exception manifest.  Set VERIFY_PACKAGING_ELF=1 to also scan built runtime
# outputs for executable-stack shared objects (slow; needs the outputs built).
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0
run() { # name script
  if "$2" >"/tmp/verify-$1.log" 2>&1; then
    printf 'PASS  %s\n' "$1"
  else
    printf 'FAIL  %s (see /tmp/verify-%s.log)\n' "$1" "$1"
    fail=$((fail + 1))
  fi
}

run lint scripts/verify-lint.sh
run locks scripts/verify-locks.sh
run exceptions scripts/verify-exceptions.sh

if [ "${VERIFY_PACKAGING_ELF:-0}" = 1 ]; then
  run elf scripts/verify-elf.sh
fi

echo "--- verify-packaging: $fail failure(s) ---"
[ "$fail" -eq 0 ]
