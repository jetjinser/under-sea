#!/usr/bin/env python3
"""Prepare a Hermes source update without regenerating its dependency lock.

The Hermes source tag and Python version move independently.  This adapter
updates only ``%hermes-version``, ``%hermes-release`` and ``%hermes-source`` in
``hermes-lock.scm``; the Python/Rust closure remains untouched for review.
"""
import argparse
import json
import re
import subprocess
import sys
import tarfile
import tomllib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepare  # noqa: E402
import run  # noqa: E402

ROOT = run.ROOT


def source_block(release, digest):
    return f'''\
(define-public %hermes-source (origin (method url-fetch) (uri "https://codeload.github.com/NousResearch/hermes-agent/tar.gz/refs/tags/v{release}")
        (file-name "hermes-agent-{release}.tar.gz")
        (sha256 (base16-string->bytevector "{digest}"))))'''


def render_lock(text, release, version, digest):
    if not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise ValueError("Hermes source digest is not a base16 sha256")
    text = re.sub(
        r'\(define-public %hermes-version "[^"]+"\)',
        f'(define-public %hermes-version "{version}")', text, count=1)
    text = re.sub(
        r'\(define-public %hermes-release "[^"]+"\)',
        f'(define-public %hermes-release "{release}")', text, count=1)
    start = text.find("(define-public %hermes-source")
    end = text.find("\n(define-public %hermes-python-sources", start)
    if start < 0 or end < 0:
        raise ValueError("cannot locate %hermes-source in hermes-lock.scm")
    return text[:start] + source_block(release, digest) + text[end:]


def archive_version(archive, workdir):
    with tarfile.open(archive) as tar:
        member = next(
            (m for m in tar.getmembers()
             if m.name.endswith("/pyproject.toml")), None)
        if member is None:
            raise SystemExit("Hermes archive has no pyproject.toml")
        data = tomllib.loads(tar.extractfile(member).read().decode())
    version = data.get("project", {}).get("version")
    if not version:
        raise SystemExit("Hermes pyproject.toml has no project.version")
    return version


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--package", required=True)
    ap.add_argument("--version")
    ap.add_argument("--workdir", type=Path, required=True)
    ap.add_argument("--manifest", type=Path, default=run.DEFAULT_MANIFEST)
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--verify", action="store_true")
    args = ap.parse_args()

    data = run.load_manifest(args.manifest)
    pkg = data["packages"].get(args.package)
    if not pkg:
        raise SystemExit(f"unknown package: {args.package}")
    if pkg.get("adapter") != "hermes":
        raise SystemExit(f"{args.package}: not a Hermes source package")
    release = args.version or run.detect_package(args.package, pkg)["latest"]
    if not release:
        raise SystemExit("cannot determine the Hermes release")

    args.workdir.mkdir(parents=True, exist_ok=True)
    url = ("https://codeload.github.com/NousResearch/hermes-agent/tar.gz/"
           f"refs/tags/v{release}")
    file_name = f"hermes-agent-{release}.tar.gz"
    archive = prepare.fetch(url, args.workdir / file_name)
    digest = prepare.sha256_hex(archive)
    version = archive_version(archive, args.workdir)

    current = (ROOT / pkg["pin"]).read_text()
    rendered = render_lock(current, release, version, digest)
    output = args.workdir / "hermes-lock.scm"
    output.write_text(rendered)
    if args.apply:
        (ROOT / pkg["pin"]).write_text(rendered)

    print(json.dumps({
        "package": args.package,
        "release": release,
        "version": version,
        "url": url,
        "sha256": digest,
        "pin": str(output),
        "applied": args.apply,
    }, indent=2, sort_keys=True))

    if args.verify:
        if not args.apply:
            raise SystemExit("--verify requires --apply")
        expr = f"(@ (under-sea packages {pkg['module']}) {pkg['package']})"
        subprocess.run(
            ["guix", "time-machine", "-C", "channels.scm", "--", "build",
             "-L", "modules", "--no-substitutes", "-e", expr],
            cwd=ROOT, check=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
