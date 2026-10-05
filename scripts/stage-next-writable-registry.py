"""Copy locked registry inputs for Next tasks that patch dependency sources.

Run after consumer staging and before compiling; immutable source providers
remain external. No package install scripts or tools are executed.
"""
import argparse
import json
import os
from pathlib import Path
import shutil

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('modules', type=Path)
args = parser.parse_args()
source, modules = args.source.resolve(), args.modules.resolve()
original = modules / '.sources'
destination = source / 'node_modules/.sources'
if destination.exists():
    raise ValueError('Writable registry already exists; start with fresh staging')
shutil.copytree(original, destination, symlinks=True)
for root, directories, files in os.walk(destination, followlinks=False):
    parent = Path(root)
    parent.chmod(parent.stat().st_mode | 0o200)
    for name in files:
        path = parent / name
        if not path.is_symlink():
            path.chmod(path.stat().st_mode | 0o200)

layout = json.loads((modules / 'guix-source-layout.json').read_text())
roots = [destination, source / 'node_modules']
roots += [source / name / 'node_modules' for name in layout['workspaces']]
rewrites = 0
for root in roots:
    for directory, directories, files in os.walk(root, followlinks=False):
        parent = Path(directory)
        for name in directories + files:
            link = parent / name
            if not link.is_symlink():
                continue
            resolved = link.resolve()
            if resolved.is_relative_to(original):
                target = destination / resolved.relative_to(original)
            elif resolved.is_relative_to(modules / '.workspaces'):
                target = source / resolved.relative_to(modules / '.workspaces')
            else:
                continue
            link.unlink()
            link.symlink_to(target)
            rewrites += 1
(source / 'guix-writable-registry.json').write_text(json.dumps({
    'original': str(original), 'destination': str(destination),
    'rewritten_links': rewrites, 'functional_validation': 'deferred'}, indent=2) + '\n')
