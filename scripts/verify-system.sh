#!/usr/bin/env bash
# System-level verification for the under-sea tree: a container smoke test for
# the networking services plus the VM (marionette) system tests.
#
# The container smoke needs either an unprivileged user namespace with a
# matching /etc/subuid range or root; when neither is available it is reported
# as SKIP (not a failure).  The VM tests run as derivations (the daemon starts
# QEMU), so they always run under the daemon's privileges.
#
# Environment:
#   VERIFY_SYSTEM_SKIP_VM=1   only run the container smoke.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GVX=(guix time-machine -C channels.scm --)
pass=0; fail=0; skip=0
declare -a rows

pass() { rows+=("PASS|$1"); pass=$((pass+1)); }
fail() { rows+=("FAIL|$1"); fail=$((fail+1)); }
skip() { rows+=("SKIP|$1: $2"); skip=$((skip+1)); }

port_listening() { # port-hex
  if command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | grep -q ":$1\b"; then
    return 0
  fi
  grep -q "0100007F:$1\|00000000:$1" /proc/net/tcp 2>/dev/null
}

container_smoke() {
  local work
  work=$(mktemp -d)
  echo "container smoke: building container script..." >&2
  if ! "${GVX[@]}" system container -L "$ROOT/modules" --network \
        -e '(@ (under-sea system networking) %under-sea-sing-box-os)' \
        -r "$work/run-container" >"$work/build.log" 2>&1; then
    skip "container smoke" "container build failed (see $work/build.log)"
    return
  fi

  "$work/run-container" --pid-file="$work/pid" >"$work/run.log" 2>&1 &
  local launcher=$!
  local ok=0
  for _ in $(seq 1 60); do
    sleep 1
    if port_listening 0820; then ok=1; break; fi
    kill -0 "$launcher" 2>/dev/null || break
  done
  [ -s "$work/pid" ] && kill "$(cat "$work/pid")" 2>/dev/null
  kill "$launcher" 2>/dev/null
  wait "$launcher" 2>/dev/null

  if [ "$ok" = 1 ]; then
    pass "container smoke (sing-box listening on 127.0.0.1:2080)"
  else
    skip "container smoke" "container could not start here (needs unprivileged userns with a matching subuid range, or root); see $work/run.log"
  fi
}

run_system_test() { # name expression
  local name="$1" expr="$2" log="/tmp/verify-system-$1.log"
  echo "system test: $name (VM; may take a few minutes)..." >&2
  if "${GVX[@]}" build -L "$ROOT/modules" --cores=1 --max-silent-time=7200 \
       -e "$expr" >"$log" 2>&1; then
    pass "system test: $name"
  else
    fail "system test: $name (see $log)"
  fi
}

container_smoke

if [ "${VERIFY_SYSTEM_SKIP_VM:-0}" != 1 ]; then
  run_system_test sing-box '(@ (under-sea tests networking) %test-under-sea-sing-box)'
  run_system_test dae '(@ (under-sea tests networking) %test-under-sea-dae)'
  run_system_test browser '(@ (under-sea tests browser) %test-under-sea-browser)'
  run_system_test hermes '(@ (under-sea tests hermes) %test-under-sea-hermes)'

  # The licensing test builds a non-substitutable package from the user-supplied
  # Autodesk archive, so it only runs where that archive is available.
  if [ -n "${MOLDFLOW_ARCHIVE:-}" ] \
     || [ -f "$HOME/Autodesk_MFIU_2027_Multilingual_Linux_64bit.tar.bz2" ]; then
    run_system_test adsk-licensing '(@ (under-sea tests adsk-licensing) %test-under-sea-adsk-licensing)'
  else
    skip "system test: adsk-licensing" "set MOLDFLOW_ARCHIVE (proprietary archive)"
  fi
fi

echo "=== system verification ==="
for r in "${rows[@]}"; do printf '%-6s %s\n' "${r%%|*}" "${r#*|}"; done
echo "--- pass=$pass fail=$fail skip=$skip ---"
[ "$fail" -eq 0 ]
