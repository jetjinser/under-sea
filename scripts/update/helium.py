#!/usr/bin/env python3
"""Report the Helium component pins without attempting an update.

Helium is assembled from several independent origins.  A single git tag is
not enough to describe an update, so this detector keeps the component
inventory visible and marks the package as manual-review (L1).
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = ROOT / "modules" / "under-sea" / "packages" / "helium.scm"

DEFINITIONS = {
    "helium_version": r'\(define %helium-version "([^"]+)"\)',
    "helium_revision": r'\(define %helium-revision "([^"]+)"\)',
    "helium_linux_revision": r'\(define %helium-linux-revision "([^"]+)"\)',
    "chromium_version": r'\(define %chromium-version "([^"]+)"\)',
    "debian_revision": r'\(define %debian-revision "([^"]+)"\)',
}
ASSETS = {
    "search_engines": r'helium-nonfree-assets"\s*\n\s*"/releases/download/([^/"]+)',
    "onboarding": r'helium-onboarding"\s*\n\s*"/releases/download/([^/"]+)',
    "ublock": r'imputnet/uBlock"\s*\n\s*"/releases/download/([^/"]+)',
    "esbuild": r'linux-x64-([0-9][0-9.]*)\.tgz',
}


def read_components(source):
    text = Path(source).read_text()
    components = {}
    for name, pattern in DEFINITIONS.items():
        match = re.search(pattern, text)
        if not match:
            raise SystemExit(f"{source}: cannot find {name}")
        components[name] = match.group(1)
    components["assets"] = {}
    for name, pattern in ASSETS.items():
        match = re.search(pattern, text)
        if not match:
            raise SystemExit(f"{source}: cannot find asset {name}")
        components["assets"][name] = match.group(1)
    return components


def version_key(text):
    return tuple(int(part) for part in re.findall(r"\d+", text))


def git_tags(repo, timeout=30):
    output = subprocess.check_output(
        ["git", "ls-remote", "--tags", f"https://github.com/{repo}.git"],
        text=True, timeout=timeout)
    tags = []
    for line in output.splitlines():
        ref = line.split("\t", 1)[-1]
        if ref.startswith("refs/tags/") and not ref.endswith("^{}"):
            tags.append(ref[len("refs/tags/"):])
    return tags


def latest_tag(repo, pattern):
    try:
        tags = [tag for tag in git_tags(repo) if re.search(pattern, tag)]
    except (OSError, subprocess.SubprocessError) as exc:
        return {"latest": None, "error": str(exc)}
    if not tags:
        return {"latest": None, "error": "no matching tags"}
    return {"latest": max(tags, key=version_key)}


def report(source, network=True):
    components = read_components(source)
    result = {
        "package": "helium",
        "level": "L1",
        "status": "manual-review",
        "components": components,
        "upstream": {},
    }
    if network:
        result["upstream"] = {
            "helium": latest_tag("imputnet/helium", r"^[0-9]"),
            "helium-linux": latest_tag("imputnet/helium-linux", r"^[0-9]"),
        }
    else:
        result["upstream"] = {
            "helium": {"latest": None, "error": "network disabled"},
            "helium-linux": {"latest": None, "error": "network disabled"},
        }
    return result


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--no-network", action="store_true")
    ap.add_argument("--fail-on-outdated", action="store_true")
    args = ap.parse_args()

    result = report(args.source, network=not args.no_network)
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        components = result["components"]
        print(f"helium {components['helium_version']} "
              f"(chromium {components['chromium_version']})")
        print(f"  helium commit: {components['helium_revision']}")
        print(f"  helium-linux commit: {components['helium_linux_revision']}")
        print(f"  debian: {components['debian_revision']}")
        for name, version in components["assets"].items():
            print(f"  asset {name}: {version}")
        for name, row in result["upstream"].items():
            print(f"  upstream {name}: {row.get('latest') or '?'}"
                  + (f" ({row['error']})" if row.get("error") else ""))

    if args.fail_on_outdated:
        current = version_key(result["components"]["helium_version"])
        for row in result["upstream"].values():
            if row.get("latest") and version_key(row["latest"]) > current:
                return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
