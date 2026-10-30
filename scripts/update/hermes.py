#!/usr/bin/env python3
"""Prepare a Hermes source update and regenerate its dependency lock.

The release archive, Python/Cargo/Git source lock, and root source pins are
prepared together. Nothing in the repository changes unless the full lock
generation succeeds; --apply replaces the generated lock atomically.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
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


def extract_source(archive, destination):
    destination.mkdir(parents=True, exist_ok=True)
    with tarfile.open(archive) as tar:
        members = tar.getmembers()
        if not members:
            raise ValueError("Hermes archive is empty")
        roots = {Path(member.name).parts[0] for member in members
                 if Path(member.name).parts}
        if len(roots) != 1:
            raise ValueError("Hermes archive must contain one root directory")
        for member in members:
            path = Path(member.name)
            if path.is_absolute() or ".." in path.parts:
                raise ValueError("unsafe path in Hermes archive: " + member.name)
        tar.extractall(destination, members=members, filter="data")
        return destination / roots.pop()


def regenerate_lock(archive, workdir, *, source_only=False):
    source = extract_source(archive, workdir / "source")
    if source_only:
        return None
    staged_lock = workdir / "generated-hermes-lock.scm"
    command = [sys.executable, str(ROOT / "scripts/lock-hermes.py"),
               str(archive), str(source), "--cache",
               str(workdir / "lock-cache"), "--output", str(staged_lock),
               "--source-overrides",
               str(ROOT / "planning/archive/hermes-source-overrides.json"),
               "--rust-git-sources",
               str(ROOT / "planning/archive/hermes-rust-git-sources.json")]
    subprocess.run(command, cwd=ROOT, check=True)
    if not staged_lock.is_file():
        raise ValueError("Hermes lock generator produced no lock")
    text = staged_lock.read_text()
    if "%hermes-version" not in text or "%hermes-python-sources" not in text:
        raise ValueError("generated Hermes lock is incomplete")
    return text


def atomic_write(target, text):
    target = Path(target)
    fd, temporary = tempfile.mkstemp(prefix=target.name + ".", suffix=".tmp",
                                     dir=target.parent)
    try:
        mode = target.stat().st_mode & 0o777 if target.exists() else 0o644
        with os.fdopen(fd, "w") as stream:
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, target)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--package", required=True)
    ap.add_argument("--version")
    ap.add_argument("--workdir", type=Path, required=True)
    ap.add_argument("--manifest", type=Path, default=run.DEFAULT_MANIFEST)
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--source-only", action="store_true",
                    help="legacy pin-only preparation; not sufficient for L3")
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
    if args.source_only:
        rendered = render_lock(current, release, version, digest)
    else:
        rendered = regenerate_lock(archive, args.workdir)
        generated_version = re.search(
            r'\(define-public %hermes-version "([^"]+)"\)', rendered)
        generated_release = re.search(
            r'\(define-public %hermes-release "([^"]+)"\)', rendered)
        if (not generated_version or generated_version.group(1) != version or
                not generated_release or generated_release.group(1) != release):
            raise ValueError("generated Hermes lock pins do not match the archive")
    output = args.workdir / "hermes-lock.scm"
    output.write_text(rendered)
    if args.apply:
        atomic_write(ROOT / pkg["pin"], rendered)

    print(json.dumps({
        "package": args.package,
        "release": release,
        "version": version,
        "url": url,
        "sha256": digest,
        "pin": str(output),
        "applied": args.apply,
        "lock_regenerated": not args.source_only,
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
