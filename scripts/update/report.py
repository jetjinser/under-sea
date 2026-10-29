#!/usr/bin/env python3
"""Summarize update coverage and autonomy levels."""
import argparse
import json
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audit  # noqa: E402
import run  # noqa: E402

ROOT = run.ROOT


def report():
    manifest = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]
    exemptions = audit.load_exemptions(audit.DEFAULT_EXEMPTIONS)
    levels = Counter()
    independent = 0
    dependent = 0
    rows = []
    for name, pkg in manifest.items():
        levels[pkg["autonomy"]] += 1
        is_independent = pkg.get("independent", True)
        if pkg["autonomy"] in ("L2", "L3", "L4"):
            if is_independent:
                independent += 1
            else:
                dependent += 1
        rows.append({
            "package": name, "module": pkg["module"],
            "level": pkg["autonomy"], "adapter": pkg["adapter"],
            "source": "manifest", "independent": is_independent,
        })
    for pkg in exemptions:
        levels[pkg["level"]] += 1
        rows.append({
            "package": pkg["package"], "module": pkg["module"],
            "level": pkg["level"], "adapter": "exempt",
            "source": "exemption", "independent": False,
        })
    return {
        "inventory": len(rows),
        "levels": dict(sorted(levels.items())),
        "independent_l2_plus": independent,
        "dependent_l2_plus": dependent,
        "rows": sorted(rows, key=lambda row: (row["level"], row["package"])),
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    data = report()
    if args.json:
        print(json.dumps(data, indent=2, sort_keys=True))
    else:
        print(f"inventory={data['inventory']} levels={data['levels']} "
              f"independent_l2_plus={data['independent_l2_plus']} "
              f"dependent_l2_plus={data['dependent_l2_plus']}")
        for row in data["rows"]:
            print(f"{row['level']} {row['source']:9} {row['module']}/{row['package']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
