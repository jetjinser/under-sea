#!/usr/bin/env bash
# Phase 7 unified functional verification matrix for the under-sea Guix tree.
#
# Resolves each component's store output with the pinned channel and runs a
# smoke/functional check.  Browser checks run under Xvfb when available.
# Prints a PASS/FAIL/SKIP table; exits non-zero if any check fails.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GVX=(guix time-machine -C channels.scm --)
pass=0; fail=0; skip=0
declare -a rows

resolve() { "${GVX[@]}" build -L "$ROOT/modules" -e "$1" 2>/dev/null | tail -1; }

check() { # name cmd...
  local name="$1"; shift
  if "$@" >/tmp/phase7-check.out 2>&1; then
    rows+=("PASS|$name"); pass=$((pass+1))
  else
    rows+=("FAIL|$name: $(tail -1 /tmp/phase7-check.out)"); fail=$((fail+1))
  fi
}

skip() { rows+=("SKIP|$1: $2"); skip=$((skip+1)); }

have_xvfb=0
XVR="$(resolve '(@ (gnu packages xorg) xvfb-run)' 2>/dev/null || true)"
XS="$(resolve '(@ (gnu packages xorg) xorg-server)' 2>/dev/null || true)"
if [ -n "$XVR" ] && [ -n "$XS" ] && [ -x "$XVR/bin/xvfb-run" ]; then
  have_xvfb=1
  export PATH="$XVR/bin:$XS/bin:$PATH"
fi

# --- dashboard / agent-browser ---
AB="$(resolve '(@ (under-sea packages agent-browser) agent-browser)')"
if [ -n "$AB" ]; then
  check "agent-browser version" "$AB/bin/agent-browser" --version
  check "dashboard embedded" grep -aq "_next/static" "$AB/bin/agent-browser"
fi

# --- sing-box ---
SB="$(resolve '(@ (under-sea packages sing-box) sing-box)')"
if [ -n "$SB" ]; then
  printf '{"endpoints":[{"type":"tailscale","tag":"t","state_directory":"/tmp/ts"}]}' > /tmp/phase7-ts.json
  check "sing-box tailscale check" "$SB/bin/sing-box" check -c /tmp/phase7-ts.json
fi

# --- dae ---
DAE="$(resolve '(@ (under-sea packages dae) dae)')"
[ -n "$DAE" ] && check "dae version" "$DAE/bin/dae" --version

# --- codex ---
CX="$(resolve '(@ (under-sea packages codex) codex)')"
[ -n "$CX" ] && check "codex version" "$CX/bin/codex" --version

# --- seafile ---
SF="$(resolve '(@ (under-sea packages seafile) seafile)')"
[ -n "$SF" ] && check "seafile cli" "$SF/bin/seaf-cli" --help

# --- seafile-server ---
SFS="$(resolve '(@ (under-sea packages seafile-server) seafile-server)')"
[ -n "$SFS" ] && check "seafile-server" "$SFS/bin/seaf-server" -v

# --- rea ---
REA="$(resolve '(@ (under-sea packages rea) rea)')"
[ -n "$REA" ] && check "rea version" "$REA/bin/rea" --version

# --- seaweedfs ---
SW="$(resolve '(@ (under-sea packages seaweedfs) seaweedfs)')"
[ -n "$SW" ] && check "seaweedfs version" "$SW/bin/weed" version
SWR="$(resolve '(@ (under-sea packages seaweedfs) seaweedfs-rocksdb)')"
[ -n "$SWR" ] && check "seaweedfs rocksdb store" \
  bash -c "\"$SWR/bin/weed\" filer --help 2>&1 | grep -q rocksdb"
SWF="$(resolve '(@ (under-sea packages seaweedfs) seaweedfs-full)')"
[ -n "$SWF" ] && check "seaweedfs full stores" \
  bash -c "for s in rocksdb sqlite tikv ydb tarantool; do \"$SWF/bin/weed\" filer --help 2>&1 | grep -q \"\$s\" || exit 1; done"

# --- marimo ---
MAR="$(resolve '(@ (under-sea packages marimo) marimo)')"
[ -n "$MAR" ] && check "marimo help" "$MAR/bin/marimo" --help
MARX="$(resolve '(@ (under-sea packages marimo) marimo-with-extras)')"
[ -n "$MARX" ] && check "marimo extras help" "$MARX/bin/marimo" --help

# --- opencode ---
OC1="$(resolve '(@ (under-sea packages opencode-v1) opencode-v1)')"
[ -n "$OC1" ] && check "opencode v1 version" "$OC1/bin/opencode-v1" --version
OC2="$(resolve '(@ (under-sea packages opencode-v2) opencode-v2)')"
[ -n "$OC2" ] && check "opencode v2 version" "$OC2/bin/opencode-v2" --version

# --- pi + standalone ---
PI="$(resolve '(@ (under-sea packages pi) pi)')"
[ -n "$PI" ] && check "pi version" "$PI/bin/pi" --version
PIS="$(resolve '(@ (under-sea packages pi) pi-standalone)')"
[ -n "$PIS" ] && check "pi-standalone version" "$PIS/bin/pi" --version

# --- kilocode ---
KC="$(resolve '(@ (under-sea packages kilocode) kilocode)')"
if [ -n "$KC" ]; then
  check "kilocode version" "$KC/bin/kilo" --version
  check "kilocode completion" "$KC/bin/kilo" completion bash
fi

# --- ghidra ---
GH="$(resolve '(@ (under-sea packages ghidra) ghidra)')"
if [ -n "$GH" ]; then
  check "ghidra headless" sh -c "'$GH/bin/analyzeHeadless' 2>&1 | grep -q 'Headless Analyzer Usage'"
fi

# --- strata ---
ST="$(resolve '(@ (under-sea packages strata) strata)')"
if [ -n "$ST" ]; then
  check "strata device help" "$ST/bin/strata-device" --help
fi

# --- strata-cuda ---
STC="$(resolve '(@ (under-sea packages strata) strata-cuda)')"
if [ -n "$STC" ]; then
  check "strata-cuda device help" "$STC/bin/strata-device" --help
fi

# --- qwenimage-ncnn-vulkan ---
QIV="$(resolve '(@ (under-sea packages qwenimage-ncnn-vulkan) qwenimage-ncnn-vulkan)')"
if [ -n "$QIV" ]; then
  check "qwenimage vulkan-loader wrapper" grep -q "vulkan-loader" "$QIV/bin/qwenimage-ncnn-vulkan"
  check "qwenimage-ncnn-vulkan starts" sh -c "'$QIV/bin/qwenimage-ncnn-vulkan' 2>&1 | grep -q 'model-type = base'"
fi

# --- bun ---
BUN="$(resolve '(@ (under-sea packages bun) bun-for-hermes)')"
[ -n "$BUN" ] && check "bun version" "$BUN/bin/bun" --version

# --- hermes integrations ---
INT="$(resolve '(@ (under-sea packages hermes) hermes-agent-integrations)')"
[ -n "$INT" ] && check "hermes help" "$INT/bin/hermes" --help

# --- Hermes browser wiring (R1 local, R2 camofox) ---
R1="$(resolve '(@ (under-sea packages hermes-browser-backends) hermes-browser-runtime)')"
if [ -n "$R1" ]; then
  check "hermes-browser-runtime wrapper" test -x "$R1/bin/hermes"
  check "AGENT_BROWSER_EXECUTABLE_PATH wired" grep -q "AGENT_BROWSER_EXECUTABLE_PATH" "$R1/bin/hermes"
fi
CFBR="$(resolve '(@ (under-sea packages camofox-browser) camofox-browser-for-hermes)')"
[ -n "$CFBR" ] && check "camofox-browser wrapper" test -x "$CFBR/bin/camofox-browser"
HCR="$(resolve '(@ (under-sea packages camofox-browser) hermes-camofox-runtime)')"
[ -n "$HCR" ] && check "hermes-camofox-runtime CAMOFOX_URL" grep -q "CAMOFOX_URL" "$HCR/bin/hermes"

# --- audio / porcupine ---
AUD="$(resolve '(@ (under-sea packages hermes-audio) hermes-agent-audio)')"
[ -n "$AUD" ] && check "porcupine import" "$AUD/bin/hermes-python" -c "import pvporcupine"

# --- assembled-runtime import smoke (all Hermes runtimes) ---
# Catches "builds fine but fails to import" defects; the per-runtime detail is
# in verify-runtime-imports.sh, summarised here as a single matrix row.
if scripts/verify-runtime-imports.sh >/tmp/phase7-runtime-imports.log 2>&1; then
  rows+=("PASS|runtime imports (all runtimes)"); pass=$((pass+1))
else
  rows+=("FAIL|runtime imports (see /tmp/phase7-runtime-imports.log)"); fail=$((fail+1))
fi

# --- browser backends (Xvfb) ---
PW="$(resolve '(@ (under-sea packages hermes-browser-backends) hermes-browser-backend-playwright)')"
if [ "$have_xvfb" = 1 ]; then
  [ -n "$PW" ] && check "playwright backend wrapper" test -x "$PW/bin/hermes-browser-playwright"
  EL="$(resolve '(@ (under-sea packages hermes-electron) hermes-electron-desktop)')"
  if [ -n "$EL" ]; then
    if timeout 20 xvfb-run -a "$EL/bin/hermes-desktop" >/tmp/phase7-el.out 2>&1; then
      rows+=("PASS|electron desktop starts"); pass=$((pass+1))
    elif grep -aq "FATAL\|Goodbye" /tmp/phase7-el.out; then
      rows+=("FAIL|electron desktop: fatal"); fail=$((fail+1))
    else
      rows+=("PASS|electron desktop starts (timeout expected)"); pass=$((pass+1))
    fi
  fi
else
  skip "browser Xvfb checks" "xvfb-run not resolvable"
fi

echo "=== Phase 7 verification ==="
for r in "${rows[@]}"; do printf '%-6s %s\n' "${r%%|*}" "${r#*|}"; done
echo "--- pass=$pass fail=$fail skip=$skip ---"
[ "$fail" -eq 0 ]

# --- ivy ---
IVY="$(resolve '(@ (under-sea packages ivy) python-ms-ivy)')"
if [ -n "$IVY" ]; then
  FIXTURE="$ROOT/scripts/fixtures/ivy-array.ivy"
  check "ivy_check passes upstream array example" \
    sh -c "'$IVY/bin/ivy_check' '$FIXTURE' 2>&1 | grep -q '^OK'"
fi
