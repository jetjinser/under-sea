"""Normalize authored Next workspace self-links to the current source tree.

The locked module graph records workspace packages (`@next/env`,
`@next/polyfill-module`, ...) as symlinks.  When those links are copied into the
consumer they can carry an absolute target from the tree the module graph was
assembled in, so a later build resolves them into a stale directory instead of
the workspace being built.  Point every such link at the matching authored
`packages/<name>` directory under the current source root and leave unrelated
registry packages untouched.
"""
import argparse
import os
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
args = parser.parse_args()
source = args.source.resolve()
packages = source / 'packages'

rewritten = 0
for directory, dirs, files in os.walk(source, followlinks=False):
    parent = Path(directory)
    if parent.name != '@next' or parent.parent.name != 'node_modules':
        continue
    for name in list(dirs) + list(files):
        link = parent / name
        if not link.is_symlink():
            continue
        target = Path(os.readlink(link))
        candidate = packages / target.name
        if not (candidate / 'package.json').is_file():
            continue
        relative = os.path.relpath(candidate, link.parent)
        if os.readlink(link) == relative:
            continue
        link.unlink()
        link.symlink_to(relative)
        rewritten += 1
print('Relinked', rewritten, 'Next workspace self-references', flush=True)
