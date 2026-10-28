#!/usr/bin/env python3
"""Emit fixed-origin npm tarballs for the rea-agents runtime closure.

In runtime mode the published rea-agents tarball already contains the compiled
dist/ tree, so the package only needs its runtime dependencies materialised on
disk.  This mode resolves the closure once with npm (package-lock v3), filters
out optional/platform packages and records every remaining tarball as a fixed
sha256 origin, together with the exact node_modules path npm would use.

In source mode (`--source-dir`) it records every resolved package-lock entry
needed by the upstream TypeScript/turbo build; the build bypasses turbo and
runs the underlying artifact scripts directly.

The build then extracts those origins directly into node_modules, so it never
runs npm and never touches the network.  The Linux node-pty platform binary is
not installed from npm: rea.scm replaces it with the source-built binding from
node-pty-for-hermes.

Usage:
  scripts/lock-rea.py --version 6.7.0 \
      --output modules/under-sea/packages/rea-lock.scm
  scripts/lock-rea.py --version 6.7.0 \
      --source-dir /path/to/rea-rea-agents-6.7.0 \
      --output modules/under-sea/packages/rea-source-lock.scm
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

REGISTRY = os.environ.get("REA_NPM_REGISTRY", "https://registry.npmjs.org")


def registry_url(name, version):
    base = name.split("/")[-1]
    return f"{REGISTRY}/{name}/-/{base}-{version}.tgz"


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def fetch(url, dest):
    if dest.is_file():
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".part")
    last = None
    for _ in range(4):
        try:
            with urllib.request.urlopen(url, timeout=60) as response:
                tmp.write_bytes(response.read())
            tmp.rename(dest)
            return
        except Exception as exc:  # noqa: BLE001
            last = exc
    raise last


def root_package_json(tarball, workdir):
    with tarfile.open(tarball) as archive:
        member = next(
            m for m in archive.getmembers()
            if m.name.endswith("/package.json") and m.name.count("/") == 1
        )
        return json.loads(archive.extractfile(member).read())


def make_lock(package, workdir):
    minimal = {
        key: package[key]
        for key in ("name", "version", "license", "type", "dependencies")
        if key in package
    }
    minimal["optionalDependencies"] = {}
    (workdir / "package.json").write_text(json.dumps(minimal, indent=2) + "\n")
    subprocess.run(
        ["npm", "install", "--package-lock-only", "--ignore-scripts",
         "--omit=dev", "--omit=optional", "--no-audit", "--no-fund"],
        cwd=workdir, check=True,
    )
    return json.loads((workdir / "package-lock.json").read_text())["packages"]


def resolve_path(packages, from_path, name):
    base = from_path
    while True:
        candidate = (base + "/node_modules/" + name) if base else (
            "node_modules/" + name)
        if candidate in packages:
            return candidate
        if not base:
            return None
        marker = base.rfind("/node_modules/")
        base = "" if marker == -1 else base[:marker]


def validate(packages, root_deps):
    missing = []
    for path, data in packages.items():
        if not path:
            continue
        for name in (data.get("dependencies") or {}):
            if resolve_path(packages, path, name) is None:
                missing.append(f"{path} -> {name}")
    for name in root_deps:
        if resolve_path(packages, "", name) is None:
            missing.append(f"<root> -> {name}")
    if missing:
        raise SystemExit("unresolved runtime dependencies:\n  " +
                         "\n  ".join(sorted(missing)))


def pin_origins(packages, tarballs, jobs):
    results = {}

    def work(item):
        path, data = item
        url = data["resolved"]
        tgz = tarballs / (hashlib.sha256(url.encode()).hexdigest()[:16] + ".tgz")
        try:
            fetch(url, tgz)
        except Exception as exc:  # noqa: BLE001
            return path, url, None, str(exc)
        return path, url, sha256_file(tgz), None

    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as ex:
        for path, url, digest, err in ex.map(work, sorted(packages.items())):
            if err:
                raise SystemExit(f"FAIL {path}: {url}: {err}")
            results[path] = (data_version(packages[path]), url, digest)
    return results


def emit_lock(output, module, export, version_var, source_var, origins_var,
              version, source_url, source_file, source_sha, results):
    output.parent.mkdir(parents=True, exist_ok=True)
    with open(output, "w") as f:
        f.write(";;; Generated by scripts/lock-rea.py; do not edit.\n")
        f.write(f"(define-module (under-sea packages {module})\n")
        f.write("  #:use-module (guix packages)\n")
        f.write("  #:use-module (guix download)\n")
        f.write("  #:use-module (guix base16)\n")
        f.write(f"  #:export ({export}))\n\n")
        f.write(f'(define-public {version_var} "{version}")\n\n')
        f.write(f"(define-public {source_var}\n")
        f.write("  (origin\n")
        f.write("    (method url-fetch)\n")
        f.write(f'    (uri "{source_url}")\n')
        f.write(f'    (file-name "{source_file}")\n')
        f.write("    (sha256\n")
        f.write(f'     (base16-string->bytevector "{source_sha}"))))\n\n')
        f.write(f"(define-public {origins_var}\n  (list\n")
        for path, (pkg_version, url, digest) in sorted(results.items()):
            name = hashlib.sha256(url.encode()).hexdigest()[:16]
            f.write(f'    (list "{path}" "{pkg_version}"\n')
            f.write(f'      (origin (method url-fetch) (uri "{url}")\n')
            f.write(f'        (file-name "{name}.tgz")\n')
            f.write(f'        (sha256 (base16-string->bytevector "{digest}"))))\n')
        f.write("))\n")


def main_runtime(args):
    tarballs = args.tarballs or Path(tempfile.mkdtemp(prefix="rea-lock-"))
    tarballs.mkdir(parents=True, exist_ok=True)

    root_url = registry_url("rea-agents", args.version)
    root_tgz = tarballs / "rea-agents.tgz"
    fetch(root_url, root_tgz)
    root_sha = sha256_file(root_tgz)
    package = root_package_json(root_tgz, tarballs)
    if package.get("version") != args.version:
        raise SystemExit(f"tarball version {package.get('version')} != {args.version}")

    workdir = Path(tempfile.mkdtemp(prefix="rea-lock-work-"))
    packages = make_lock(package, workdir)
    root_deps = packages[""].get("dependencies", {})

    runtime = {
        path: data for path, data in packages.items()
        if path and not data.get("optional")
    }
    validate(runtime, root_deps)
    results = pin_origins(runtime, tarballs, args.jobs)

    emit_lock(args.output, "rea-lock", "%rea-version %rea-source %rea-npm-origins",
              "%rea-version", "%rea-source", "%rea-npm-origins",
              args.version, root_url, f"rea-agents-{args.version}.tgz", root_sha, results)
    print(f"{len(results)} runtime tarballs pinned", file=sys.stderr)


def main_source(args):
    source_url = (
        "https://codeload.github.com/morluto/rea/tar.gz/"
        f"refs/tags/rea-agents-{args.version}")
    tarballs = args.tarballs or Path(tempfile.mkdtemp(prefix="rea-source-lock-"))
    tarballs.mkdir(parents=True, exist_ok=True)
    source_tgz = tarballs / "rea-source.tgz"
    fetch(source_url, source_tgz)
    source_sha = sha256_file(source_tgz)

    lock = json.loads((args.source_dir / "package-lock.json").read_text())
    packages = {
        path: data for path, data in lock["packages"].items()
        if path and data.get("resolved")
        and not data.get("link")
        and not str(data["resolved"]).startswith("file:")
    }
    results = pin_origins(packages, tarballs, args.jobs)

    emit_lock(args.output, "rea-source-lock",
              "%rea-source-version %rea-source-tree %rea-build-origins",
              "%rea-source-version", "%rea-source-tree", "%rea-build-origins",
              args.version, source_url, f"rea-agents-{args.version}-source.tar.gz",
              source_sha, results)
    print(f"{len(results)} build tarballs pinned", file=sys.stderr)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--version", required=True)
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--source-dir", type=Path,
                    help="emit the source-build closure from this checkout")
    ap.add_argument("--tarballs", type=Path, default=None,
                    help="tarball cache (default: a temporary directory)")
    ap.add_argument("--jobs", type=int, default=8)
    args = ap.parse_args()
    if args.source_dir:
        main_source(args)
    else:
        main_runtime(args)


def data_version(data):
    return data.get("version") or "0.0.0"


if __name__ == "__main__":
    main()
