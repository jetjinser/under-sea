#!/usr/bin/env bash
# Verify the precompiled/source-unavailable exception manifest:
#   1. every package whose description marks it a source-unavailable exception
#      must be listed in planning/precompiled-exceptions.json;
#   2. every listed recipe resolves and has a fixed-output sha256 source
#      (except channel-/embedded-prebuilt entries).
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

exec guix time-machine -C channels.scm -- repl -L "$ROOT/modules" scripts/verify-exceptions.scm
