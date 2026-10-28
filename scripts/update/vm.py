#!/usr/bin/env python3
"""Run the VM test associated with a manifest package."""
import argparse
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run  # noqa: E402

ROOT = run.ROOT
TESTS = {
    "opencode-v1": "opencode",
    "opencode-v2": "opencode",
    "seaweedfs": "seaweedfs",
    "marimo": "marimo",
    "rea": "rea",
    "seafile": "seafile",
}


def test_expression(package):
    test = TESTS.get(package)
    if not test:
        raise SystemExit(f"{package}: no VM test mapping")
    return f"(@ (under-sea tests {test}) %test-under-sea-{test})"


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--package", required=True)
    args = ap.parse_args()
    expr = test_expression(args.package)
    print(f"==> {expr}", file=sys.stderr)
    subprocess.run(
        ["guix", "time-machine", "-C", "channels.scm", "--", "build",
         "-L", "modules", "-e", expr],
        cwd=ROOT, check=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
