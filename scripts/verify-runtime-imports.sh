#!/usr/bin/env bash
# Import/CLI smoke for each assembled runtime: catches the class of defects
# where a package builds fine but its closure fails to import at runtime
# (missing Python dependency, native library clash, ...).
#
# Build the runtimes first (see verify-system.sh / guix build); this script
# resolves each one with --no-grafts --no-substitutes so it never hits the
# network and returns an existing output instantly.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GVX=(guix time-machine -C channels.scm --)
pass=0; fail=0; skip=0
declare -a rows

resolve() {
  "${GVX[@]}" build --no-grafts --no-substitutes -L . -e "$1" 2>/dev/null | tail -1
}
check() {
  local name="$1"; shift
  if "$@" >/tmp/runtime-import.out 2>&1; then
    rows+=("PASS|$name"); pass=$((pass+1))
  else
    rows+=("FAIL|$name: $(tail -1 /tmp/runtime-import.out)"); fail=$((fail+1))
  fi
}
skip() { rows+=("SKIP|$1: $2"); skip=$((skip+1)); }

general() { # name expression
  local name="$1" expr="$2" rt work
  rt="$(resolve "$expr")"
  if [ -z "$rt" ] || [ ! -x "$rt/bin/hermes" ]; then skip "$name" "not built"; return; fi
  work="$(mktemp -d)"
  check "$name: hermes --help" env HERMES_HOME="$work/home" "$rt/bin/hermes" --help
  check "$name: check-hermes.py" \
    env HERMES_HOME="$work/home" sh -c "cd '$work' && '$rt/bin/hermes-python' '$ROOT/scripts/check-hermes.py'"
  rm -rf "$work"
}

imports() { # name expression "mod1,mod2,..."
  local name="$1" expr="$2" mods="$3" rt
  rt="$(resolve "$expr")"
  if [ -z "$rt" ] || [ ! -x "$rt/bin/hermes-python" ]; then skip "$name" "not built"; return; fi
  check "$name: import $mods" "$rt/bin/hermes-python" -c "import $mods"
}

general "hermes-agent"              '(@ (under-sea packages hermes) hermes-agent)'
general "hermes-agent-interfaces"   '(@ (under-sea packages hermes) hermes-agent-interfaces)'
general "hermes-agent-integrations" '(@ (under-sea packages hermes) hermes-agent-integrations)'
general "hermes-agent-audio"        '(@ (under-sea packages hermes-audio) hermes-agent-audio)'
imports "hermes-agent-browser-use"  '(@ (under-sea packages hermes-browser-use) hermes-agent-browser-use)' "browser_use,langchain_openai,tiktoken,oci,boto3,imageio,agentmail,imgcat"
imports "hermes-agent-camoufox"     '(@ (under-sea packages hermes-camoufox) hermes-agent-camoufox)' "camoufox,maxminddb"

echo "=== runtime import verification ==="
for r in "${rows[@]}"; do printf '%-6s %s\n' "${r%%|*}" "${r#*|}"; done
echo "--- pass=$pass fail=$fail skip=$skip ---"
[ "$fail" -eq 0 ]
