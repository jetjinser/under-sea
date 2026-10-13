#!/usr/bin/env bash
# Single entry point for the under-sea verification gates.
#
# Runs the packaging-quality checks, the Phase 7 functional matrix (which
# includes the assembled-runtime import smoke) and the system-level checks,
# then the credential/network-gated report.  Prints one summary line per gate
# and exits non-zero if any gate fails.  SKIP entries are environment-gated,
# not failures.
#
# Environment:
#   VERIFY_PACKAGING_ELF=1    also scan runtime outputs for exec-stack (slow).
#   VERIFY_SYSTEM_SKIP_VM=1   skip the (slow) VM system tests.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0
gate() { # name script
  local name="$1" script="$2"
  if "$script" >"/tmp/verify-all-$name.log" 2>&1; then
    printf 'PASS  %-11s %s\n' "$name" "$script"
  else
    printf 'FAIL  %-11s %s (see /tmp/verify-all-%s.log)\n' "$name" "$script" "$name"
    fail=$((fail + 1))
  fi
}

gate packaging scripts/verify-packaging.sh
gate phase7    scripts/verify-phase7.sh
gate system    scripts/verify-system.sh

# Credential/network-gated report (SKIP entries are not failures).
scripts/verify-credentials.sh || true

echo "--- verify-all: $fail failing gate(s) ---"
[ "$fail" -eq 0 ]
