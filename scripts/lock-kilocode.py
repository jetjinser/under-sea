#!/usr/bin/env python3
"""Emit a per-origin lock for kilocode's npm closure.

bun's installer does not encode on-disk paths in bun.lock (unlike npm/pnpm), so
the node_modules tree cannot be reconstructed by a flat extraction.  Instead we
replay bun's own installer offline: `bun install --frozen-lockfile --offline`
succeeds when $BUN_INSTALL_CACHE_DIR contains the extracted packages under the
exact names bun uses (<name>@<version>@@@1).  This script captures those cache
directory names from a real `bun install` (run once, with network) and pairs
each with the registry tarball of the package it contains, producing one fixed
sha256 origin per package.

Usage:
  1) produce a cache with network, e.g.:
       HOME=$PWD/home BUN_INSTALL_CACHE_DIR=$PWD/cache bun install --frozen-lockfile
  2) scripts/lock-kilocode.py --cache $PWD/cache \
       --output under-sea/packages/kilocode-lock.scm
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

REGISTRY = "https://registry.npmjs.org"


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
    tmp = dest.with_suffix(dest.suffix + ".part")
    subprocess.run(["curl", "-fsSL", "--retry", "3", "--retry-delay", "2",
                    "-o", str(tmp), url], check=True)
    tmp.rename(dest)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--cache", type=Path, required=True,
                    help="bun install-cache directory produced by bun install")
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--tarballs", type=Path, required=True,
                    help="directory to cache downloaded tarballs")
    ap.add_argument("--jobs", type=int, default=8)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--bun-lock", type=Path, default=None,
                    help="bun.lock, to discover direct-URL dependencies")
    args = ap.parse_args()

    args.tarballs.mkdir(parents=True, exist_ok=True)

    # Direct-URL dependencies (e.g. xlsx from cdn.sheetjs.com) are not on the
    # default registry; bun.lock encodes their ident as "<name>@<url>".
    import re
    url_deps = {}
    if args.bun_lock:
        text = re.sub(r",(?=\s*[}\]])", "", args.bun_lock.read_text())
        lock = json.loads(text)
        for v in (lock.get("packages") or {}).values():
            ident = v[0] if isinstance(v, list) and v else None
            if not isinstance(ident, str):
                continue
            m = re.match(r"^(?P<name>.+)@(?P<url>https?://.+)$", ident)
            if m:
                url_deps[m.group("name")] = m.group("url")

    # Flat package dirs are <name>@<version>@@@1 at the cache root, or
    # @scope/<name>@<version>@@@1 one level down; ignore the unversioned
    # metadata dirs, the binary manifest cache and the patched copies.
    def candidates():
        for entry in sorted(os.listdir(args.cache)):
            if entry.endswith(".npm"):
                continue
            p = args.cache / entry
            if "@@@1" in entry and "_patch_hash=" not in entry and p.is_dir():
                # flat package dir, including URL deps labeled @T@<hash>@@@1
                yield entry, p
            elif entry.startswith("@") and p.is_dir():
                for sub in sorted(os.listdir(p)):
                    if "_patch_hash=" in sub or "@@@1" not in sub:
                        continue
                    yield f"{entry}/{sub}", p / sub

    labels = []
    for label, d in candidates():
        pj = d / "package.json"
        if not pj.is_file():
            continue
        data = json.loads(pj.read_text())
        name, version = data.get("name"), data.get("version")
        if not name or not version:
            continue
        labels.append((label, name, version))
    if args.limit:
        labels = labels[: args.limit]
    print(f"{len(labels)} cache entries", file=sys.stderr)

    results = {}

    failures = []

    def work(item):
        label, name, version = item
        url = url_deps.get(name) or registry_url(name, version)
        tgz = args.tarballs / (hashlib.sha256(url.encode()).hexdigest()[:16] + ".tgz")
        try:
            fetch(url, tgz)
        except Exception as e:  # noqa: BLE001
            return label, name, version, url, None, str(e)
        return label, name, version, url, sha256_file(tgz), None

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as ex:
        for label, name, version, url, digest, err in ex.map(work, labels):
            if err:
                failures.append((label, name, version, url, err))
            else:
                results[label] = (url, digest)

    for label, name, version, url, err in failures:
        print(f"FAIL {label}: {name}@{version} {url}: {err}", file=sys.stderr)
    print(f"{len(failures)} failures", file=sys.stderr)

    with open(args.output, "w") as f:
        f.write(";;; Generated by scripts/lock-kilocode.py; do not edit.\n")
        f.write("(define-module (under-sea packages kilocode-lock)\n")
        f.write("  #:use-module (guix packages)\n")
        f.write("  #:use-module (guix download)\n")
        f.write("  #:use-module (guix base16)\n")
        f.write("  #:export (%kilocode-npm-origins))\n\n")
        f.write("(define %kilocode-npm-origins\n  (list\n")
        for label, name, _ in sorted(labels):
            if label not in results:
                continue
            url, digest = results[label]
            f.write(f'    (list "{label}"\n')
            f.write(f'      (origin (method url-fetch) (uri "{url}")\n')
            f.write(f'        (file-name "{hashlib.sha256(url.encode()).hexdigest()[:16]}.tgz")\n')
            f.write(f'        (sha256 (base16-string->bytevector "{digest}"))))\n')
        f.write("))\n")


if __name__ == "__main__":
    main()
