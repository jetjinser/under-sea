#!/usr/bin/env python3
"""Lock SeaweedFS' source archive and offline Go module inputs.

Run with the Go and Python supplied by the pinned channels.scm.  The resulting
Guix build uses a file:// module proxy and cannot fetch code or toolchains.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile

from lock_lib import digest, origin, scheme


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    parser.add_argument("archive", type=Path)
    parser.add_argument("source", type=Path)
    parser.add_argument("--output", type=Path,
                        default=Path("modules/under-sea/packages/seaweedfs-lock.scm"))
    parser.add_argument("--cache", type=Path,
                        default=Path("/tmp/under-sea-seaweedfs-lock"))
    parser.add_argument("--proxy", default=os.environ.get(
        "GOPROXY", "https://goproxy.cn|https://proxy.golang.org"),
        help="Go module proxy (Go checksum verification remains enabled)")
    parser.add_argument("--tags", default="",
                        help="comma-separated Go build tags (for example rocksdb)")
    parser.add_argument("--module", default="(under-sea packages seaweedfs-lock)",
                        help="Guile module name for the generated lock")
    parser.add_argument("--prefix", default="seaweedfs",
                        help="symbol prefix for generated definitions")
    args = parser.parse_args()
    if not re.fullmatch(r"\d+\.\d+(\.\d+)?", args.version):
        parser.error("version must be a stable release, such as 4.49")
    source = args.source.resolve()
    archive = args.archive.resolve()
    cache = args.cache.resolve()
    cache.mkdir(parents=True, exist_ok=True)

    # Resolve against the exact metadata the Guix builder will see rather than
    # accidentally locking a modified checkout against an unrelated archive.
    with tarfile.open(archive, "r:gz") as contents:
        for relative in ("go.mod", "go.sum", "weed/Makefile", "weed/weed.go"):
            member = contents.extractfile(f"seaweedfs-{args.version}/{relative}")
            if member is None or member.read() != (source / relative).read_bytes():
                raise SystemExit(f"Archive and source disagree: {relative}")
        expected_go_mod = contents.extractfile(
            f"seaweedfs-{args.version}/go.mod").read()
    env = os.environ.copy()
    env.update(GOTOOLCHAIN="local", GOENV="off", GOSUMDB="sum.golang.org",
               CGO_ENABLED="1" if args.tags else "0",
               GOOS="linux", GOARCH="amd64", GOWORK="off",
               GOFLAGS="", GOPATH=str(cache / "gopath"),
               GOMODCACHE=str(cache / "modules"), GOCACHE=str(cache / "build"),
               GOPROXY=args.proxy)
    if "https://goproxy.cn" in args.proxy:
        for key in ("NO_PROXY", "no_proxy"):
            env[key] = ",".join(filter(None, (env.get(key, ""), "goproxy.cn")))
    # Avoid stalled multiplexed transfers on the module mirror.  This affects
    # the resolver's transport only, not the resulting package's runtime.
    env["GODEBUG"] = ",".join(filter(None, (env.get("GODEBUG", ""), "http2client=0")))
    go_version = subprocess.check_output(["go", "version"], env=env,
                                         text=True).strip()
    state = json.dumps({"source_sha256": digest(archive), "goos": "linux",
                        "goarch": "amd64", "go_version": go_version,
                        "tags": args.tags}, sort_keys=True)
    state_file = cache / "lock-state.json"
    if state_file.exists():
        if state_file.read_text() != state:
            raise SystemExit("Cache belongs to another source; use a fresh --cache")
    elif (cache / "modules").exists():
        raise SystemExit("Unidentified module cache; use a fresh --cache")
    state_file.write_text(state)
    print(f"{go_version}; resolving dependencies with checksum verification enabled...",
          flush=True)
    # The default build (no optional store tags) needs exactly the packages
    # reachable from ./weed.  go list fetches their metadata and source zips.
    list_command = ["go", "list", "-mod=readonly", "-buildvcs=false", "-deps"]
    if args.tags:
        list_command.append("-tags=" + args.tags)
    list_command.append("./weed")
    subprocess.run(list_command, cwd=source, env=env, check=True,
                   stdout=subprocess.DEVNULL)
    if (source / "go.mod").read_bytes() != expected_go_mod:
        raise SystemExit("Dependency resolution modified upstream go.mod")
    proxy = cache / "modules/cache/download"
    files = sorted(p for p in proxy.rglob("*")
                   if p.is_file() and p.suffix in {".mod", ".info", ".zip"})
    if not files:
        raise SystemExit("No module source inputs were resolved")
    inputs = cache / "inputs"
    inputs.mkdir(exist_ok=True)
    source_name = f"seaweedfs-{args.version}.tar.gz"
    shutil.copyfile(archive, inputs / source_name)
    prefix = args.prefix
    lines = [";;; Generated by scripts/lock-seaweedfs.py; do not edit hashes by hand.",
             f"(define-module {args.module}",
             "  #:use-module (guix packages)",
             "  #:use-module (guix download)",
             "  #:use-module (guix base16)",
             f"  #:export (%{prefix}-version %{prefix}-source",
             f"            %{prefix}-module-files))", "",
             f"(define %{prefix}-version {scheme(args.version)})",
             f"(define %{prefix}-source\n  " + origin(
                 "https://codeload.github.com/seaweedfs/seaweedfs/tar.gz/refs/tags/"
                 + args.version, source_name, archive) + ")",
             f"(define %{prefix}-module-files\n  (list"]
    for path in files:
        relative = path.relative_to(proxy).as_posix()
        name = "go-source-" + hashlib.sha256(relative.encode()).hexdigest()[:20] + path.suffix
        shutil.copyfile(path, inputs / name)
        lines.append(f"    (list {scheme(relative)}\n      " + origin(
            "https://goproxy.cn/" + relative, name, path) + ")")
    lines.append("  ))\n")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    # Never leave a half-written lock if resolution or hashing fails.
    with tempfile.NamedTemporaryFile(mode="w", dir=args.output.parent,
                                     delete=False) as handle:
        handle.write("\n".join(lines))
        temporary = handle.name
    os.replace(temporary, args.output)
    print(f"Wrote {args.output}: {len(files)} hash-pinned source/metadata files")
    print(f"Downloaded inputs for optional store seeding: {inputs}")


if __name__ == "__main__":
    main()
