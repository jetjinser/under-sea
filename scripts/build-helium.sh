#!/usr/bin/env bash
# Build the helium package with offline-friendly pre-seeding.
#
# Usage: scripts/build-helium.sh [extra guix build args...]
#   e.g. scripts/build-helium.sh -K    # keep failed build trees
#
# What it does:
#   1. Verifies the locally cached tarballs against the sha256 pins in
#      modules/under-sea/packages/helium.scm.
#   2. Pre-injects them into the store via `guix download`, so the daemon
#      skips network fetches for those origins.
#   3. Preflights the git origins the build clones at build time.
#   4. Runs the real build: guix build -L modules helium.
#
# Cache and log locations (overridable):
#   HELIUM_CACHE     (default /var/tmp/kilo-keep/helium)  tarball cache
#   HELIUM_BUILD_LOG (default /var/tmp/helium-build.log)  build log copy
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
KEEP="${HELIUM_CACHE:-/var/tmp/kilo-keep/helium}"
STAGE="$KEEP/stage"
LOG="${HELIUM_BUILD_LOG:-/var/tmp/helium-build.log}"
mkdir -p "$STAGE"

fail=0

inject() { # <local file> <origin basename> <nix-base32 sha256>
  local src="$1" name="$2" want="$3" got
  local staged="$STAGE/$name"
  if [ ! -f "$src" ]; then
    echo "✗ missing local file: $src"
    fail=1; return 1
  fi
  if [ ! -e "$staged" ]; then
    ln "$src" "$staged" 2>/dev/null || cp -n "$src" "$staged"
  fi
  got="$(guix hash -f nix-base32 "$staged")"
  if [ "$got" != "$want" ]; then
    echo "✗ hash mismatch: $name"
    echo "    expected $want"
    echo "    actual   $got"
    fail=1; return 1
  fi
  guix download "$staged" >/dev/null 2>&1 \
    && echo "✓ seeded store: $name" \
    || { echo "✗ guix download failed: $name"; fail=1; return 1; }
}

preflight_git() { # <label> <url> <commit>
  if timeout 30 git ls-remote "$2" 2>/dev/null | grep -q "^$3"; then
    echo "✓ reachable: $1 ($2)"
  else
    echo "⚠ preflight failed (build will retry): $1 ($2)"
  fi
}

echo "=== 1/4 disk check ==="
df -h /gnu/store | tail -1
echo "   (a full chromium build needs roughly 60-100GB)"

echo
echo "=== 2/4 pre-seed url origins ==="
inject "$KEEP/chromium-155.0.8059.84-base.tar.zst" \
       "chromium-155.0.8059.84-base.tar.zst" \
       "1i56njrm2g5qf5pads55w2q8j7vb5hzlp7v97plzzyini2scxkw9"
inject "$KEEP/chromium-155.0.8059.84-linux-x64.tar.zst" \
       "chromium-155.0.8059.84-linux-x64.tar.zst" \
       "1ydjlzx1v9vs4ny3ryhq6ll4ixhk43pyl0f2yqxfkr5gijxs1rmz"
inject "$KEEP/helium-deps/search-engines.tar.gz" \
       "nonfree-search-engines-data-202609082320.tar.gz" \
       "19siv868wb8khzqazbajy5jr4h88v639gwdm9gb4ci2586pn739a"
inject "$KEEP/helium-deps/onboarding.tar.gz" \
       "helium-onboarding-202610161403.tar.gz" \
       "1b00d79bg9nn1ni1h19v7a24dkff364flw0a7bsn824ynzgfcpdk"
inject "$KEEP/helium-deps/ublock.zip" \
       "uBlock0_1.75.0.chromium.zip" \
       "1ipkggprglp9ac52najvlpvv2qw4s9dw0ix61pk79i66yxs4c8a9"

echo
echo "=== 3/4 git origin preflight ==="
preflight_git helium       "https://ghfast.top/https://github.com/imputnet/helium" \
              832faa7822566270e10c0d3262f702f9d0fea81f
preflight_git helium-linux "https://ghfast.top/https://github.com/imputnet/helium-linux" \
              cf878d4aaff58d063beada276c437ae756a142aa
preflight_git debian-patches "https://salsa.debian.org/chromium-team/chromium.git" \
              "debian/151.0.7922.137-1"

echo
if [ "$fail" -ne 0 ]; then
  echo "Some pre-seeding failed; continuing (those origins will download)."
fi

echo "=== 4/4 guix build ==="
echo "log: $LOG  (completed derivations are cached; rerun to resume)"
cd "$REPO"
guix build -L modules helium "$@" 2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}
echo
if [ "$rc" -eq 0 ]; then
  echo "★ build succeeded"
else
  echo "★ build exited $rc — tail of log: tail -50 $LOG"
fi
exit "$rc"
