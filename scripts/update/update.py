#!/usr/bin/env python3
"""One entry point for the automated package update pipeline.

Examples:
  scripts/update/update.py --all --dry-run
  scripts/update/update.py --package kilocode --version 7.8.20 \
      --apply --verify --commit

L0/L1 packages are reported as skipped.  L2 only updates the pin; L3 also
regenerates its lock through the package adapter.  Nothing is applied until the
adapter has produced a complete result.
"""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run  # noqa: E402

ROOT = run.ROOT
DEFAULT_WORKDIR = Path(os.environ.get("UPDATE_WORKDIR",
                                     "/var/tmp/under-sea-update"))


def prepare_command(name, pkg, version, workdir, apply, verify):
    cmd = [
        sys.executable, str(ROOT / "scripts" / "update" / "run.py"),
        "prepare", "--package", name, "--version", version,
        "--workdir", str(workdir),
    ]
    if apply:
        cmd.append("--apply")
    if verify:
        cmd.append("--verify")
    return cmd


def changed_package_files():
    output = subprocess.check_output(
        ["git", "status", "--porcelain"], cwd=ROOT, text=True)
    files = []
    for line in output.splitlines():
        path = line[3:].strip()
        if path.startswith("modules/under-sea/packages/"):
            files.append(path)
    return files


def update_one(name, pkg, version, workdir, apply, verify, vm, commit,
               force):
    detected = run.detect_package(name, pkg)
    if detected["status"] == "error":
        return {"package": name, "status": "error",
                "error": detected["error"]}
    current = detected["current"]
    target = version or detected["latest"]
    if not target:
        return {"package": name, "status": "error",
                "error": "no upstream version"}
    if not force and target == current:
        return {"package": name, "status": "current", "version": current}
    if pkg["autonomy"] in ("L0", "L1"):
        return {"package": name, "status": "skipped-level",
                "level": pkg["autonomy"], "version": current}
    pkgdir = workdir / f"{name}-{target}"
    cmd = prepare_command(name, pkg, target, pkgdir, apply, verify)
    result = {"package": name, "current": current, "target": target,
              "level": pkg["autonomy"], "adapter": pkg["adapter"],
              "command": cmd, "status": "prepared"}
    if not apply:
        result["status"] = "dry-run"
        return result
    subprocess.run(cmd, cwd=ROOT, check=True)
    result["status"] = "applied"
    if commit:
        files = changed_package_files()
        if not files:
            result["status"] = "no-change"
            return result
        subprocess.run(["git", "add", *files], cwd=ROOT, check=True)
        subprocess.run(
            ["git", "commit", "-S", "-m", f"{name}: update to {target}"],
            cwd=ROOT, check=True)
        result["status"] = "committed"
        result["files"] = files
    if vm:
        subprocess.run(
            [sys.executable, str(ROOT / "scripts" / "update" / "vm.py"),
             "--package", name], cwd=ROOT, check=True)
        result["vm"] = "passed"
    return result


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--package", action="append", default=[])
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--version", help="target version (single package only)")
    ap.add_argument("--workdir", type=Path, default=DEFAULT_WORKDIR)
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--vm", action="store_true")
    ap.add_argument("--commit", action="store_true")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--dry-run", action="store_true",
                    help="detect and print the plan without applying")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    data = run.load_manifest(run.DEFAULT_MANIFEST)
    packages = data["packages"]
    selected = list(packages) if args.all else args.package
    if not selected:
        ap.error("pass --all or --package NAME")
    if args.version and len(selected) != 1:
        ap.error("--version requires exactly one --package")
    if args.verify and not args.apply:
        ap.error("--verify requires --apply")
    if args.vm and not args.verify:
        ap.error("--vm requires --verify")
    if args.commit and not args.verify:
        ap.error("--commit requires --verify")
    results = []
    for name in selected:
        if name not in packages:
            results.append({"package": name, "status": "error",
                            "error": "not in manifest"})
            continue
        results.append(update_one(
            name, packages[name], args.version, args.workdir,
            args.apply, args.verify, args.vm, args.commit, args.force))
    if args.json:
        print(json.dumps(results, indent=2, sort_keys=True))
    else:
        for row in results:
            detail = row.get("target") or row.get("version") or ""
            print(f"{row['status']:14} {row['package']} {detail}".rstrip())
    return 1 if any(row["status"] == "error" for row in results) else 0


if __name__ == "__main__":
    sys.exit(main())
