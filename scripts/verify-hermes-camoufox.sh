#!/usr/bin/env bash
# Run controller, backend and browser startup checks in a guest VM.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
exec guix time-machine -C channels.scm -- build \
  --substitute-urls='https://ci.guix.gnu.org https://bordeaux.guix.gnu.org' \
  -L "$ROOT/modules" -e \
  '(@ (under-sea tests camoufox) %test-under-sea-camoufox)'
