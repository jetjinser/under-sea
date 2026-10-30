#!/usr/bin/env python3
"""Run a local health smoke against an installed camofox-browser package."""
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: smoke-camofox.py PACKAGE-OUTPUT")

    package = Path(sys.argv[1])
    server = package / "lib/camofox-browser/server.js"
    wrapper = package / "bin/camofox-browser"
    node = shutil.which("node")
    if not node:
        raise SystemExit("node is not on PATH")
    subprocess.run([node, "--check", str(server)], check=True)

    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]

    with tempfile.TemporaryDirectory(prefix="camofox-smoke-") as home:
        env = os.environ.copy()
        env.update({"HOME": home, "CAMOFOX_PORT": str(port),
                    "CAMOFOX_BIND_HOST": "127.0.0.1"})
        log_path = Path(home) / "server.log"
        with log_path.open("w+") as log:
            process = subprocess.Popen(
                [str(wrapper)], env=env, stdout=log, stderr=subprocess.STDOUT)
            deadline = time.monotonic() + 30
            healthy = False
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    break
                try:
                    with urllib.request.urlopen(
                            f"http://127.0.0.1:{port}/health", timeout=1) as response:
                        if response.status == 200:
                            healthy = True
                            break
                except (urllib.error.URLError, TimeoutError, OSError):
                    pass
                time.sleep(0.25)

            if not healthy:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                log.flush()
                raise RuntimeError(
                    f"camofox health endpoint did not return HTTP 200:\n"
                    f"{log_path.read_text(errors='replace')}")

            process.terminate()
            try:
                exit_code = process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
                raise RuntimeError("camofox did not stop after SIGTERM")
            if exit_code != 0:
                log.flush()
                raise RuntimeError(
                    f"camofox exited with status {exit_code}:\n"
                    f"{log_path.read_text(errors='replace')}")


if __name__ == "__main__":
    main()
