"""Attach locked modules to writable authored Next workspaces for source builds."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shlex
import shutil

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('modules', type=Path)
parser.add_argument('--node', type=Path, required=True)
parser.add_argument('--shell', type=Path, required=True)
args = parser.parse_args()
source, modules = args.source.resolve(), args.modules.resolve()
layout = json.loads((modules / 'guix-source-layout.json').read_text())
if hashlib.sha256((source / 'pnpm-lock.yaml').read_bytes()).hexdigest() != layout['pnpm_lock_sha256']:
    raise ValueError('Consumer source differs from locked dependency layout')
workspaces = modules / '.workspaces'

def relocate(destination):
    resolved = destination.resolve()
    if resolved.is_relative_to(workspaces):
        return source / resolved.relative_to(workspaces)
    return resolved

staged = []
for identity, original in layout['workspaces'].items():
    target = source / identity
    if not target.is_dir() or not (target / 'package.json').is_file():
        raise ValueError('Missing authored consumer workspace: ' + identity)
    deps = target / 'node_modules'
    if deps.exists() or deps.is_symlink():
        raise ValueError('Consumer workspace already has dependencies: ' + identity)
    original_deps = Path(original) / 'node_modules'
    if original_deps.is_dir():
        shutil.copytree(original_deps, deps, symlinks=True)
        for directory, dirs, files in os.walk(deps, followlinks=False):
            parent = Path(directory)
            parent.chmod(parent.stat().st_mode | 0o200)
            for name in dirs + files:
                link = parent / name
                if link.is_symlink():
                    destination = relocate(link)
                    link.unlink()
                    link.symlink_to(destination)
    else:
        deps.mkdir()
    staged.append(deps)
root_deps = source / 'node_modules'
if root_deps.exists() or root_deps.is_symlink():
    raise ValueError('Consumer root already has dependencies')
root_deps.mkdir()
for entry in modules.iterdir():
    if entry.name.startswith('.') or not (entry.is_dir() or entry.is_symlink()):
        continue
    # Scoped aliases are directory containers; preserve each package identity.
    entries = list(entry.iterdir()) if entry.name.startswith('@') else [entry]
    for alias in entries:
        name = entry.name + '/' + alias.name if entry.name.startswith('@') else alias.name
        destination = root_deps / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.symlink_to(relocate(alias))
staged.append(root_deps)
cli_records = {}
for deps in staged:
    packages = []
    for entry in deps.iterdir():
        if entry.name.startswith('.'):
            continue
        packages.extend(entry.iterdir() if entry.name.startswith('@') else [entry])
    commands = {}
    for package in packages:
        metadata_file = package / 'package.json'
        if not metadata_file.is_file():
            raise ValueError('Linked package has no metadata: ' + str(package))
        metadata = json.loads(metadata_file.read_text())
        bins = metadata.get('bin') or {}
        if isinstance(bins, str):
            bins = {metadata['name'].rsplit('/', 1)[-1]: bins}
        for command, path in bins.items():
            relative = Path(path)
            if not command or '/' in command or relative.is_absolute() or '..' in relative.parts:
                raise ValueError('Unsafe authored CLI path')
            target = package.resolve() / relative
            if command in commands and commands[command] != target:
                raise ValueError('Conflicting CLI providers: ' + command)
            commands[command] = target
    if commands:
        bin_dir = deps / '.bin'
        bin_dir.mkdir()
        for command, target in commands.items():
            # Preserve native provider executables; feeding ELF to Node would
            # turn an otherwise complete source provider into a broken CLI.
            launcher = [str(args.node), str(target)]
            if target.is_file():
                with target.open('rb') as file:
                    header = file.read(256)
                if header.startswith(b'\x7fELF'):
                    launcher = [str(target)]
                elif header.startswith(b'#!'):
                    interpreter = header.split(b'\n', 1)[0].decode()
                    if not re.search(r'(?:^|[ /])node(?:\s|$)', interpreter):
                        launcher = [str(target)]
            wrapper = bin_dir / command
            wrapper.write_text('#!' + str(args.shell) + '\nexec '
                               + ' '.join(map(shlex.quote, launcher)) + ' "$@"\n')
            wrapper.chmod(0o755)
        cli_records[str(deps.relative_to(source))] = {k: str(v) for k, v in commands.items()}
(source / 'guix-consumer-module-layout.json').write_text(json.dumps({
    'pnpm_lock_sha256': layout['pnpm_lock_sha256'], 'cli_entrypoints': cli_records,
    'source_module_layout': str(modules), 'install_scripts_executed': False,
    'functional_validation': 'deferred'}, indent=2) + '\n')
print('Staged', len(staged), 'consumer dependency directories without modifying source providers')
