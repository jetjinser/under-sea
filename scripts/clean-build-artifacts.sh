#!/usr/bin/env bash
# Remove Guix --keep-failed build trees left in /tmp (/tmp/guix-build-*.drv-*).
#
# These are the intermediate trees kept when a build fails; repeated attempts
# accumulate and waste disk.  Only directories owned by the current user that
# have had no write for --min-age minutes are removed, so an in-progress build
# is not disturbed.  Read-only npm/Go subdirectories are made writable with
# chmod -R u+w first.
#
# Usage:
#   scripts/clean-build-artifacts.sh [--min-age MIN] [--dry-run] [--force]
#     --min-age MIN  only remove trees idle for at least MIN minutes (default 120)
#     --dry-run      list what would be removed
#     --force        ignore the idle guard; remove every tree owned by the user
set -euo pipefail

usage() { awk 'NR > 1 && /^set /{exit} NR > 1{print}' "$0"; }

min_age=120
dry_run=0
force=0
while [ $# -gt 0 ]; do
  case "$1" in
    --min-age) min_age="${2:?missing MIN}"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --force) force=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

me=$(id -un)
shopt -s nullglob
found=0
for d in /tmp/guix-build-*; do
  [ -d "$d" ] || continue
  found=1
  if [ "$(stat -c %U "$d" 2>/dev/null)" != "$me" ]; then
    echo "skip (not owned by $me): $d"
    continue
  fi
  if [ "$force" -eq 0 ] \
     && [ -n "$(find "$d" -mmin -"$min_age" -print -quit 2>/dev/null)" ]; then
    echo "skip (written within ${min_age} min): $d"
    continue
  fi
  size=$(du -sh "$d" 2>/dev/null | cut -f1)
  if [ "$dry_run" -eq 1 ]; then
    echo "would remove ($size): $d"
  else
    chmod -R u+w "$d" 2>/dev/null || true
    rm -rf "$d"
    echo "removed ($size): $d"
  fi
done
[ "$found" -eq 1 ] || echo "no /tmp/guix-build-* trees"
