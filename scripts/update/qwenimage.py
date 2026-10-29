#!/usr/bin/env python3
"""Check the ncnn submodule revision pinned by qwenimage-ncnn-vulkan.

An upstream main commit change is only safe when its src/ncnn submodule still
matches the separately pinned ncnn revision.  A mismatch blocks automatic
apply and requires a human update of both pins.
"""
import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run  # noqa: E402

ROOT = run.ROOT
DEFAULT_MAIN_PIN = ROOT / "modules" / "under-sea" / "packages" / "qwenimage-pin.scm"
DEFAULT_NCNN_PIN = ROOT / "modules" / "under-sea" / "packages" / "qwenimage-ncnn-pin.scm"


def define(text, symbol):
    match = re.search(
        rf'\(define-public {re.escape(symbol)} "([^"]+)"\)', text)
    if not match:
        raise SystemExit(f"cannot find {symbol}")
    return match.group(1)


def read_pins(main_pin=DEFAULT_MAIN_PIN, ncnn_pin=DEFAULT_NCNN_PIN):
    return {
        "main_version": define(Path(main_pin).read_text(), "%qwenimage-version"),
        "main_commit": define(Path(main_pin).read_text(), "%qwenimage-commit"),
        "ncnn_version": define(Path(ncnn_pin).read_text(), "%ncnn-version"),
        "ncnn_commit": define(Path(ncnn_pin).read_text(), "%ncnn-commit"),
    }


def submodule_sha(commit, timeout=30):
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "under-sea-update-qwenimage",
    }
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    url = ("https://api.github.com/repos/nihui/qwenimage-ncnn-vulkan/"
           f"contents/src/ncnn?ref={commit}")
    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = json.load(response)
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as exc:
        return None, str(exc)
    if payload.get("type") != "submodule" or not payload.get("sha"):
        return None, "src/ncnn is not a git submodule"
    return payload["sha"], None


def report(network=True, main_pin=DEFAULT_MAIN_PIN, ncnn_pin=DEFAULT_NCNN_PIN):
    pins = read_pins(main_pin, ncnn_pin)
    result = {
        "package": "qwenimage",
        "pins": pins,
        "submodule": {"current": pins["ncnn_commit"], "latest": None,
                      "status": "unknown", "error": None},
    }
    if not network:
        result["submodule"]["error"] = "network disabled"
        return result
    latest, error = submodule_sha(pins["main_commit"])
    result["submodule"]["latest"] = latest
    result["submodule"]["error"] = error
    if latest:
        result["submodule"]["status"] = (
            "current" if latest == pins["ncnn_commit"] else "changed")
    return result


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--main-pin", type=Path, default=DEFAULT_MAIN_PIN)
    ap.add_argument("--ncnn-pin", type=Path, default=DEFAULT_NCNN_PIN)
    ap.add_argument("--no-network", action="store_true")
    ap.add_argument("--fail-on-change", action="store_true")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    result = report(not args.no_network, args.main_pin, args.ncnn_pin)
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(f"qwenimage {result['pins']['main_version']}: "
              f"ncnn {result['submodule']['status']}")
        print(f"  pinned ncnn: {result['pins']['ncnn_commit']}")
        print(f"  upstream ncnn: {result['submodule']['latest'] or '?'}")
        if result["submodule"]["error"]:
            print(f"  error: {result['submodule']['error']}")
    if args.fail_on_change and result["submodule"]["status"] != "current":
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
