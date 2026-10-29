#!/usr/bin/env python3
"""Detect upstream versions for packages in planning/update-manifest.json.

This is the detect-only stage of the update pipeline.  It never edits the
tree, runs package build scripts, or invokes a package manager.  It reports a
JSON matrix that CI can turn into prepare jobs.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = ROOT / "planning" / "update-manifest.json"


def load_manifest(path):
    data = json.loads(Path(path).read_text())
    if data.get("schema") != 1:
        raise SystemExit(f"{path}: unsupported schema {data.get('schema')!r}")
    packages = data.get("packages")
    if not isinstance(packages, dict) or not packages:
        raise SystemExit(f"{path}: packages must be a non-empty object")
    for name, pkg in packages.items():
        for key in ("module", "package", "pin", "upstream", "adapter",
                    "autonomy"):
            if key not in pkg:
                raise SystemExit(f"{path}: {name}: missing {key}")
        if not (pkg.get("version_symbol") or pkg.get("version_regex")):
            raise SystemExit(
                f"{path}: {name}: needs version_symbol or version_regex")
        if not (ROOT / pkg["pin"]).is_file():
            raise SystemExit(f"{path}: {name}: pin does not exist: {pkg['pin']}")
        upstream = pkg["upstream"]
        kind = upstream.get("type")
        if kind in ("github", "github-release"):
            if not upstream.get("repo") or not upstream.get("tag_regex"):
                raise SystemExit(
                    f"{path}: {name}: github upstream needs repo/tag_regex")
            re.compile(upstream["tag_regex"])
            if kind == "github-release" and not upstream.get("assets"):
                raise SystemExit(
                    f"{path}: {name}: github-release needs assets")
        elif kind == "pypi":
            if not upstream.get("project"):
                raise SystemExit(
                    f"{path}: {name}: pypi upstream needs project")
        elif kind == "git-commit":
            for key in ("repo", "branch", "version_file", "version_regex"):
                if not upstream.get(key):
                    raise SystemExit(
                        f"{path}: {name}: git-commit needs {key}")
            re.compile(upstream["version_regex"])
        else:
            raise SystemExit(
                f"{path}: {name}: unsupported upstream type {kind!r}")
        if pkg.get("version_regex"):
            re.compile(pkg["version_regex"])
    return data


def current_commit(pkg):
    text = (ROOT / pkg["pin"]).read_text()
    symbol = re.escape(pkg["commit_symbol"])
    match = re.search(rf'\(define(?:-public)?\s+{symbol}\s+"([^"]+)"', text)
    if not match:
        raise SystemExit(f"{pkg['pin']}: cannot find {pkg['commit_symbol']}")
    return match.group(1)


def git_head(repo, branch, timeout=30):
    output = subprocess.check_output(
        ["git", "ls-remote", f"https://github.com/{repo}.git",
         f"refs/heads/{branch}"], text=True, timeout=timeout)
    return output.split("	", 1)[0].strip()


def current_version(pkg):
    path = ROOT / pkg["pin"]
    text = path.read_text()
    if pkg.get("version_regex"):
        match = re.search(pkg["version_regex"], text)
        if match:
            return match.group(1)
        raise SystemExit(
            f"{path}: cannot match version_regex {pkg['version_regex']!r}")
    symbol = re.escape(pkg["version_symbol"])
    match = re.search(rf'\(define(?:-public)?\s+{symbol}\s+"([^"]+)"', text)
    if not match:
        raise SystemExit(f"{path}: cannot find {pkg['version_symbol']}")
    return match.group(1)


def version_key(text):
    return tuple(int(part) for part in re.findall(r"\d+", text))


def tag_version(tag, version_regex=None):
    if version_regex:
        match = re.search(version_regex, tag)
        return match.group(1) if match else None
    match = re.match(r"^[^0-9]*([0-9].*)$", tag)
    return match.group(1) if match else tag


PRERELEASE_RX = re.compile(r"-(?:alpha|beta|rc|pre|dev)(?:[.\-]|$)", re.I)


def select_tag(tags, tag_regex, allow_prerelease=False):
    rx = re.compile(tag_regex)
    candidates = [
        tag for tag in tags
        if rx.search(tag)
        and (allow_prerelease or not PRERELEASE_RX.search(tag))
    ]
    if not candidates:
        return None
    # Prefer the highest numeric version; tags are stable strings.
    return max(candidates, key=version_key)


def github_tags(repo, token=None, timeout=30):
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "under-sea-update-detect",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    url = f"https://api.github.com/repos/{repo}/tags?per_page=100"
    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = json.load(response)
        return [entry["name"] for entry in payload if "name" in entry]
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError):
        # API rate limits are common on shared runners; ls-remote has no such
        # quota and is enough for tag-based packages.
        output = subprocess.check_output(
            ["git", "ls-remote", "--tags", f"https://github.com/{repo}.git"],
            text=True, timeout=timeout)
        tags = []
        for line in output.splitlines():
            ref = line.split("\t", 1)[-1]
            if ref.startswith("refs/tags/") and not ref.endswith("^{}"):
                tags.append(ref[len("refs/tags/"):])
        return tags


def pypi_version(project, timeout=30):
    url = f"https://pypi.org/pypi/{project}/json"
    request = urllib.request.Request(
        url, headers={"User-Agent": "under-sea-update-detect"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.load(response)["info"]["version"]


def detect_package(name, pkg, token=None):
    current = current_version(pkg)
    upstream = pkg["upstream"]
    tag = None
    try:
        if upstream["type"] in ("github", "github-release"):
            tags = github_tags(upstream["repo"], token=token)
            tag = select_tag(
                tags, upstream["tag_regex"],
                allow_prerelease=upstream.get("allow_prerelease", False))
            latest = (tag_version(tag, upstream.get("version_regex"))
                      if tag else None)
        elif upstream["type"] == "git-commit":
            tag = git_head(upstream["repo"], upstream["branch"])
            latest = current
        else:
            latest = pypi_version(upstream["project"])
        status = "error" if latest is None else (
            "current" if version_key(latest) <= version_key(current)
            else "outdated")
        error = None if latest is not None else "no upstream version"
    except Exception as exc:  # noqa: BLE001
        tag = None
        latest = None
        status = "error"
        error = str(exc)
    return {
        "package": name,
        "current": current,
        "latest": latest,
        "tag": tag,
        "status": status,
        "commit": tag if upstream.get("type") == "git-commit" else None,
        "current_commit": (current_commit(pkg)
                           if upstream.get("type") == "git-commit" else None),
        "autonomy": pkg["autonomy"],
        "adapter": pkg["adapter"],
        "pin": pkg["pin"],
        "error": error,
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("command", nargs="?", default="detect",
                    choices=("detect", "validate", "prepare", "verify"))
    ap.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    ap.add_argument("--package", action="append", default=[],
                    help="package name to check (repeatable)")
    ap.add_argument("--all", action="store_true", help="check every manifest entry")
    ap.add_argument("--json", action="store_true", help="emit JSON (default)")
    ap.add_argument("--fail-on-outdated", action="store_true",
                    help="exit 1 when any package is outdated or errored")
    ap.add_argument("--version")
    ap.add_argument("--workdir", type=Path)
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--verify", action="store_true")
    args = ap.parse_args()
    data = load_manifest(args.manifest)
    if args.command == "validate":
        print(f"ok: {args.manifest} ({len(data['packages'])} packages)")
        return 0
    packages = data["packages"]
    if args.command in ("prepare", "verify"):
        if len(args.package) != 1:
            ap.error(f"{args.command} needs exactly one --package")
        name = args.package[0]
        if name not in packages:
            ap.error(f"unknown package: {name}")
        pkg = packages[name]
        if args.command == "prepare":
            if pkg["autonomy"] in ("L0", "L1"):
                ap.error(f"{name}: autonomy {pkg['autonomy']} is detect-only")
            script = {
                "bun": "bun.py",
                "go": "go.py",
                "cargo": "cargo.py",
                "npm": "npm.py",
                "codex-cargo": "codex.py",
                "cargo-lock": "codex.py",
                "dae-go": "dae.py",
            }.get(pkg["adapter"], "prepare.py")
            cmd = [sys.executable, str(ROOT / "scripts" / "update" / script),
                   "--package", name, "--manifest", str(args.manifest)]
            if args.version:
                cmd += ["--version", args.version]
            if args.workdir:
                cmd += ["--workdir", str(args.workdir)]
            if args.apply:
                cmd.append("--apply")
            if args.verify:
                cmd.append("--verify")
            return subprocess.run(cmd).returncode
        cmd = [sys.executable, str(ROOT / "scripts" / "update" / "verify.py"),
               "--package", name, "--manifest", str(args.manifest)]
        return subprocess.run(cmd).returncode
    selected = list(packages) if args.all else args.package
    if not selected:
        ap.error("pass --all or --package NAME")
    unknown = [name for name in selected if name not in packages]
    if unknown:
        ap.error(f"unknown package(s): {', '.join(unknown)}")
    token = os.environ.get("GITHUB_TOKEN")
    report = [detect_package(name, packages[name], token=token)
              for name in selected]
    print(json.dumps(report, indent=2, sort_keys=True))
    if args.fail_on_outdated and any(row["status"] != "current" for row in report):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
