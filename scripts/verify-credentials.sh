#!/usr/bin/env bash
# Credential/network-gated verification for the under-sea tree.
#
# Reports which capabilities can be exercised in the current environment and
# skips (never fails) the ones that require secrets or external servers.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
GVX=(guix time-machine -C channels.scm --)
resolve() { "${GVX[@]}" build -L . -e "$1" 2>/dev/null | tail -1; }

report() { printf '%-6s %-34s %s\n' "$1" "$2" "$3"; }

echo "=== credential / network gated checks ==="

# Porcupine wakeword (needs an access key)
AUD="$(resolve '(@ (under-sea packages hermes-audio) hermes-agent-audio)')"
if [ -n "${PORCUPINE_ACCESS_KEY:-}" ]; then
  if "$AUD/bin/hermes-python" -c "import pvporcupine; pvporcupine.create(access_key='$PORCUPINE_ACCESS_KEY', keywords=['computer'])" >/dev/null 2>&1; then
    report RUN porcupine-wakeword "created engine"
  else
    report FAIL porcupine-wakeword "engine creation failed"
  fi
else
  report SKIP porcupine-wakeword "set PORCUPINE_ACCESS_KEY"
fi

# sing-box real connectivity (needs a server + config)
if [ -n "${SING_BOX_CONFIG:-}" ]; then
  SB="$(resolve '(@ (under-sea packages sing-box) sing-box)')"
  "$SB/bin/sing-box" run -c "$SING_BOX_CONFIG" >/tmp/sb-run.out 2>&1 &
  sbpid=$!
  sleep 3
  if kill -0 "$sbpid" 2>/dev/null; then
    kill "$sbpid" 2>/dev/null
    report RUN sing-box "started with $SING_BOX_CONFIG"
  else
    report FAIL sing-box "exited early (see /tmp/sb-run.out)"
  fi
else
  report SKIP sing-box "set SING_BOX_CONFIG to a real outbound"
fi

# dae real service (needs config + privileges)
if [ -n "${DAE_CONFIG:-}" ]; then
  report RUN dae "config provided; run dae manually with $DAE_CONFIG"
else
  report SKIP dae "set DAE_CONFIG"
fi

# Codex auth/exec (needs credentials)
CX="$(resolve '(@ (under-sea packages codex) codex-complete)')"
if [ -n "${OPENAI_API_KEY:-}" ] || [ -d "$HOME/.codex" ]; then
  report RUN codex-auth "credentials present; try: $CX/bin/codex login/exec"
else
  report SKIP codex-auth "set OPENAI_API_KEY or run codex login"
fi

# Hermes LLM e2e (needs a model API key)
INT="$(resolve '(@ (under-sea packages hermes) hermes-agent-integrations)')"
if [ -n "${ANTHROPIC_API_KEY:-}${OPENAI_API_KEY:-}${HERMES_API_KEY:-}" ]; then
  report RUN hermes-llm "keys present; run: $INT/bin/hermes -z 'ping'"
else
  report SKIP hermes-llm "set a model API key"
fi

# Cloud browser providers (need API keys)
for pair in "BROWSERBASE_API_KEY:browserbase" "BROWSER_USE_API_KEY:browser_use" "FIRECRAWL_API_KEY:firecrawl"; do
  var="${pair%%:*}"; name="${pair##*:}"
  if [ -n "${!var:-}" ]; then
    report RUN "cloud-browser-$name" "key present"
  else
    report SKIP "cloud-browser-$name" "set $var"
  fi
done

# Autodesk Moldflow Insight (proprietary thin-client; needs a license)
if [ -n "${MOLDFLOW_ARCHIVE:-}" ] \
   || [ -f "$HOME/Autodesk_MFIU_2027_Multilingual_Linux_64bit.tar.bz2" ]; then
  MF="$(resolve '(@ (under-sea packages moldflow) moldflow-insight-thinclient)')"
  if [ -n "$MF" ] \
     && [ -x "$MF/opt/Autodesk/simulation-compute2/bin/ComputeTool" ]; then
    if [ -n "${ADSK_SERVICE_ADDRESS:-}" ]; then
      report RUN moldflow "license server $ADSK_SERVICE_ADDRESS set; try: . $MF/mfclient.env; $MF/autodesk-moldflow-insight-2027/bin/license_diagnostics checkout MFLOW 00000"
    else
      report SKIP moldflow "set ADSK_SERVICE_ADDRESS (network license) or configure named-user entitlement"
    fi
  else
    report SKIP moldflow "not built (set MOLDFLOW_ARCHIVE and guix build)"
  fi

  # Autodesk Licensing Service
  AL="$(resolve '(@ (under-sea packages adsk-licensing) adsk-licensing)' 2>/dev/null || true)"
  if [ -n "$AL" ] && [ -x "$AL/bin/AdskLicensingService" ]; then
    if "$AL/bin/AdskLicensingService" --version >/dev/null 2>&1; then
      report RUN adsk-licensing "service binary runs"
    else
      report FAIL adsk-licensing "service binary failed to run"
    fi
    if [ -d /var/opt/Autodesk/AdskLicensingService ]; then
      report RUN adsk-licensing-state "state dir present"
    else
      report SKIP adsk-licensing-state "enable adsk-licensing-service-type to create /var/opt/Autodesk/AdskLicensingService"
    fi
  else
    report SKIP adsk-licensing "not built (guix build adsk-licensing)"
  fi
else
  report SKIP moldflow "set MOLDFLOW_ARCHIVE to the downloaded installer"
fi

echo "--- done (SKIP entries are environment-gated, not failures) ---"
