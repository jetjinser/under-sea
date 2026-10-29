#!/usr/bin/env python3
"""Generate the camofox-browser Node source lock from its package-lock.json."""
import argparse
import subprocess
import sys
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--version", required=True)
    ap.add_argument("--source-dir", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--tarballs", type=Path, required=True)
    args = ap.parse_args()
    args.tarballs.mkdir(parents=True, exist_ok=True)
    archive = args.tarballs / f"camofox-browser-{args.version}.tar.gz"
    if not archive.is_file():
        with tarfile.open(archive, "w:gz") as tar:
            tar.add(args.source_dir,
                    arcname=f"camofox-browser-{args.version}")
    subprocess.run([
        sys.executable, str(ROOT / "scripts" / "lock-hermes-node.py"),
        str(archive), str(args.source_dir),
        "--cache", str(args.tarballs),
        "--inventory", str(ROOT / "planning" / "camofox-node-inventory.json"),
        "--output", str(args.output),
        "--module", "camofox-node-lock",
        "--symbol", "%camofox-node-sources",
        "--fetch",
    ], cwd=ROOT, check=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
