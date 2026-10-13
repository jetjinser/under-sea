#!/usr/bin/env python3
"""Resolve source inputs outside Guix builds, then emit hash-pinned origins.

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


def scheme(value):
    return json.dumps(str(value), ensure_ascii=False)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def origin(url, name, path):
    return (f'(origin (method url-fetch) (uri {scheme(url)})\n'
            f'        (file-name {scheme(name)})\n'
            f'        (sha256 (base16-string->bytevector "{digest(path)}")))')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    parser.add_argument("archive", type=Path)
    parser.add_argument("source", type=Path)
    parser.add_argument("--output", type=Path,
                        default=Path("under-sea/packages/sing-box-lock.scm"))
    parser.add_argument("--cache", type=Path,
                        default=Path("/tmp/under-sea-sing-box-lock"))
    parser.add_argument("--proxy", default=os.environ.get(
        "GOPROXY", "https://goproxy.cn|https://proxy.golang.org"),
        help="Go module proxy (Go checksum verification remains enabled)")
    args = parser.parse_args()
    if not re.fullmatch(r"\d+\.\d+\.\d+", args.version):
        parser.error("version must be a stable release, such as 1.14.2")
    source = args.source.resolve()
    archive = args.archive.resolve()
    cache = args.cache.resolve()
    cache.mkdir(parents=True, exist_ok=True)

    tags = (source / "release/DEFAULT_BUILD_TAGS").read_text().strip().split(",")
    # Use cronet-go's purego bindings for NaiveProxy: they dlopen libcronet.so
    # at runtime instead of statically linking the (toolchain-incompatible)
    # prebuilt libcronet.a, so no cgo/C++ toolchain is required.
    tags.append("with_purego")
    # The full default tag set is locked.  with_naive_outbound pulls in the
    # cronet-go module (libcronet) and with_tailscale pulls in a prebuilt web
    # client; both are recorded as exact hash-pinned origins.
    ldflags = (source / "release/LDFLAGS").read_text().strip().split()
    # Resolve the exact metadata which the Guix builder will see, rather than
    # accidentally locking a modified checkout against an unrelated archive.
    with tarfile.open(archive, "r:gz") as contents:
        for relative in ("go.mod", "go.sum", "release/DEFAULT_BUILD_TAGS",
                         "release/LDFLAGS"):
            member = contents.extractfile(f"sing-box-{args.version}/{relative}")
            if member is None or member.read() != (source / relative).read_bytes():
                raise SystemExit(f"Archive and source disagree: {relative}")
    env = os.environ.copy()
    env.update(GOTOOLCHAIN="local", GOENV="off", GOSUMDB="sum.golang.org",
               CGO_ENABLED="1", GOOS="linux",
               GOARCH="amd64", GOWORK="off", GOFLAGS="", GOPATH=str(cache / "gopath"),
               GOMODCACHE=str(cache / "modules"), GOCACHE=str(cache / "build"),
               GOPROXY=args.proxy)
    if "https://goproxy.cn" in args.proxy:
        for key in ("NO_PROXY", "no_proxy"):
            env[key] = ",".join(filter(None, (env.get(key, ""), "goproxy.cn")))
    # Avoid stalled multiplexed transfers on the module mirror. This affects
    # the resolver's transport only, not the resulting package's runtime.
    env["GODEBUG"] = ",".join(filter(None, (env.get("GODEBUG", ""), "http2client=0")))
    # Resume interrupted downloads, but never mix releases or feature sets.
    go_version = subprocess.check_output(["go", "version"], env=env,
                                         text=True).strip()
    state = json.dumps({"source_sha256": digest(archive), "tags": tags,
                        "goos": "linux", "goarch": "amd64",
                        "go_version": go_version}, sort_keys=True)
    state_file = cache / "lock-state.json"
    if state_file.exists():
        if state_file.read_text() != state:
            raise SystemExit("Cache belongs to another source/features; use a fresh --cache")
    elif (cache / "modules").exists():
        raise SystemExit("Unidentified module cache; use a fresh --cache")
    state_file.write_text(state)
    print(f"{go_version}; resolving dependencies with checksum verification enabled...",
          flush=True)
    # go list fetches only source archives reachable with the chosen build tags;
    # unlike go mod download all, it does not fetch cronet binary archives.
    subprocess.run(["go", "list", "-mod=readonly", "-buildvcs=false", "-deps",
                    "-tags=" + ",".join(tags), "./cmd/sing-box"],
                   cwd=source, env=env, check=True, stdout=subprocess.DEVNULL)
    proxy = cache / "modules/cache/download"
    files = sorted(p for p in proxy.rglob("*")
                   if p.is_file() and p.suffix in {".mod", ".info", ".zip"})
    if not files:
        raise SystemExit("No module source inputs were resolved")
    inputs = cache / "inputs"
    inputs.mkdir(exist_ok=True)
    source_name = f"sing-box-{args.version}.tar.gz"
    shutil.copyfile(archive, inputs / source_name)
    lines = [";;; Generated by scripts/lock-sing-box.py; do not edit hashes by hand.",
             "(define-module (under-sea packages sing-box-lock)",
             "  #:use-module (guix packages)",
             "  #:use-module (guix download)",
             "  #:use-module (guix base16)",
             "  #:export (%sing-box-version %sing-box-source %sing-box-tags",
             "            %sing-box-ldflags %sing-box-module-files))", "",
             f"(define %sing-box-version {scheme(args.version)})",
             "(define %sing-box-source\n  " + origin(
                 "https://codeload.github.com/SagerNet/sing-box/tar.gz/refs/tags/v"
                 + args.version, source_name, archive) + ")",
             "(define %sing-box-tags '({}))".format(" ".join(map(scheme, tags))),
             "(define %sing-box-ldflags '({}))".format(" ".join(map(scheme, ldflags))),
             "(define %sing-box-module-files\n  (list"]
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
