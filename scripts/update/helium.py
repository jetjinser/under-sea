#!/usr/bin/env python3
"""Discover Helium update candidates, resolve fixed hashes, and transact pins.

Helium is assembled from several independent origins.  Candidate discovery
collects upstream tags and asset metadata; Chromium source changes still need
human integration review before the transaction can proceed.
"""
import argparse
import configparser
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
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
ORIGINS = {
    "helium": "%helium-origin",
    "helium_linux": "%helium-linux-origin",
    "search_engines": "%search-engines-origin",
    "onboarding": "%onboarding-origin",
    "ublock": "%ublock-origin",
    "esbuild": "%esbuild-origin",
    "debian": "%debian-origin",
    "chromium_base": "%chromium-base-tarball-origin",
    "chromium_linux_x64": "%chromium-linux-x64-tarball-origin",
}
CANDIDATE_FIELDS = {
    "helium": ("version", "revision"),
    "helium_linux": ("version", "revision"),
    "chromium_base": ("version",),
    "chromium_linux_x64": ("version",),
    "search_engines": ("release",),
    "onboarding": ("release",),
    "ublock": ("version",),
    "esbuild": ("version",),
    "debian": ("revision",),
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


def _origin_block(text, symbol):
    match = re.search(r"\(define " + re.escape(symbol) + r"\b", text)
    if not match:
        raise SystemExit(f"cannot find origin {symbol}")
    end = text.find("\n(define ", match.end())
    return match.start(), len(text) if end < 0 else end


def _origin_hash(text, symbol):
    start, end = _origin_block(text, symbol)
    match = re.search(r'\(base32\s+"([0-9a-z]{52})"\)', text[start:end])
    if not match:
        raise SystemExit(f"cannot find base32 sha256 for {symbol}")
    return match.group(1)


def component_inventory(source):
    text = Path(source).read_text()
    components = read_components(source)
    versions = components["assets"]
    rows = {
        "helium": {"version": components["helium_version"],
                   "revision": components["helium_revision"]},
        "helium_linux": {"version": components["helium_version"],
                         "revision": components["helium_linux_revision"]},
        "chromium_base": {"version": components["chromium_version"]},
        "chromium_linux_x64": {"version": components["chromium_version"]},
        "search_engines": {"release": versions["search_engines"]},
        "onboarding": {"release": versions["onboarding"]},
        "ublock": {"version": versions["ublock"]},
        "esbuild": {"version": versions["esbuild"]},
        "debian": {"revision": components["debian_revision"]},
    }
    return {
        name: {**row, "sha256": _origin_hash(text, ORIGINS[name])}
        for name, row in rows.items()
    }


def validate_candidate(candidate):
    if not isinstance(candidate, dict) or set(candidate) != set(CANDIDATE_FIELDS):
        raise ValueError("candidate must contain exactly the nine Helium components")
    for name, fields in CANDIDATE_FIELDS.items():
        row = candidate[name]
        if not isinstance(row, dict) or set(row) != set(fields) | {"sha256"}:
            raise ValueError(f"{name}: expected fields {sorted(set(fields) | {'sha256'})}")
        for field in fields:
            if not isinstance(row[field], str) or not row[field] or "\n" in row[field] or '"' in row[field]:
                raise ValueError(f"{name}.{field}: invalid value")
        if not re.fullmatch(r"[0-9a-z]{52}", row["sha256"]):
            raise ValueError(f"{name}.sha256: expected a Guix base32 SHA-256")
    for name in ("helium", "helium_linux"):
        if not re.fullmatch(r"[0-9a-f]{40}", candidate[name]["revision"]):
            raise ValueError(f"{name}.revision: expected a full git commit")
    if candidate["helium"]["version"] != candidate["helium_linux"]["version"]:
        raise ValueError("helium and helium-linux versions must match")
    if candidate["chromium_base"]["version"] != candidate["chromium_linux_x64"]["version"]:
        raise ValueError("Chromium base and linux-x64 versions must match")


def validate_candidate_inputs(candidate):
    """Validate version/revision fields; generated hashes may be omitted."""
    if not isinstance(candidate, dict) or set(candidate) != set(CANDIDATE_FIELDS):
        raise ValueError("candidate must contain exactly the nine Helium components")
    normalized = {}
    for name, fields in CANDIDATE_FIELDS.items():
        row = candidate[name]
        if not isinstance(row, dict) or set(row) - (set(fields) | {"sha256"}) \
                or not set(fields).issubset(row):
            raise ValueError(f"{name}: expected fields {sorted(fields)} and optional sha256")
        normalized[name] = {field: row[field] for field in fields}
    for name in ("helium", "helium_linux"):
        revision = normalized[name]["revision"]
        if not re.fullmatch(r"[0-9a-f]{40}", revision):
            raise ValueError(f"{name}.revision: expected a full git commit")
    if normalized["helium"]["version"] != normalized["helium_linux"]["version"]:
        raise ValueError("helium and helium-linux versions must match")
    if normalized["chromium_base"]["version"] != normalized["chromium_linux_x64"]["version"]:
        raise ValueError("Chromium base and linux-x64 versions must match")
    for name, fields in CANDIDATE_FIELDS.items():
        for field in fields:
            value = normalized[name][field]
            if not isinstance(value, str) or not value or "\n" in value or '"' in value:
                raise ValueError(f"{name}.{field}: invalid value")
    return normalized


def guix_file_hash(path):
    return subprocess.check_output(
        ["guix", "hash", "-H", "sha256", "-f", "nix-base32", str(path)],
        text=True).strip()


def guix_git_hash(repo, revision, workdir):
    checkout = workdir / ("git-" + hashlib.sha256(
        f"{repo}@{revision}".encode()).hexdigest()[:12])
    if not checkout.exists():
        checkout.mkdir(parents=True)
        subprocess.run(["git", "init", str(checkout)], check=True)
        subprocess.run(["git", "-C", str(checkout), "remote", "add", "origin",
                        f"https://github.com/{repo}.git"], check=True)
        subprocess.run(["git", "-C", str(checkout), "fetch", "--depth=1", "origin",
                        revision], check=True)
        subprocess.run(["git", "-C", str(checkout), "checkout", "--detach",
                        "FETCH_HEAD"], check=True)
    return subprocess.check_output(
        ["guix", "hash", "--serializer=nar", "--exclude-vcs", "-H", "sha256",
         "-f", "nix-base32", str(checkout)], text=True).strip()


def candidate_urls(candidate):
    return {
        "search_engines": (
            f"https://github.com/imputnet/helium-nonfree-assets/releases/download/"
            f"{candidate['search_engines']['release']}/nonfree-search-engines-data-"
            f"{candidate['search_engines']['release']}.tar.gz"),
        "onboarding": (
            f"https://github.com/imputnet/helium-onboarding/releases/download/"
            f"{candidate['onboarding']['release']}/helium-onboarding-"
            f"{candidate['onboarding']['release']}.tar.gz"),
        "ublock": (
            f"https://github.com/imputnet/uBlock/releases/download/"
            f"{candidate['ublock']['version']}/uBlock0_"
            f"{candidate['ublock']['version']}.chromium.zip"),
        "esbuild": (
            "https://registry.npmjs.org/@esbuild/linux-x64/-/linux-x64-"
            f"{candidate['esbuild']['version']}.tgz"),
    }


def fetch_file(url, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["curl", "-fsSL", "--retry", "3", "--retry-delay", "2",
                    "--max-time", "600", "-o", str(path), url], check=True)
    return path


def resolve_candidate_hashes(source, candidate, workdir):
    """Fill candidate hashes from pinned upstream sources without applying."""
    candidate = validate_candidate_inputs(candidate)
    old = component_inventory(source)
    if candidate["chromium_base"]["version"] != old["chromium_base"]["version"]:
        raise ValueError("Chromium prepared-tarball version changed; human merge required")
    workdir = Path(workdir)
    workdir.mkdir(parents=True, exist_ok=True)
    resolved = {name: {**row, "sha256": old[name]["sha256"]}
                for name, row in candidate.items()}
    for name, repo in (("helium", "imputnet/helium"),
                       ("helium_linux", "imputnet/helium-linux")):
        resolved[name]["sha256"] = guix_git_hash(
            repo, resolved[name]["revision"], workdir)
    # Debian's repository is hosted on Salsa rather than GitHub.
    debian_checkout = workdir / ("git-debian-" + hashlib.sha256(
        resolved["debian"]["revision"].encode()).hexdigest()[:12])
    if not debian_checkout.exists():
        debian_checkout.mkdir(parents=True)
        subprocess.run(["git", "init", str(debian_checkout)], check=True)
        subprocess.run(["git", "-C", str(debian_checkout), "remote", "add", "origin",
                        "https://salsa.debian.org/chromium-team/chromium.git"], check=True)
        subprocess.run(["git", "-C", str(debian_checkout), "fetch", "--depth=1", "origin",
                        resolved["debian"]["revision"]], check=True)
        subprocess.run(["git", "-C", str(debian_checkout), "checkout", "--detach",
                        "FETCH_HEAD"], check=True)
    resolved["debian"]["sha256"] = subprocess.check_output(
        ["guix", "hash", "--serializer=nar", "--exclude-vcs", "-H", "sha256",
         "-f", "nix-base32", str(debian_checkout)], text=True).strip()

    for name, url in candidate_urls(candidate).items():
        filename = hashlib.sha256(url.encode()).hexdigest()[:16]
        artifact = fetch_file(url, workdir / "downloads" / filename)
        resolved[name]["sha256"] = guix_file_hash(artifact)
    # Chromium tarballs are intentionally not fetched: they are large prepared
    # sources and their changes require a separate human integration review.
    validate_candidate(resolved)
    return resolved


def transaction(source, candidate, apply=False):
    """Compare all nine origins, then atomically replace the single SCM file."""
    validate_candidate(candidate)
    old = component_inventory(source)
    for name in ("chromium_base", "chromium_linux_x64"):
        if candidate[name] != old[name]:
            raise ValueError("Chromium prepared-tarball changes require a human merge")
    text = Path(source).read_text()
    changes = []

    def replace_scalar(symbol, value):
        nonlocal text
        pattern = r'(\(define ' + re.escape(symbol) + r' ")[^"]+("\))'
        updated, count = re.subn(pattern, lambda m: m.group(1) + value + m.group(2), text, count=1)
        if count != 1:
            raise ValueError(f"cannot update {symbol}")
        text = updated

    replace_scalar("%helium-version", candidate["helium"]["version"])
    replace_scalar("%helium-revision", candidate["helium"]["revision"])
    replace_scalar("%helium-linux-revision", candidate["helium_linux"]["revision"])
    replace_scalar("%debian-revision", candidate["debian"]["revision"])

    value_locations = {
        "search_engines": ("%search-engines-origin", old["search_engines"]["release"],
                           candidate["search_engines"]["release"]),
        "onboarding": ("%onboarding-origin", old["onboarding"]["release"],
                       candidate["onboarding"]["release"]),
        "ublock": ("%ublock-origin", old["ublock"]["version"], candidate["ublock"]["version"]),
        "esbuild": ("%esbuild-origin", old["esbuild"]["version"], candidate["esbuild"]["version"]),
    }
    for name, (symbol, previous, current) in value_locations.items():
        start, end = _origin_block(text, symbol)
        block = text[start:end]
        if previous not in block:
            raise ValueError(f"{name}: pinned value is not present in its origin")
        block = block.replace(previous, current)
        text = text[:start] + block + text[end:]

    # Refresh component hashes against the current text, in reverse source order.
    replacements = []
    for name, symbol in ORIGINS.items():
        start, end = _origin_block(text, symbol)
        block = text[start:end]
        match = re.search(r'(\(base32\s+")[0-9a-z]{52}("\))', block)
        if not match:
            raise ValueError(f"cannot update hash for {name}")
        block = block[:match.start()] + match.group(1) + candidate[name]["sha256"] + match.group(2) + block[match.end():]
        replacements.append((start, end, block))
    for start, end, block in reversed(replacements):
        text = text[:start] + block + text[end:]

    new_source = component_inventory_from_text(text)
    diff = {name: {"old": old[name], "new": new_source[name]}
            for name in CANDIDATE_FIELDS if old[name] != new_source[name]}
    if apply and diff:
        path = Path(source)
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent,
                                         prefix=path.name + ".", delete=False) as out:
            temp_path = Path(out.name)
            out.write(text)
        os.chmod(temp_path, path.stat().st_mode)
        os.replace(temp_path, path)
    return {"applied": bool(apply and diff), "changed": diff,
            "unchanged": sorted(set(CANDIDATE_FIELDS) - set(diff))}


def component_inventory_from_text(text):
    # Reuse the same parser without writing a temporary source file.
    components = read_components_from_text(text)
    assets = components["assets"]
    rows = {
        "helium": {"version": components["helium_version"], "revision": components["helium_revision"]},
        "helium_linux": {"version": components["helium_version"], "revision": components["helium_linux_revision"]},
        "chromium_base": {"version": components["chromium_version"]},
        "chromium_linux_x64": {"version": components["chromium_version"]},
        "search_engines": {"release": assets["search_engines"]},
        "onboarding": {"release": assets["onboarding"]},
        "ublock": {"version": assets["ublock"]},
        "esbuild": {"version": assets["esbuild"]},
        "debian": {"revision": components["debian_revision"]},
    }
    return {name: {**row, "sha256": _origin_hash(text, ORIGINS[name])}
            for name, row in rows.items()}


def read_components_from_text(text):
    components = {}
    for name, pattern in DEFINITIONS.items():
        match = re.search(pattern, text)
        if not match:
            raise ValueError(f"cannot find {name}")
        components[name] = match.group(1)
    components["assets"] = {}
    for name, pattern in ASSETS.items():
        match = re.search(pattern, text)
        if not match:
            raise ValueError(f"cannot find asset {name}")
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


def latest_tag_revision(repo, pattern):
    output = subprocess.check_output(
        ["git", "ls-remote", "--tags", f"https://github.com/{repo}.git"],
        text=True, timeout=30)
    refs = {}
    peeled = {}
    for line in output.splitlines():
        revision, ref = line.split("\t", 1)
        if not ref.startswith("refs/tags/"):
            continue
        name = ref[len("refs/tags/"):]
        if name.endswith("^{}"):
            peeled[name[:-3]] = revision
        else:
            refs[name] = revision
    tags = [tag for tag in refs if re.search(pattern, tag)]
    if not tags:
        raise ValueError(f"no matching tag for {repo}")
    tag = max(tags, key=version_key)
    return tag, peeled.get(tag, refs[tag])


def remote_text(url):
    request = urllib.request.Request(
        url, headers={"User-Agent": "under-sea-helium-updater"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read().decode("utf-8")


def discover_candidate(source):
    """Build a reviewable candidate from latest tags and pinned upstream deps."""
    helium_tag, helium_revision = latest_tag_revision(
        "imputnet/helium", r"^[0-9]")
    linux_tag, linux_revision = latest_tag_revision(
        "imputnet/helium-linux", r"^[0-9]")
    if linux_tag != helium_tag and not linux_tag.startswith(helium_tag + "."):
        raise ValueError(
            f"latest source tags do not match: helium={helium_tag}, helium-linux={linux_tag}")
    base = "https://raw.githubusercontent.com/imputnet/helium/"
    chromium_version = remote_text(
        base + helium_revision + "/chromium_version.txt").strip()
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){3}", chromium_version):
        raise ValueError(f"unexpected chromium_version.txt value: {chromium_version!r}")
    deps = configparser.ConfigParser(interpolation=None)
    deps.read_string(remote_text(base + helium_revision + "/deps.ini"))
    old = component_inventory(source)
    package_version = linux_tag
    # The Linux packaging release may have a trailing rebuild counter (e.g.
    # 0.20.3.1), while the Chromium source tag is 0.20.3.
    candidate = {
        "helium": {"version": package_version, "revision": helium_revision},
        "helium_linux": {"version": package_version, "revision": linux_revision},
        "chromium_base": {"version": chromium_version},
        "chromium_linux_x64": {"version": chromium_version},
        "search_engines": {"release": deps["search_engines_data"]["version"]},
        "onboarding": {"release": deps["onboarding"]["version"]},
        "ublock": {"version": deps["ublock_origin"]["version"]},
        # esbuild is pinned by Chromium's DevTools dependency graph, not deps.ini.
        # Keep the current value and require review when Chromium moves.
        "esbuild": {"version": old["esbuild"]["version"]},
        # Debian patches are deliberately not selected automatically; their
        # compatibility is reviewed against the Chromium bump.
        "debian": {"revision": old["debian"]["revision"]},
    }
    validate_candidate_inputs(candidate)
    return candidate, {
        "helium_tag": helium_tag,
        "helium_linux_tag": linux_tag,
        "chromium_version": chromium_version,
        "review_required": [
            "Chromium prepared tarballs and patch compatibility",
            "Debian patch revision compatibility",
            "DevTools esbuild version (retained from current pin)",
        ],
    }


def report(source, network=True):
    components = read_components(source)
    result = {
        "package": "helium",
        "level": "L3",
        "status": "atomic-source-update; Chromium tarballs require human merge",
        "components": components,
        "component_inventory": component_inventory(source),
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
    ap.add_argument("--candidate", type=Path,
                    help="complete JSON transaction containing all nine components")
    ap.add_argument("--write-current-candidate", type=Path,
                    help="write the current nine-component matrix as a transaction template")
    ap.add_argument("--discover-candidate", type=Path,
                    help="write a candidate from latest Helium tags and deps.ini")
    ap.add_argument("--resolve-candidate", type=Path,
                    help="fetch candidate sources and replace their hashes")
    ap.add_argument("--output-candidate", type=Path,
                    help="write the resolved candidate JSON (requires --resolve-candidate)")
    ap.add_argument("--workdir", type=Path,
                    help="keep fetched candidate sources in this directory")
    ap.add_argument("--apply", action="store_true",
                    help="atomically apply a complete candidate transaction")
    args = ap.parse_args()

    if args.resolve_candidate and not args.output_candidate:
        ap.error("--resolve-candidate requires --output-candidate")
    if args.output_candidate and not args.resolve_candidate:
        ap.error("--output-candidate requires --resolve-candidate")
    if args.discover_candidate and args.no_network:
        ap.error("--discover-candidate requires network access")

    result = report(args.source, network=not args.no_network)
    if args.write_current_candidate:
        args.write_current_candidate.write_text(
            json.dumps(result["component_inventory"], indent=2, sort_keys=True) + "\n")
    if args.discover_candidate:
        try:
            candidate, discovery = discover_candidate(args.source)
        except (ValueError, OSError, subprocess.SubprocessError,
                urllib.error.URLError, KeyError) as exc:
            ap.error(str(exc))
        args.discover_candidate.write_text(
            json.dumps(candidate, indent=2, sort_keys=True) + "\n")
        result["candidate_discovery"] = discovery
        result["candidate_file"] = str(args.discover_candidate)
    if args.resolve_candidate:
        try:
            candidate = json.loads(args.resolve_candidate.read_text())
            if args.workdir:
                resolved = resolve_candidate_hashes(
                    args.source, candidate, args.workdir)
            else:
                with tempfile.TemporaryDirectory(prefix="helium-candidate-") as temp:
                    resolved = resolve_candidate_hashes(args.source, candidate, temp)
            args.output_candidate.write_text(
                json.dumps(resolved, indent=2, sort_keys=True) + "\n")
            result["resolved_candidate"] = str(args.output_candidate)
        except (ValueError, OSError, subprocess.SubprocessError,
                json.JSONDecodeError) as exc:
            ap.error(str(exc))
    if args.apply and not args.candidate:
        ap.error("--apply requires --candidate")
    if args.candidate:
        try:
            transaction_result = transaction(
                args.source, json.loads(args.candidate.read_text()), apply=args.apply)
        except (ValueError, OSError, json.JSONDecodeError) as exc:
            ap.error(str(exc))
        result["transaction"] = transaction_result
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
        if "transaction" in result:
            transaction_result = result["transaction"]
            print("  transaction: " + ("applied" if transaction_result["applied"] else "dry-run"))
            for name in sorted(CANDIDATE_FIELDS):
                change = transaction_result["changed"].get(name)
                if change:
                    print(f"    {name}: {json.dumps(change['old'], sort_keys=True)} -> "
                          f"{json.dumps(change['new'], sort_keys=True)}")
                else:
                    print(f"    {name}: unchanged")

    if args.fail_on_outdated:
        current = version_key(result["components"]["helium_version"])
        for row in result["upstream"].values():
            if row.get("latest") and version_key(row["latest"]) > current:
                return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
