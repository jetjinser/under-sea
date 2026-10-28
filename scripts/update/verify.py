#!/usr/bin/env python3
"""Build a package and its declared dependents with the pinned channels."""
import argparse
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run  # noqa: E402

ROOT = run.ROOT


def build_plan(data, name):
    pkg = data["packages"][name]
    plan = [(pkg["module"], pkg["package"], "primary")]
    for dep in pkg.get("dependents", []):
        plan.append((dep["module"], dep["package"], "dependent"))
    return plan


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--package", required=True)
    ap.add_argument("--manifest", type=Path, default=run.DEFAULT_MANIFEST)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    data = run.load_manifest(args.manifest)
    if args.package not in data["packages"]:
        raise SystemExit(f"unknown package: {args.package}")
    plan = build_plan(data, args.package)
    print(json.dumps([{"module": m, "package": p, "kind": k}
                      for m, p, k in plan], indent=2))
    if args.dry_run:
        return 0
    for module, package, kind in plan:
        expr = f"(@ (under-sea packages {module}) {package})"
        print(f"==> {kind}: {expr}", file=sys.stderr)
        subprocess.run(
            ["guix", "time-machine", "-C", "channels.scm", "--", "build",
             "-L", "modules", "--no-substitutes", "-e", expr],
            cwd=ROOT, check=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
