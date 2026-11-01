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
import urllib.parse
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


def candidate_source_urls(candidate):
    sources = {
        "helium": f"https://github.com/imputnet/helium/commit/{candidate['helium']['revision']}",
        "helium_linux": (
            "https://github.com/imputnet/helium-linux/commit/"
            f"{candidate['helium_linux']['revision']}"),
        "chromium_base": (
            f"https://tarballs.imput.net/chromium-{candidate['chromium_base']['version']}/"
            f"chromium-{candidate['chromium_base']['version']}-base.tar.zst"),
        "chromium_linux_x64": (
            f"https://tarballs.imput.net/chromium-{candidate['chromium_linux_x64']['version']}/"
            f"chromium-{candidate['chromium_linux_x64']['version']}-linux-x64.tar.zst"),
        "debian": (
            "https://salsa.debian.org/chromium-team/chromium/-/tree/"
            f"{urllib.parse.quote(candidate['debian']['revision'], safe='/')}"),
        **candidate_urls(candidate),
    }
    return sources


def candidate_review(source, candidate, discovery_evidence=None):
    """Render a concise diff and provenance report for human review."""
    normalized = validate_candidate_inputs(candidate)
    old = component_inventory(source)
    rows = []
    for name in CANDIDATE_FIELDS:
        current, proposed = old[name], normalized[name]
        digest = candidate.get(name, {}).get("sha256")
        fields = CANDIDATE_FIELDS[name]
        changed = {field: {"current": current[field], "proposed": proposed[field]}
                   for field in fields if current[field] != proposed[field]}
        if digest and digest != current["sha256"]:
            changed["sha256"] = {"current": current["sha256"], "proposed": digest}
        if name in ("chromium_base", "chromium_linux_x64") and \
                proposed["version"] != current["version"]:
            hash_note = "not fetched; prepared-tarball review required"
        elif digest == current["sha256"]:
            hash_note = "unchanged; reuses current pinned Guix hash"
        elif digest:
            hash_note = "resolved locally with Guix hash"
        else:
            hash_note = "not resolved yet"
        upstream = (discovery_evidence or {}).get("upstream_artifacts", {}).get(name, {})
        rows.append({
            "component": name,
            "changed": changed,
            "current_sha256": current["sha256"],
            "proposed_sha256": digest,
            "hash_status": hash_note,
            "source": candidate_source_urls(normalized)[name],
            "upstream_sha256": upstream.get("sha256"),
        })
    chromium_changed = any(
        normalized[name]["version"] != old[name]["version"]
        for name in ("chromium_base", "chromium_linux_x64"))
    review_items = []
    if chromium_changed:
        review_items.extend([
            "Check both Chromium prepared tarballs and their extraction layout.",
            "Rebase and build the local Chromium/Helium patch set against the new source.",
            "Update and verify Debian patches against the selected Chromium version.",
        ])
    if chromium_changed and normalized["esbuild"]["version"] == old["esbuild"]["version"]:
        review_items.append(
            "Confirm the retained esbuild pin still matches Chromium DevTools at this revision.")
    elif normalized["debian"]["revision"] != old["debian"]["revision"]:
        review_items.append("Review the selected Debian patch revision for compatibility.")
    changed_count = sum(bool(row["changed"]) for row in rows)
    lines = [
        "# Helium update review",
        "",
        f"Decision status: **{'human Chromium review required' if chromium_changed else 'ready for candidate review'}**",
        f"Changed components: {changed_count} of {len(rows)}.",
        "",
        "## Component diff and source evidence",
        "",
        "| Component | Current → proposed | Source | Hash status |",
        "|---|---|---|---|",
    ]
    for row in rows:
        values = row["changed"]
        if values:
            delta = "; ".join(
                f"{field}: `{item['current']}` → `{item['proposed']}`"
                for field, item in values.items())
        else:
            delta = "unchanged"
        source_url = row["source"]
        status = row["hash_status"]
        lines.append(
            f"| `{row['component']}` | {delta} | [source]({source_url}) | {status} |")
    lines.extend(["", "## Hash evidence", ""])
    for row in rows:
        lines.append(f"- `{row['component']}`: current `{row['current_sha256']}`")
        if row["proposed_sha256"]:
            lines.append(f"  - proposed `{row['proposed_sha256']}`")
        if row["upstream_sha256"]:
            lines.append(f"  - upstream-declared SHA-256 `{row['upstream_sha256']}`")
        lines.append(f"  - {row['hash_status']}")
    lines.extend(["", "## Human review items", ""])
    if review_items:
        lines.extend(f"- {item}" for item in review_items)
    else:
        lines.append("- No Chromium version change detected; review the listed source and hash evidence.")
    evidence = (discovery_evidence or {}).get("sources", {})
    if evidence:
        lines.extend(["", "## Discovery inputs", ""])
        for name, url in evidence.items():
            lines.append(f"- [{name}]({url})")
    return {"markdown": "\n".join(lines) + "\n", "components": rows,
            "chromium_changed": chromium_changed,
            "review_items": review_items, "changed_components": changed_count}


def fetch_file(url, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["curl", "-fsSL", "--retry", "3", "--retry-delay", "2",
                    "--max-time", "600", "-o", str(path), url], check=True)
    return path


def resolve_candidate_hashes(source, candidate, workdir):
    """Resolve safe source hashes; changed Chromium layers remain unhashed."""
    candidate = validate_candidate_inputs(candidate)
    old = component_inventory(source)
    chromium_changed = (
        candidate["chromium_base"]["version"] != old["chromium_base"]["version"])
    workdir = Path(workdir)
    workdir.mkdir(parents=True, exist_ok=True)
    resolved = {}
    for name, row in candidate.items():
        resolved[name] = dict(row)
        changed_prepared_tarball = (
            name in ("chromium_base", "chromium_linux_x64") and chromium_changed)
        if not changed_prepared_tarball:
            resolved[name]["sha256"] = old[name]["sha256"]
    for name, repo in (("helium", "imputnet/helium"),
                       ("helium_linux", "imputnet/helium-linux")):
        if (resolved[name]["revision"] != old[name]["revision"] or
                resolved[name]["version"] != old[name]["version"]):
            resolved[name]["sha256"] = guix_git_hash(
                repo, resolved[name]["revision"], workdir)
    # Debian's repository is hosted on Salsa rather than GitHub.
    if resolved["debian"]["revision"] != old["debian"]["revision"]:
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
        if all(candidate[name][field] == old[name][field]
               for field in CANDIDATE_FIELDS[name]):
            continue
        filename = hashlib.sha256(url.encode()).hexdigest()[:16]
        artifact = fetch_file(url, workdir / "downloads" / filename)
        resolved[name]["sha256"] = guix_file_hash(artifact)
    # Chromium tarballs are intentionally not fetched: they are large prepared
    # sources and their changes require a separate human integration review.
    if chromium_changed:
        validate_candidate_inputs(resolved)
    else:
        validate_candidate(resolved)
    return resolved


def transaction(source, candidate, apply=False, accept_chromium_change=False):
    """Compare all nine origins, then atomically replace the single SCM file."""
    validate_candidate(candidate)
    old = component_inventory(source)
    for name in ("chromium_base", "chromium_linux_x64"):
        if candidate[name] != old[name] and not accept_chromium_change:
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
    replace_scalar("%chromium-version", candidate["chromium_base"]["version"])
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
    upstream_artifacts = {}
    for component, section in (("search_engines", "search_engines_data"),
                              ("onboarding", "onboarding"),
                              ("ublock", "ublock_origin")):
        values = deps[section]
        upstream_artifacts[component] = {
            "url": values["url"] % {"version": values["version"]},
            "sha256": values.get("sha256"),
        }
    return candidate, {
        "helium_tag": helium_tag,
        "helium_linux_tag": linux_tag,
        "chromium_version": chromium_version,
        "sources": {
            "helium tag": f"https://github.com/imputnet/helium/tree/{helium_tag}",
            "helium-linux tag": f"https://github.com/imputnet/helium-linux/tree/{linux_tag}",
            "pinned chromium_version.txt": base + helium_revision + "/chromium_version.txt",
            "pinned deps.ini": base + helium_revision + "/deps.ini",
        },
        "upstream_artifacts": upstream_artifacts,
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
    ap.add_argument("--review-candidate", type=Path,
                    help="write a human-readable diff/provenance report for a candidate")
    ap.add_argument("--review-output", type=Path,
                    help="Markdown report path (requires --review-candidate)")
    ap.add_argument("--workdir", type=Path,
                    help="keep fetched candidate sources in this directory")
    ap.add_argument("--apply", action="store_true",
                    help="atomically apply a complete candidate transaction")
    ap.add_argument("--accept-chromium-change", action="store_true",
                    help="allow a reviewed Chromium version/hash change")
    args = ap.parse_args()

    if args.resolve_candidate and not args.output_candidate:
        ap.error("--resolve-candidate requires --output-candidate")
    if args.output_candidate and not args.resolve_candidate:
        ap.error("--output-candidate requires --resolve-candidate")
    if args.discover_candidate and args.no_network:
        ap.error("--discover-candidate requires network access")
    if args.review_candidate and not args.review_output:
        ap.error("--review-candidate requires --review-output")
    if args.review_output and not args.review_candidate:
        ap.error("--review-output requires --review-candidate")

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
        evidence_path = args.discover_candidate.with_name(
            args.discover_candidate.name + ".evidence.json")
        evidence_path.write_text(json.dumps(discovery, indent=2, sort_keys=True) + "\n")
        result["candidate_discovery"] = discovery
        result["candidate_file"] = str(args.discover_candidate)
        result["evidence_file"] = str(evidence_path)
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
            source_evidence = args.resolve_candidate.with_name(
                args.resolve_candidate.name + ".evidence.json")
            if source_evidence.is_file():
                evidence_copy = args.output_candidate.with_name(
                    args.output_candidate.name + ".evidence.json")
                evidence_copy.write_text(source_evidence.read_text())
                result["evidence_file"] = str(evidence_copy)
        except (ValueError, OSError, subprocess.SubprocessError,
                json.JSONDecodeError) as exc:
            ap.error(str(exc))
    if args.review_candidate:
        try:
            candidate = json.loads(args.review_candidate.read_text())
            evidence_path = args.review_candidate.with_name(
                args.review_candidate.name + ".evidence.json")
            evidence = (json.loads(evidence_path.read_text())
                        if evidence_path.is_file() else None)
            review = candidate_review(args.source, candidate, evidence)
            args.review_output.write_text(review["markdown"])
            result["review_file"] = str(args.review_output)
            result["review_summary"] = {
                "chromium_changed": review["chromium_changed"],
                "changed_components": review["changed_components"],
                "review_items": review["review_items"],
            }
        except (ValueError, OSError, json.JSONDecodeError, KeyError) as exc:
            ap.error(str(exc))
    if args.apply and not args.candidate:
        ap.error("--apply requires --candidate")
    if args.accept_chromium_change and not args.candidate:
        ap.error("--accept-chromium-change requires --candidate")
    if args.candidate:
        try:
            transaction_result = transaction(
                args.source, json.loads(args.candidate.read_text()), apply=args.apply,
                accept_chromium_change=args.accept_chromium_change)
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
