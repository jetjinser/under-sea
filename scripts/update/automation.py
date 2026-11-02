#!/usr/bin/env python3
"""Run package updates whose individual build verification is automated.

The caller must create a clean branch and provide a configured signing key.
Each successful package is committed independently, so a later package failure
does not discard earlier verified updates.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "planning" / "update-manifest.json"
UPDATER = ROOT / "scripts" / "update" / "update.scm"


def eligible_packages():
    packages = json.loads(MANIFEST.read_text())["packages"]
    return [
        name for name, package in sorted(packages.items())
        if package.get("autonomy") == "L3"
        and package.get("independent", True)
        and package.get("adapter") not in ("dependent", "helium")
    ]


def main():
    if subprocess.run(["git", "status", "--porcelain"], cwd=ROOT,
                      check=True, capture_output=True, text=True).stdout.strip():
        print("automatic update requires a clean checkout", file=sys.stderr)
        return 2
    base = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()

    successes = []
    failures = []
    work_root = Path(os.environ.get("RUNNER_TEMP", "/var/tmp")) / "under-sea-automation"
    for name in eligible_packages():
        print(f"::group::Update {name}", flush=True)
        result = subprocess.run(
            ["guile", "--no-auto-compile", "-L", str(ROOT / "scripts/update"),
             "-s", str(UPDATER), "--package", name, "--apply", "--commit",
             "--json", "--workdir", str(work_root / name)],
            cwd=ROOT,
        )
        print("::endgroup::", flush=True)
        if result.returncode:
            failures.append(name)
            print(f"FAILED {name} (exit {result.returncode})", flush=True)
            if subprocess.run(["git", "status", "--porcelain"], cwd=ROOT,
                              check=True, capture_output=True,
                              text=True).stdout.strip():
                subprocess.run(["git", "reset", "--hard", "HEAD"],
                               cwd=ROOT, check=True)
        else:
            successes.append(name)

    commit_count = int(subprocess.check_output(
        ["git", "rev-list", "--count", f"{base}..HEAD"],
        cwd=ROOT, text=True).strip())
    summary = [
        "## Scheduled package updates",
        f"- Eligible packages checked: {len(successes) + len(failures)}",
        f"- Updater completed: {len(successes)}",
        f"- Failed: {len(failures)}",
        f"- Commits created: {commit_count}",
    ]
    if successes:
        summary.append("- Completed packages: " + ", ".join(successes))
    if failures:
        summary.append("- Failed packages: " + ", ".join(failures))
    summary_text = "\n".join(summary) + "\n"
    report_path = Path(os.environ.get("RUNNER_TEMP", "/var/tmp")) / "automatic-update-report.md"
    report_path.write_text(summary_text)
    print(summary_text, end="", flush=True)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
