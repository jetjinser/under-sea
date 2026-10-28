"""Shared resilient download helper for the npm/Bun lockers."""
import os
import subprocess
from pathlib import Path

DEFAULT_MIRRORS = ("https://registry.npmmirror.com",)


def candidate_urls(url, mirrors=None):
    """Return URL plus registry-mirror rewrites for npmjs.org URLs."""
    urls = [url]
    if "registry.npmjs.org/" not in url:
        return urls
    mirrors = mirrors if mirrors is not None else DEFAULT_MIRRORS
    suffix = url.split("registry.npmjs.org/", 1)[1]
    for mirror in mirrors:
        urls.append(mirror.rstrip("/") + "/" + suffix)
    return urls


def fetch(url, dest, mirrors=None, timeout=180):
    """Download URL to DEST, trying mirrors and retrying transient failures."""
    dest = Path(dest)
    if dest.is_file() and dest.stat().st_size > 0:
        return
    tmp = dest.with_suffix(dest.suffix + ".part")
    errors = []
    for candidate in candidate_urls(url, mirrors):
        for attempt in range(3):
            try:
                subprocess.run(
                    ["curl", "-fsSL",
                     "--connect-timeout", "15",
                     "--max-time", str(timeout),
                     "--retry", "5",
                     "--retry-all-errors",
                     "--retry-delay", "2",
                     "-o", str(tmp), candidate],
                    check=True)
                tmp.rename(dest)
                return
            except subprocess.CalledProcessError as exc:
                errors.append(f"{candidate}: exit {exc.returncode}")
    raise RuntimeError("could not download " + url + ": " + "; ".join(errors))


def mirrors_from_env():
    value = os.environ.get("KC_NPM_MIRRORS")
    if value:
        return [item.strip() for item in value.split(",") if item.strip()]
    return list(DEFAULT_MIRRORS)
