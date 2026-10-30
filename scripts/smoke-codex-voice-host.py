#!/usr/bin/env python3
"""Exercise the packaged helper's framed control lifecycle without audio."""

import json
import os
import select
import struct
import subprocess
import sys
import time


def frame(message):
    payload = json.dumps(message, separators=(",", ":")).encode()
    return struct.pack(">I", len(payload)) + payload


def read_frame(process, deadline):
    data = bytearray()
    while len(data) < 4:
        remaining = deadline - time.monotonic()
        if remaining <= 0 or not select.select([process.stdout], [], [], remaining)[0]:
            raise RuntimeError("timed out waiting for voice-host response")
        data.extend(os.read(process.stdout.fileno(), 4 - len(data)))
    length = struct.unpack(">I", data)[0]
    while len(data) < length + 4:
        remaining = deadline - time.monotonic()
        if remaining <= 0 or not select.select([process.stdout], [], [], remaining)[0]:
            raise RuntimeError("timed out reading voice-host response frame")
        data.extend(os.read(process.stdout.fileno(), length + 4 - len(data)))
    return json.loads(data[4:])


def main(binary):
    build_commit = subprocess.check_output(
        [binary, "--build-commit"], text=True, timeout=5
    ).strip()
    if not build_commit:
        raise RuntimeError("voice-host returned an empty build commit")
    process = subprocess.Popen(
        [binary], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    try:
        process.stdin.write(frame({"type": "hello", "protocol": 1,
                                   "buildCommit": build_commit}))
        process.stdin.flush()
        if read_frame(process, time.monotonic() + 5) != {"type": "ready"}:
            raise RuntimeError("voice-host did not complete the hello/ready handshake")
        process.stdin.write(frame({"type": "close"}))
        process.stdin.flush()
        if read_frame(process, time.monotonic() + 5) != {"type": "closed"}:
            raise RuntimeError("voice-host did not acknowledge close")
        if process.wait(timeout=5) != 0:
            raise RuntimeError("voice-host exited unsuccessfully after close")
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
        process.stdin.close()
        process.stdout.close()
        process.stderr.close()


if __name__ == "__main__":
    main(sys.argv[1])
