#!/usr/bin/env python3
"""Atomically install a prepared set of text artifacts into a target tree."""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import hermes  # noqa: E402


def apply_artifacts(source_root, target_root, relative_paths):
    source_root = Path(source_root)
    target_root = Path(target_root)
    files = {}
    for relative in relative_paths:
        source = source_root / Path(relative).name
        if not source.is_file():
            raise FileNotFoundError(f"prepared artifact is missing: {source}")
        files[target_root / relative] = source.read_text()
    hermes.atomic_write_many(files)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", required=True, type=Path)
    parser.add_argument("--target-root", required=True, type=Path)
    parser.add_argument("--artifact", action="append", required=True)
    args = parser.parse_args()
    apply_artifacts(args.source_root, args.target_root, args.artifact)
    return 0


if __name__ == "__main__":
    sys.exit(main())
