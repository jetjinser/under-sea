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


def regenerate_lock(archive, workdir, *, source_only=False, source=None):
    source = source or extract_source(archive, workdir / "source")
    if source_only:
        return None
    staged_lock = workdir / "generated-hermes-lock.scm"
    command = [sys.executable, str(ROOT / "scripts/lock-hermes.py"),
               str(archive), str(source), "--cache",
               str(workdir / "lock-cache"), "--workers", "2",
               "--output", str(staged_lock),
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


def regenerate_dependent_locks(archive, source, workdir, specs):
    """Regenerate each declared dependent profile into the staging directory."""
    generated = {}
    for spec in specs:
        module = spec["module"]
        output = workdir / f"generated-{module}.scm"
        command = [sys.executable, str(ROOT / "scripts/lock-hermes.py"),
                   str(archive), str(source), "--cache",
                   str(workdir / "lock-cache"), "--workers", "2",
                   "--output", str(output), "--module", module,
                   "--source-overrides",
                   str(ROOT / "planning/archive/hermes-source-overrides.json"),
                   "--rust-git-sources",
                   str(ROOT / "planning/archive/hermes-rust-git-sources.json")]
        for extra in spec.get("extras", []):
            command.extend(("--extra", extra))
        if spec.get("python_components"):
            command.extend(("--python-components",
                            str(ROOT / spec["python_components"])))
        for source_audit in spec.get("source_audits", []):
            command.extend(("--source-audit", str(ROOT / source_audit)))
        if spec.get("record_unbuildable"):
            command.append("--record-unbuildable")
        subprocess.run(command, cwd=ROOT, check=True)
        if not output.is_file():
            raise ValueError(f"Hermes lock generator produced no {module} lock")
        text = output.read_text()
        if "%hermes-python-sources" not in text or "%hermes-crate-sources" not in text:
            raise ValueError(f"generated Hermes variant lock is incomplete: {module}")
        if spec.get("source_audits") and "%hermes-source-unavailable-components" not in text:
            raise ValueError(f"generated Hermes lock omitted audited source exceptions: {module}")
        if re.search(r'\(define-public %(?:hermes-version|hermes-release|hermes-source)(?=\s|\))',
                     text):
            raise ValueError(f"dependent lock must inherit root pins: {module}")
        generated[spec["target"]] = text
    return generated


def verification_specs(specs):
    """Return only dependent packages whose build gates are currently active."""
    return [spec for spec in specs if spec.get("verify", True)]


def dependent_lock_specs(pkg, packages):
    """Select this Hermes dependent's profile from its parent transaction."""
    if pkg.get("adapter") != "hermes-dependent":
        return pkg.get("dependent_locks", [])
    parent = packages.get(pkg.get("depends_on"), {})
    output = pkg.get("lock", {}).get("output")
    selected = [spec for spec in parent.get("dependent_locks", [])
                if spec.get("target") == output]
    if len(selected) != 1:
        raise ValueError(
            f"{pkg.get('package')}: expected one parent lock profile for {output}")
    return selected


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


def atomic_write_many(files):
    """Stage every lock first and roll back replacements if an apply fails."""
    staged = []
    backups = []
    installed = []
    committed = False
    try:
        for target, text in files.items():
            target = Path(target)
            fd, temporary = tempfile.mkstemp(
                prefix=target.name + ".", suffix=".tmp", dir=target.parent)
            mode = target.stat().st_mode & 0o777 if target.exists() else 0o644
            with os.fdopen(fd, "w") as stream:
                stream.write(text)
                stream.flush()
                os.fsync(stream.fileno())
            os.chmod(temporary, mode)
            staged.append((target, temporary))
        for target, _ in staged:
            if target.exists():
                fd, backup = tempfile.mkstemp(
                    prefix=target.name + ".", suffix=".bak", dir=target.parent)
                os.close(fd)
                os.unlink(backup)
                os.replace(target, backup)
                backups.append((target, backup))
        for target, temporary in staged:
            os.replace(temporary, target)
            installed.append(target)
        committed = True
    except BaseException:
        for target in installed:
            target.unlink(missing_ok=True)
        for target, backup in reversed(backups):
            os.replace(backup, target)
        raise
    finally:
        for _, temporary in staged:
            Path(temporary).unlink(missing_ok=True)
        if committed:
            for _, backup in backups:
                Path(backup).unlink(missing_ok=True)


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
    if args.source_only and args.apply:
        raise SystemExit("--source-only cannot apply an incomplete Hermes update")

    data = run.load_manifest(args.manifest)
    pkg = data["packages"].get(args.package)
    if not pkg:
        raise SystemExit(f"unknown package: {args.package}")
    if pkg.get("adapter") not in ("hermes", "hermes-dependent"):
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
    source = extract_source(archive, args.workdir / "source")
    try:
        dependent_specs = dependent_lock_specs(pkg, data["packages"])
    except ValueError as error:
        raise SystemExit(str(error)) from error

    if args.source_only:
        rendered = render_lock(current, release, version, digest)
        dependent_locks = {}
    else:
        rendered = regenerate_lock(archive, args.workdir, source=source)
        generated_version = re.search(
            r'\(define-public %hermes-version "([^"]+)"\)', rendered)
        generated_release = re.search(
            r'\(define-public %hermes-release "([^"]+)"\)', rendered)
        if (not generated_version or generated_version.group(1) != version or
                not generated_release or generated_release.group(1) != release):
            raise ValueError("generated Hermes lock pins do not match the archive")
        dependent_locks = regenerate_dependent_locks(
            archive, source, args.workdir, dependent_specs)
    output = args.workdir / "hermes-lock.scm"
    output.write_text(rendered)
    if args.apply:
        files = {ROOT / pkg["pin"]: rendered}
        files.update({ROOT / target: text
                      for target, text in dependent_locks.items()})
        atomic_write_many(files)
    for target, text in dependent_locks.items():
        (args.workdir / Path(target).name).write_text(text)

    print(json.dumps({
        "package": args.package,
        "release": release,
        "version": version,
        "url": url,
        "sha256": digest,
        "pin": str(output),
        "dependent_locks": sorted(dependent_locks),
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
        for spec in verification_specs(dependent_specs):
            expression = f"(@ (under-sea packages {spec['package_module']}) {spec['package']})"
            subprocess.run(
                ["guix", "time-machine", "-C", "channels.scm", "--", "build",
                 "-L", "modules", "--no-substitutes", "-e", expression],
                cwd=ROOT, check=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
