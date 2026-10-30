#!/usr/bin/env bash
# Run the CDP smoke in a VM so host sandbox syscall restrictions do not
# interfere with Chromium's crashpad and browser process.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
exec guix time-machine -C channels.scm -- build \
  --substitute-urls='https://ci.guix.gnu.org https://bordeaux.guix.gnu.org' \
  -L "$ROOT/modules" -e \
  '(@ (under-sea tests browser-use) %test-under-sea-browser-use)'
