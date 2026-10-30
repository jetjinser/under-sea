#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$(guix time-machine -C "$ROOT/channels.scm" -- build -L "$ROOT/modules" \
  -e '(@ (under-sea packages overleaf) overleaf-ctl)' | tail -1)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/under-sea-overleaf.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

OVERLEAF_ROOT="$WORK/root" "$OUTPUT/bin/overleaf-ctl" help | grep -q 'usage: overleaf-ctl'
OVERLEAF_ROOT="$WORK/root" "$OUTPUT/bin/overleaf-ctl" init
test -s "$WORK/root/config/overleaf.rc"
test -s "$WORK/root/config/variables.env"
test ! -e "$WORK/root/lib/data"
printf '%s\n' 'PASS  overleaf help and isolated init smoke'
