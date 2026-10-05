#!/usr/bin/env python3
"""Lock dae's source archive, eBPF headers and offline Go module inputs."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import shutil
import subprocess
import tarfile
import tempfile

# Share the origin serializer with the existing source locker.
helpers = runpy.run_path(str(Path(__file__).with_name("lock-sing-box.py")))
scheme, digest, origin = (helpers[name] for name in ("scheme", "digest", "origin"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    parser.add_argument("archive", type=Path)
    parser.add_argument("source", type=Path)
    parser.add_argument("headers_commit")
    parser.add_argument("headers_archive", type=Path)
    parser.add_argument("--output", type=Path,
                        default=Path("under-sea/packages/dae-lock.scm"))
    parser.add_argument("--cache", type=Path, default=Path("/tmp/under-sea-dae-lock"))
    parser.add_argument("--proxy", default=os.environ.get(
        "GOPROXY", "https://goproxy.cn|https://proxy.golang.org"))
    args = parser.parse_args()
    if not re.fullmatch(r"\d+\.\d+\.\d+", args.version):
        parser.error("expected a stable release version")
    if not re.fullmatch(r"[0-9a-f]{40}", args.headers_commit):
        parser.error("expected a full headers submodule commit")
    source, archive = args.source.resolve(), args.archive.resolve()
    headers = args.headers_archive.resolve()
    cache = args.cache.resolve()
    cache.mkdir(parents=True, exist_ok=True)
    with tarfile.open(archive, "r:gz") as contents:
        for relative in ("go.mod", "go.sum", "Makefile", ".gitmodules"):
            member = contents.extractfile(f"dae-{args.version}/{relative}")
            if member is None or member.read() != (source / relative).read_bytes():
                raise SystemExit(f"Archive and source disagree: {relative}")
    with tarfile.open(headers, "r:gz") as contents:
        if not any(m.name == f"dae_bpf_headers-{args.headers_commit}/vmlinux.h"
                   for m in contents.getmembers()):
            raise SystemExit("Headers archive does not match the specified commit")
    module_metadata = {name: (source / name).read_bytes()
                       for name in ("go.mod", "go.sum")}
    match = re.search(r"^DEFAULT_GOEXPERIMENT\s*:=\s*(\S+)",
                      (source / "Makefile").read_text(), re.MULTILINE)
    if match is None:
        raise SystemExit("Cannot find upstream's build experiments")
    experiments = match.group(1)
    env = os.environ.copy()
    env.update(GOTOOLCHAIN="local", GOENV="off", GOSUMDB="sum.golang.org",
               CGO_ENABLED="0", GOOS="linux", GOARCH="amd64", GOWORK="off",
               GOFLAGS="", GOEXPERIMENT=experiments, GOPATH=str(cache / "gopath"),
               GOMODCACHE=str(cache / "modules"), GOCACHE=str(cache / "build"),
               GOPROXY=args.proxy)
    if "https://goproxy.cn" in args.proxy:
        for key in ("NO_PROXY", "no_proxy"):
            env[key] = ",".join(filter(None, (env.get(key, ""), "goproxy.cn")))
    env["GODEBUG"] = ",".join(filter(None, (env.get("GODEBUG", ""), "http2client=0")))
    go_version = subprocess.check_output(["go", "version"], env=env, text=True).strip()
    state = json.dumps({"source_sha256": digest(archive),
                        "headers_sha256": digest(headers),
                        "experiments": experiments, "go_version": go_version},
                       sort_keys=True)
    state_file = cache / "lock-state.json"
    if state_file.exists():
        if state_file.read_text() != state:
            raise SystemExit("Cache belongs to another release; use a fresh --cache")
    elif (cache / "modules").exists():
        raise SystemExit("Unidentified module cache; use a fresh --cache")
    state_file.write_text(state)
    print(f"{go_version}; resolving modules with checksum verification enabled...",
          flush=True)
    # Includes bpf2go and upstream unit-test dependencies. The production
    # executable is built with real generated eBPF objects, never the stub tag.
    packages = subprocess.check_output(["go", "list", "-mod=readonly", "-buildvcs=false", "-deps",
                    "-test", "-tags=trace,dae_stub_ebpf", "-json", ".", "./config",
                    "./pkg/config_parser", "./pkg/trie", "./common/consts",
                    "./cmd/generators/gen_ebpf_sync",
                    "github.com/cilium/ebpf/cmd/bpf2go"],
                   cwd=source, env=env, text=True)
    decoder = json.JSONDecoder()
    selected = set()
    position = 0
    while position < len(packages):
        if packages[position].isspace():
            position += 1
            continue
        package, position = decoder.raw_decode(packages, position)
        module = package.get("Module", {})
        module = module.get("Replace", module)
        if "Version" in module:
            escaped = "".join("!" + c.lower() if c.isupper() else c
                              for c in module["Path"])
            selected.add(escaped + "/@v/" + module["Version"])
    for name, expected in module_metadata.items():
        if (source / name).read_bytes() != expected:
            raise SystemExit(f"Dependency resolution modified upstream {name}")
    proxy = cache / "modules/cache/download"
    files = sorted(p for p in proxy.rglob("*") if p.is_file()
                   and (p.suffix == ".mod" or
                        (p.suffix in {".info", ".zip"} and
                         p.relative_to(proxy).as_posix().rsplit(".", 1)[0] in selected)))
    if not files:
        raise SystemExit("No module source inputs were downloaded")
    for path in files:
        if path.suffix == ".zip" and ("/cronet-go/lib/" in str(path)
                                      or "web-client-prebuilt" in str(path)):
            raise SystemExit(f"Unexpected precompiled runtime dependency: {path}")
    inputs = cache / "inputs"
    inputs.mkdir(exist_ok=True)
    source_name = f"dae-{args.version}.tar.gz"
    headers_name = f"dae-bpf-headers-{args.headers_commit}.tar.gz"
    shutil.copyfile(archive, inputs / source_name)
    shutil.copyfile(headers, inputs / headers_name)
    lines = [";;; Generated by scripts/lock-dae.py; do not edit hashes by hand.",
             "(define-module (under-sea packages dae-lock)",
             "  #:use-module (guix packages)",
             "  #:use-module (guix download)",
             "  #:use-module (guix base16)",
             "  #:export (%dae-version %dae-source %dae-headers",
             "            %dae-goexperiment %dae-module-files))", "",
             f"(define %dae-version {scheme(args.version)})",
             "(define %dae-source\n  " + origin(
                 "https://codeload.github.com/daeuniverse/dae/tar.gz/refs/tags/v"
                 + args.version, source_name, archive) + ")",
             "(define %dae-headers\n  " + origin(
                 "https://codeload.github.com/daeuniverse/dae_bpf_headers/tar.gz/"
                 + args.headers_commit, headers_name, headers) + ")",
             f"(define %dae-goexperiment {scheme(experiments)})",
             "(define %dae-module-files\n  (list"]
    for path in files:
        relative = path.relative_to(proxy).as_posix()
        name = "go-source-" + hashlib.sha256(relative.encode()).hexdigest()[:20] + path.suffix
        shutil.copyfile(path, inputs / name)
        lines.append(f"    (list {scheme(relative)}\n      " + origin(
            "https://proxy.golang.org/" + relative, name, path) + ")")
    lines.append("  ))\n")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=args.output.parent,
                                     delete=False) as handle:
        handle.write("\n".join(lines))
        temporary = handle.name
    os.replace(temporary, args.output)
    print(f"Wrote {args.output}: {len(files)} hash-pinned module files")
    print(f"Inputs for optional store seeding: {inputs}")


if __name__ == "__main__":
    main()
