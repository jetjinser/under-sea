#!/usr/bin/env python3
"""Offline E2E driver for the Hermes gateway service: one full agent turn
against the mock OpenAI-compatible model server (127.0.0.1:30000).

Run under the hermes-python runtime inside the test VM:
    hermes-python /run/current-system/profile/bin/hermes-e2e-driver.py

Passes when the model's terminal tool_call creates the marker file and the
second model round returns the final response.
"""
import os
import sys

import yaml

# Point the model provider at the local mock server before the AIAgent reads
# its configuration.
home = os.environ.get("HERMES_HOME") or os.path.expanduser("~/.hermes")
os.makedirs(home, exist_ok=True)
with open(os.path.join(home, "config.yaml"), "w", encoding="utf-8") as cfg:
    cfg.write(yaml.safe_dump({
        "providers": {
            "mock": {
                "base_url": "http://127.0.0.1:30000/v1",
                "api_key": "dummy",
                "model": "mock-model",
            }
        },
        "provider": "mock",
        "model": "mock-model",
    }))

sys.path.insert(0, "/run/current-system/profile/share/hermes-agent")

from run_agent import AIAgent  # noqa: E402

MARKER = "/tmp/hermes-e2e-marker"

agent = AIAgent(base_url="http://127.0.0.1:30000/v1", model="mock-model")

agent = AIAgent(base_url="http://127.0.0.1:30000/v1", model="mock-model")
response = agent.run_conversation(
    "Please create the file %s using the terminal tool, then confirm." % MARKER
)

print("AGENT-RESPONSE:", response)
if os.path.exists(MARKER):
    print("E2E OK: marker file exists")
else:
    print("E2E FAIL: marker file missing")
    sys.exit(1)
