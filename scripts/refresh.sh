#!/usr/bin/env bash
# Check upstream versions through the channel's guix refresh updaters.
#
# Usage: scripts/refresh.sh [guix refresh args...]
#   With no arguments, refreshes every package through the two updaters; their
#   predicates select packages carrying an upstream-github property plus
#   python-ms-ivy (the ms-ivy master-tip tracker).
#
# This checkout is passed to guix as a file:// channel so that the
# (guix import under-sea-github) and (guix import ms-ivy) updaters are
# discovered without a prior `guix pull'.
set -eu

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CHANNELS="$(mktemp /tmp/under-sea-channels.XXXXXX.scm)"
trap 'rm -f "$CHANNELS"' EXIT

{ printf '(cons (channel (name (quote under-sea)) (url "file://%s"))\n' "$REPO"
  cat "$REPO/channels.scm"
  echo ')'
} > "$CHANNELS"

exec guix time-machine -C "$CHANNELS" -- refresh -t under-sea-github -t ms-ivy "$@"
