#!/usr/bin/env bash
# Whole-channel source hygiene: unused module imports and unreferenced
# private definitions.  Exits non-zero when anything is found.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

exec guix time-machine -C channels.scm -- repl -L "$ROOT/modules" scripts/verify-hygiene.scm
