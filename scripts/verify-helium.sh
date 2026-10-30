#!/usr/bin/env bash
# Build Helium from source with the pinned channel and smoke its installed CLI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUTPUT="$(guix time-machine -C "$ROOT/channels.scm" -- build \
  --no-substitutes -L "$ROOT/modules" helium)"
"$OUTPUT/bin/helium" --version
