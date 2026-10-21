#!/usr/bin/env bash
# Verify every (under-sea packages *-lock) module loads and every origin it
# defines is a fixed-output sha256 origin.  Exits non-zero otherwise.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

exec guix time-machine -C channels.scm -- repl -L "$ROOT/modules" scripts/verify-locks.scm
