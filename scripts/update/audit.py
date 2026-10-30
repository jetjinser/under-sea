#!/usr/bin/env python3
"""Audit that every user-facing package is classified for updates."""
import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run  # noqa: E402

ROOT = run.ROOT
DEFAULT_EXEMPTIONS = ROOT / "planning" / "update-exemptions.json"
STATUS = ROOT / "STATUS.md"
VALID_LEVELS = {"L0", "L1", "L2", "L3", "L4"}
DOC_RX = re.compile(r"\(@ \(under-sea packages ([^)]+)\) ([^)\s]+)\)")


def load_exemptions(path):
    data = json.loads(Path(path).read_text())
    if data.get("schema") != 1:
        raise SystemExit(f"{path}: unsupported schema {data.get('schema')!r}")
    packages = data.get("packages")
    if not isinstance(packages, list):
        raise SystemExit(f"{path}: packages must be a list")
    for pkg in packages:
        for key in ("module", "package", "level", "reason"):
            if key not in pkg:
                raise SystemExit(f"{path}: missing {key} in {pkg!r}")
        if pkg["level"] not in VALID_LEVELS:
            raise SystemExit(f"{path}: invalid level {pkg['level']!r}")
    return packages


def doc_expressions(path=STATUS):
    if not Path(path).is_file():
        return set()
    return set(DOC_RX.findall(Path(path).read_text()))


def audit(manifest_path=run.DEFAULT_MANIFEST, exemptions_path=DEFAULT_EXEMPTIONS,
          check_docs=True):
    manifest = run.load_manifest(manifest_path)["packages"]
    exemptions = load_exemptions(exemptions_path)
    errors = []
    manifest_keys = {(pkg["module"], pkg["package"]) for pkg in manifest.values()}
    exemption_keys = {(pkg["module"], pkg["package"]) for pkg in exemptions}
    for key in sorted(manifest_keys & exemption_keys):
        errors.append(f"duplicate manifest/exemption: {key[0]}/{key[1]}")
    for pkg in exemptions:
        if pkg["level"] in ("L2", "L3", "L4") and not pkg["reason"]:
            errors.append(f"missing reason for {pkg['module']}/{pkg['package']}")
    for name, pkg in manifest.items():
        if pkg.get("autonomy") in ("L2", "L3") and not pkg.get("tests"):
            errors.append(
                f"missing verification gates for {name} at {pkg['autonomy']}")
        if not pkg.get("independent", True):
            parent = pkg.get("depends_on")
            if parent not in manifest:
                errors.append(
                    f"dependent {name} has unknown parent {parent!r}")
    inventory = manifest_keys | exemption_keys
    if check_docs:
        for key in sorted(doc_expressions() - inventory):
            errors.append(f"STATUS expression not classified: {key[0]}/{key[1]}")
    return {
        "manifest": len(manifest),
        "exemptions": len(exemptions),
        "inventory": len(inventory),
        "errors": errors,
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--manifest", type=Path, default=run.DEFAULT_MANIFEST)
    ap.add_argument("--exemptions", type=Path, default=DEFAULT_EXEMPTIONS)
    ap.add_argument("--no-docs", action="store_true")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    result = audit(args.manifest, args.exemptions, check_docs=not args.no_docs)
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(f"manifest={result['manifest']} exemptions={result['exemptions']} "
              f"inventory={result['inventory']}")
        for error in result["errors"]:
            print(f"FAIL {error}")
    return 1 if result["errors"] else 0


if __name__ == "__main__":
    sys.exit(main())
