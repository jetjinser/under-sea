#!/usr/bin/env python3
"""Prepare a Bun-based package: pin, offline cache and lock closure.

This is the L3 prepare adapter.  It runs `bun install` with network only in
the prepare phase, invokes the repository's existing locker, and reports native
payload changes.  It never builds the package; verification is a separate step.
"""
import argparse
import json
import os
import re
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


def package_output(expr):
    output = subprocess.check_output(
        ["guix", "time-machine", "-C", "channels.scm", "--", "build",
         "-L", "modules", "--no-substitutes", "-e", expr],
        cwd=ROOT, text=True)
    return output.strip().splitlines()[-1]


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


def native_inventory(lock_text, patterns):
    found = set()
    for url in re.findall(r'\(uri "([^"]+)"\)', lock_text):
        for pattern in patterns:
            if pattern in url:
                found.add(pattern)
    return sorted(found)


def lock_command(pkg, cache, tarballs, bun_lock, output):
    lock = pkg["lock"]
    cmd = [sys.executable, str(ROOT / lock["script"]),
           "--cache", str(cache),
           "--tarballs", str(tarballs),
           "--bun-lock", str(bun_lock),
           "--output", str(output)]
    if "module" in lock:
        cmd += ["--module", lock["module"]]
    if "prefix" in lock:
        cmd += ["--prefix", lock["prefix"]]
    return cmd


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--package", required=True)
    ap.add_argument("--version")
    ap.add_argument("--tag")
    ap.add_argument("--workdir", type=Path, default=None)
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--vm", action="store_true", help="also run the package VM test")
    ap.add_argument("--accept-native-change", action="store_true",
                    help="allow applying a lock with changed native payloads")
    ap.add_argument("--manifest", type=Path, default=run.DEFAULT_MANIFEST)
    args = ap.parse_args()

    data = run.load_manifest(args.manifest)
    pkg = data["packages"].get(args.package)
    if not pkg:
        raise SystemExit(f"unknown package: {args.package}")
    if pkg.get("adapter") != "bun" or "lock" not in pkg:
        raise SystemExit(f"{args.package} is not configured as a Bun package")
    upstream = pkg["upstream"]
    if upstream["type"] != "github":
        raise SystemExit("Bun adapter currently supports GitHub sources")

    version = args.version or run.detect_package(args.package, pkg)["latest"]
    if not version:
        raise SystemExit("cannot determine a version")
    tag = args.tag or pkg["tag_template"].format(version=version)
    url = (f"https://codeload.github.com/{upstream['repo']}/tar.gz/"
           f"refs/tags/{tag}")
    file_name = f"{pkg['package']}-{version}.tar.gz"
    workdir = args.workdir or Path(tempfile.mkdtemp(prefix=f"update-{args.package}-"))
    workdir.mkdir(parents=True, exist_ok=True)

    tarball = prepare.fetch(url, workdir / file_name)
    digest = prepare.guix_hash(tarball, pkg["hash_format"])
    rendered_pin = prepare.render_pin(
        pkg, version, url, file_name, digest)
    pin_path = workdir / f"{pkg['pin_module']}.scm"
    pin_path.write_text(rendered_pin)

    src = extract_source(tarball, workdir)
    bun = package_output(
        f"(@ (under-sea packages bun) {pkg['bun']})") + "/bin/bun"
    cache = workdir / "bun-cache"
    tarballs = workdir / "tarballs"
    cache.mkdir(parents=True, exist_ok=True)
    tarballs.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["HOME"] = str(workdir / "home")
    env["BUN_INSTALL_CACHE_DIR"] = str(cache)
    subprocess.run(
        [bun, "install", "--frozen-lockfile", "--ignore-scripts"],
        cwd=src, env=env, check=True)

    lock_path = workdir / Path(pkg["lock"]["output"]).name
    subprocess.run(
        lock_command(pkg, cache, tarballs, src / "bun.lock", lock_path),
        cwd=ROOT, check=True)

    old_lock_path = ROOT / pkg["lock"]["output"]
    old_inventory = native_inventory(
        old_lock_path.read_text(), pkg["native_payloads"]) if old_lock_path.exists() else []
    new_inventory = native_inventory(
        lock_path.read_text(), pkg["native_payloads"])
    added = sorted(set(new_inventory) - set(old_inventory))
    removed = sorted(set(old_inventory) - set(new_inventory))
    native_changed = bool(added or removed)
    if native_changed and args.apply and not args.accept_native_change:
        raise SystemExit(
            "native payload inventory changed; rerun with --accept-native-change "
            f"(added={added}, removed={removed})")

    if args.apply:
        (ROOT / pkg["pin"]).write_text(rendered_pin)
        old_lock_path.write_text(lock_path.read_text())

    result = {
        "package": args.package,
        "version": version,
        "tag": tag,
        "url": url,
        "sha256": digest,
        "pin": str(pin_path),
        "lock": str(lock_path),
        "applied": args.apply,
        "native_payloads_added": added,
        "native_payloads_removed": removed,
    }
    print(json.dumps(result, indent=2, sort_keys=True))

    if args.verify:
        if not args.apply:
            raise SystemExit("--verify requires --apply")
        expr = f"(@ (under-sea packages {pkg['module']}) {pkg['package']})"
        subprocess.run(
            ["guix", "time-machine", "-C", "channels.scm", "--", "build",
             "-L", "modules", "--no-substitutes", "-e", expr],
            cwd=ROOT, check=True)
    if args.vm:
        if not args.verify:
            raise SystemExit("--vm requires --verify")
        test_module = "opencode" if args.package.startswith("opencode") else args.package
        expr = f"(@ (under-sea tests {test_module}) %test-under-sea-{test_module})"
        subprocess.run(
            ["guix", "time-machine", "-C", "channels.scm", "--", "build",
             "-L", "modules", "-e", expr],
            cwd=ROOT, check=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
