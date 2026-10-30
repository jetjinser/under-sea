#!/usr/bin/env python3
"""Prepare a camofox-browser source pin and its Node source lock."""
import argparse
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import npm  # noqa: E402
import prepare  # noqa: E402
import run  # noqa: E402

ROOT = run.ROOT


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
    if not pkg or pkg.get("adapter") != "camofox":
        raise SystemExit(f"{args.package} is not configured as a camofox package")
    if pkg["autonomy"] not in ("L2", "L3", "L4"):
        raise SystemExit(
            f"{args.package}: autonomy {pkg['autonomy']} does not allow lock updates")
    if (args.apply and pkg["autonomy"] == "L2"
            and not pkg["lock"].get("candidate")):
        raise SystemExit(
            f"{args.package}: an L2 lock must be marked candidate before applying")
    version = args.version or run.detect_package(args.package, pkg)["latest"]
    if not version:
        raise SystemExit("cannot determine a version")
    tag = args.tag or pkg["tag_template"].format(version=version)
    upstream = pkg["upstream"]
    url = (f"https://codeload.github.com/{upstream['repo']}/tar.gz/"
           f"refs/tags/{tag}")
    workdir = args.workdir or (Path("/var/tmp/under-sea-update")
                               / f"{args.package}-{version}")
    workdir.mkdir(parents=True, exist_ok=True)
    file_name = f"{pkg['package']}-{version}.tar.gz"
    tarball = prepare.fetch(url, workdir / file_name)
    src = npm.extract_source(tarball, workdir)
    digest = prepare.guix_hash(tarball, pkg["hash_format"])
    pin = prepare.render_pin(pkg, version, url, file_name, digest)
    pin_path = workdir / "camofox-pin.scm"
    pin_path.write_text(pin)
    lock = pkg["lock"]
    lock_path = workdir / Path(lock["output"]).name
    inventory_path = workdir / Path(lock["inventory"]).name
    subprocess.run([
        sys.executable, str(ROOT / lock["script"]),
        "--version", version, "--source-dir", str(src),
        "--output", str(lock_path), "--inventory", str(inventory_path),
        "--tarballs", str(workdir / "tarballs"),
    ], cwd=ROOT, check=True)
    if args.apply:
        (ROOT / pkg["pin"]).write_text(pin)
        (ROOT / lock["output"]).write_text(lock_path.read_text())
        (ROOT / lock["inventory"]).write_text(inventory_path.read_text())
    print(json.dumps({
        "package": args.package, "version": version, "tag": tag,
        "url": url, "sha256": digest, "pin": str(pin_path),
        "lock": str(lock_path), "applied": args.apply,
        "inventory": str(inventory_path),
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
