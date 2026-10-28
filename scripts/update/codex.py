#!/usr/bin/env python3
"""Prepare a Cargo source lock from an upstream release archive."""
import argparse
import json
import shutil
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepare  # noqa: E402
import run  # noqa: E402

ROOT = run.ROOT


def extract_source(tarball, workdir):
    src = workdir / "src"
    if src.exists():
        shutil.rmtree(src)
    src.mkdir()
    with tarfile.open(tarball) as archive:
        archive.extractall(src, filter="data")
    entries = [entry for entry in src.iterdir() if entry.is_dir()]
    if len(entries) != 1:
        raise SystemExit(f"expected one source directory, got {entries}")
    return entries[0]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--package", required=True)
    ap.add_argument("--version")
    ap.add_argument("--tag")
    ap.add_argument("--workdir", type=Path)
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--manifest", type=Path, default=run.DEFAULT_MANIFEST)
    args = ap.parse_args()
    data = run.load_manifest(args.manifest)
    pkg = data["packages"].get(args.package)
    if not pkg or pkg.get("adapter") not in ("codex-cargo", "cargo-lock"):
        raise SystemExit(f"{args.package} is not configured as a Cargo lock package")
    if pkg["autonomy"] not in ("L3", "L4"):
        raise SystemExit(
            f"{args.package}: autonomy {pkg['autonomy']} does not allow lock updates")
    upstream = pkg["upstream"]
    version = args.version or run.detect_package(args.package, pkg)["latest"]
    if not version:
        raise SystemExit("cannot determine a version")
    tag = args.tag or pkg["tag_template"].format(version=version)
    url = (f"https://codeload.github.com/{upstream['repo']}/tar.gz/"
           f"refs/tags/{tag}")
    workdir = args.workdir or Path(tempfile.mkdtemp(prefix=f"update-{args.package}-"))
    workdir.mkdir(parents=True, exist_ok=True)
    tarball = prepare.fetch(url, workdir / f"{pkg['package']}-{version}.tar.gz")
    src = extract_source(tarball, workdir)
    lock = pkg["lock"]
    output = workdir / Path(lock["output"]).name
    subprocess.run(
        [sys.executable, str(ROOT / lock["script"]), str(tarball), str(src),
         "--output", str(output), "--cache", str(workdir / "crates")],
        cwd=ROOT, check=True)
    if args.apply:
        (ROOT / lock["output"]).write_text(output.read_text())
    print(json.dumps({
        "package": args.package, "version": version, "tag": tag,
        "url": url, "lock": str(output), "applied": args.apply,
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
