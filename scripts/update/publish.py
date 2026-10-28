#!/usr/bin/env python3
"""Print the publish plan for a prepared package update."""
import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run  # noqa: E402


def plan(package, version):
    return {
        "package": package,
        "version": version,
        "branch": f"update/{package}-{version}",
        "commit": f"{package}: update to {version}",
        "title": f"{package}: update to {version}",
        "prepare": (
            f"scripts/update/run.py prepare --package {package} "
            f"--version {version} --apply --verify"),
        "push": f"git push origin update/{package}-{version}",
        "pr": f"gh pr create --head update/{package}-{version} "
              f"--title \"{package}: update to {version}\" --fill",
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--package", required=True)
    ap.add_argument("--version", required=True)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    data = run.load_manifest(run.DEFAULT_MANIFEST)
    if args.package not in data["packages"]:
        raise SystemExit(f"unknown package: {args.package}")
    result = plan(args.package, args.version)
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        for key in ("branch", "commit", "prepare", "push", "pr"):
            print(f"{key}: {result[key]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
