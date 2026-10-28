#!/usr/bin/env python3
"""Prepare a Cargo-backed Python sdist (currently Loro)."""
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
    ap.add_argument("--workdir", type=Path)
    ap.add_argument("--cache", type=Path,
                    default=Path.home() / ".cache" / "loro-crates")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--manifest", type=Path, default=run.DEFAULT_MANIFEST)
    args = ap.parse_args()
    data = run.load_manifest(args.manifest)
    pkg = data["packages"].get(args.package)
    if not pkg or pkg.get("adapter") != "cargo":
        raise SystemExit(f"{args.package} is not configured as a Cargo package")
    if pkg["autonomy"] not in ("L3", "L4"):
        raise SystemExit(
            f"{args.package}: autonomy {pkg['autonomy']} does not allow lock updates")
    upstream = pkg["upstream"]
    if upstream["type"] != "pypi":
        raise SystemExit("Cargo adapter currently supports PyPI sdists")
    version, url = prepare.pypi_sdist(upstream["project"])
    if args.version and args.version != version:
        raise SystemExit(f"pypi latest is {version}, not requested {args.version}")
    workdir = args.workdir or Path(tempfile.mkdtemp(prefix=f"update-{args.package}-"))
    workdir.mkdir(parents=True, exist_ok=True)
    tarball = prepare.fetch(url, workdir / url.rsplit("/", 1)[-1])
    digest = prepare.guix_hash(tarball, "base32")
    src = extract_source(tarball, workdir)
    lock = pkg["lock"]
    output = workdir / Path(lock["output"]).name
    subprocess.run(
        [sys.executable, str(ROOT / lock["script"]),
         "--version", version, "--source", str(src), "--output", str(output),
         "--cache", str(args.cache),
         "--source-url", url, "--source-sha256", digest],
        cwd=ROOT, check=True)
    if args.apply:
        (ROOT / lock["output"]).write_text(output.read_text())
    print(json.dumps({
        "package": args.package, "version": version, "url": url,
        "sha256": digest, "lock": str(output), "applied": args.apply,
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
