#!/usr/bin/env python3
"""Generate Vimium C's production Node lock from npm-shrinkwrap.json."""
import argparse
import subprocess
import sys
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--tarballs", type=Path, required=True)
    args = parser.parse_args()

    args.tarballs.mkdir(parents=True, exist_ok=True)
    archive = args.tarballs / f"vimium-c-{args.version}-source.tar.gz"
    if not archive.is_file():
        with tarfile.open(archive, "w:gz") as tar:
            tar.add(args.source_dir, arcname=f"vimium-c-{args.version}")

    subprocess.run([
        sys.executable, str(ROOT / "scripts" / "lock-hermes-node.py"),
        str(archive), str(args.source_dir),
        "--cache", str(args.tarballs),
        "--inventory", str(args.inventory),
        "--output", str(args.output),
        "--lockfile", "npm-shrinkwrap.json",
        "--module", "vimium-c-node-lock",
        "--symbol", "%vimium-c-node-sources",
        "--production-only", "--fetch",
    ], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
