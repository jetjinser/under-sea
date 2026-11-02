#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE must point at the checkout}"
: "${RUNNER_TEMP:?RUNNER_TEMP must point at the job temporary directory}"
: "${GITHUB_ENV:?GITHUB_ENV must point at the job environment file}"

config_root="$RUNNER_TEMP/under-sea-guix-config"
mkdir -p "$config_root/guix"
cp "$GITHUB_WORKSPACE/channels.scm" \
  "$config_root/guix/trusted-channels.scm"
printf 'XDG_CONFIG_HOME=%s\n' "$config_root" >> "$GITHUB_ENV"
