#!/usr/bin/env python3
"""Refresh a PyPI version, uv resolution and generated Python source lock."""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import hermes  # noqa: E402
import run  # noqa: E402

ROOT = run.ROOT


def pypi_release(project, version=None, timeout=60):
    suffix = f"/{version}" if version else ""
    url = f"https://pypi.org/pypi/{project}{suffix}/json"
    request = urllib.request.Request(
        url, headers={"User-Agent": "under-sea-browser-use-update"})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            data = json.load(response)
    except (OSError, TimeoutError) as error:
        raise SystemExit(f"cannot query PyPI for {project} {version or 'latest'}: {error}") from error
    selected = data["info"]["version"]
    if version and selected != version:
        raise ValueError(f"PyPI returned {selected} for requested {version}")
    if not version:
        selected = data["info"]["version"]
    if not any(item.get("packagetype") == "sdist" for item in data["urls"]):
        raise ValueError(f"{project} {selected} has no source distribution")
    return selected


def render_project(template, root, version, extras):
    pattern = re.compile(
        rf'("{re.escape(root)}\[([^]]+)\]==)[^"\n]+(")')
    matches = list(pattern.finditer(template))
    if len(matches) != 1:
        raise ValueError(f"synthetic project must pin {root} exactly once")
    match = matches[0]
    declared = match.group(2).split(",")
    if declared != extras:
        raise ValueError(f"project extras {declared} do not match manifest {extras}")
    return (template[:match.start()] + match.group(1) + version + match.group(3)
            + template[match.end():])


def uv_executable():
    override = os.environ.get("UV")
    if override:
        candidate = Path(override)
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
        raise SystemExit(f"UV does not name an executable: {override}")
    # Resolve the tool from the same pinned Guix channel used for package builds.
    result = subprocess.check_output(
        ["guix", "time-machine", "-C", "channels.scm", "--", "build",
         "-L", "modules", "-e", "(@ (gnu packages build-tools) uv)"],
        cwd=ROOT, text=True)
    store_path = result.strip().splitlines()[-1]
    candidate = Path(store_path) / "bin/uv"
    if not candidate.is_file():
        raise SystemExit(f"pinned Guix uv output has no executable: {candidate}")
    return str(candidate)


def check_uv_version(executable, expected):
    output = subprocess.check_output([executable, "--version"], text=True)
    match = re.search(r"\buv ([0-9]+(?:\.[0-9]+)+)\b", output)
    if not match or match.group(1) != expected:
        raise SystemExit(
            f"uv {expected} from channels.scm is required; got {output.strip()}")
    return output.strip()


def lock_command(spec, uv_lock, output, cache):
    command = [
        sys.executable, str(ROOT / spec["script"]), str(uv_lock),
        "--root", spec["root"], "--module", spec["module"],
        "--version-symbol", spec["version_symbol"],
        "--output", str(output), "--cache", str(cache),
    ]
    if spec.get("components"):
        command.extend(("--components", str(ROOT / spec["components"])))
    if spec.get("cargo_lock_overrides"):
        command.extend(("--cargo-lock-overrides",
                        str(ROOT / spec["cargo_lock_overrides"])))
    for extra in spec.get("extras", []):
        command.extend(("--extra", extra))
    return command


def uv_lock_command(uv, project_dir, cache, *, upgrade_project=None):
    command = [uv, "lock", "--project", str(project_dir), "--python",
               sys.executable, "--cache-dir", str(cache)]
    if upgrade_project:
        command.extend(("--upgrade-package", upgrade_project))
    return command


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", required=True)
    parser.add_argument("--version")
    parser.add_argument("--workdir", type=Path)
    parser.add_argument("--manifest", type=Path, default=run.DEFAULT_MANIFEST)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()

    manifest = run.load_manifest(args.manifest)
    package = manifest["packages"].get(args.package)
    if not package or package.get("adapter") not in ("browser-use", "uv-profile"):
        raise SystemExit(f"{args.package} is not configured for a uv profile update")
    if package["autonomy"] not in ("L2", "L3", "L4"):
        raise SystemExit(f"{args.package}: level does not allow source updates")
    lock_spec = package.get("lock", {})
    if (args.apply and package["autonomy"] == "L2"
            and not lock_spec.get("candidate")):
        raise SystemExit("an L2 uv profile lock must be marked candidate before apply")
    if args.verify and not args.apply:
        raise SystemExit("--verify requires --apply")

    upstream = package["upstream"]
    if upstream.get("type") != "pypi":
        raise SystemExit("uv profile upstream must be PyPI")
    version = pypi_release(upstream["project"], args.version)
    workdir = args.workdir or Path(tempfile.mkdtemp(
        prefix=f"update-{upstream['project']}-"))
    workdir.mkdir(parents=True, exist_ok=True)
    project_dir = workdir / "project"
    project_dir.mkdir(exist_ok=True)
    project_path = ROOT / lock_spec["project"]
    project_text = render_project(
        project_path.read_text(), lock_spec["root"], version,
        lock_spec["extras"])
    (project_dir / "pyproject.toml").write_text(project_text)
    uv_lock_path = project_dir / "uv.lock"
    committed_uv_lock = ROOT / lock_spec["lockfile"]
    if committed_uv_lock.is_file():
        shutil.copyfile(committed_uv_lock, uv_lock_path)

    uv = uv_executable()
    check_uv_version(uv, lock_spec["uv_version"])
    uv_cache = workdir / "uv-cache"
    uv_cache.mkdir(parents=True, exist_ok=True)
    uv_command = uv_lock_command(uv, project_dir, uv_cache)
    if uv_lock_path.exists():
        uv_command = uv_lock_command(
            uv, project_dir, uv_cache, upgrade_project=upstream["project"])
    uv_env = dict(os.environ)
    uv_env["UV_PYTHON_DOWNLOADS"] = "never"
    subprocess.run(uv_command, cwd=ROOT, check=True, env=uv_env)
    if not uv_lock_path.is_file():
        raise ValueError("uv did not produce a lock file")

    output = workdir / Path(lock_spec["output"]).name
    cache = workdir / "source-cache"
    command = lock_command(lock_spec, uv_lock_path, output, cache)
    subprocess.run(command, cwd=ROOT, check=True)
    lock_text = output.read_text()
    version_pin = re.search(
        rf'\(define-public {re.escape(lock_spec["version_symbol"])} '
        rf'"{re.escape(version)}"\)', lock_text)
    source_pin = re.search(
        rf'\(list "{re.escape(lock_spec["root"])}" '
        rf'"{re.escape(version)}" \(origin', lock_text)
    if not version_pin or not source_pin:
        raise ValueError("generated source lock does not pin its selected version")

    staged_uv_lock = workdir / Path(lock_spec["lockfile"]).name
    shutil.copyfile(uv_lock_path, staged_uv_lock)
    artifacts = {
        ROOT / lock_spec["output"]: lock_text,
        ROOT / lock_spec["lockfile"]: staged_uv_lock.read_text(),
    }
    if args.apply:
        hermes.atomic_write_many(artifacts)
    # update.scm copies these basename-addressed staged artifacts on --apply.
    (workdir / Path(lock_spec["output"]).name).write_text(lock_text)
    print(json.dumps({
        "package": args.package,
        "project": upstream["project"],
        "version": version,
        "lock": str(output),
        "uv_lock": str(staged_uv_lock),
        "applied": args.apply,
    }, indent=2, sort_keys=True))
    if args.verify:
        expression = (f"(@ (under-sea packages {package['module']}) "
                      f"{package['package']})")
        subprocess.run(
            ["guix", "time-machine", "-C", "channels.scm", "--", "build",
             "-L", "modules", "--no-substitutes", "-e", expression],
            cwd=ROOT, check=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
