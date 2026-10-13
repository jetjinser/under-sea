#!/usr/bin/env bash
# Lint every package under (under-sea packages ...) with the offline checkers.
# Exits non-zero if any package produces a warning.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

exec guix time-machine -C channels.scm -- repl -L . scripts/lint-packages.guile
