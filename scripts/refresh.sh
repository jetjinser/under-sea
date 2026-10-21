#!/usr/bin/env bash
# Check upstream versions through the channel's guix refresh updaters.
#
# Usage: scripts/refresh.sh [guix refresh args...]
#   With no arguments, checks every package carrying an upstream-github
#   property plus python-ms-ivy (the ms-ivy master-tip tracker).
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

# Keep in sync with packages declaring an upstream-github property.
DEFAULT_PKGS="sing-box dae ncnn qwenimage-ncnn-vulkan hermes-agent hermes-agent-interfaces hermes-agent-integrations codex kilocode pi bun-for-hermes helium ghidra strata"

if [ "$#" -eq 0 ]; then
  set -- $DEFAULT_PKGS python-ms-ivy
fi
exec guix time-machine -C "$CHANNELS" -- refresh -t under-sea-github -t ms-ivy "$@"
