#!/usr/bin/env python3
"""Check Codex's assembled voice/zsh resource layout and helper entrypoints."""

import pathlib
import subprocess
import sys


def main(root):
    root = pathlib.Path(root)
    voice = root / "codex-resources/voice/bin/codex-voice-host"
    zsh = root / "codex-resources/zsh/bin/zsh"
    for component in (voice, zsh):
        if not component.is_symlink() or not component.exists():
            raise RuntimeError(f"missing packaged component link: {component}")
    subprocess.run([str(zsh), "--version"], check=True, timeout=5)
    commit = subprocess.check_output([str(voice), "--build-commit"],
                                     text=True, timeout=5).strip()
    if not commit:
        raise RuntimeError("voice helper returned an empty build identity")


if __name__ == "__main__":
    main(sys.argv[1])
