#!/usr/bin/env bash
# Verify the precompiled/source-unavailable exception manifest.
#   1. every package whose description marks it a source-unavailable exception
#      must be listed in planning/precompiled-exceptions.json;
#   2. every listed recipe resolves and has a fixed-output sha256 source
#      (except channel-/embedded-prebuilt entries).
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

guix time-machine -C channels.scm -- shell python-minimal -- python3 - <<'PY' || exit 2
import json, re, sys, pathlib

manifest = json.loads(pathlib.Path("planning/precompiled-exceptions.json").read_text())
listed = {e["recipe"] for e in manifest["exceptions"]}

missing = []
for path in sorted(pathlib.Path("modules/under-sea/packages").glob("*.scm")):
    text = path.read_text()
    for block in re.split(r"(?=\(define-public\s)", text):
        m = re.match(r"\(define-public\s+([a-z0-9-]+)", block)
        if not m:
            continue
        name = m.group(1)
        di = block.find("(description")
        if di != -1 and "source-unavailable exception" in block[di:]:
            if name not in listed:
                missing.append(f"{path}: {name}")

if missing:
    print("verify-exceptions: unlisted source-unavailable packages:", file=sys.stderr)
    for item in missing:
        print("  " + item, file=sys.stderr)
    sys.exit(1)
print(f"verify-exceptions: all detected source-unavailable packages are listed ({len(listed)} entries)")
PY

exec guix time-machine -C channels.scm -- repl -L "$ROOT/modules" scripts/verify-exceptions.guile
