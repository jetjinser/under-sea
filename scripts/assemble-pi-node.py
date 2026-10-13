#!/usr/bin/env python3
"""Assemble Pi's npm (lockfileVersion 3) node_modules tree from locked archives.

Unlike pnpm, npm's lock encodes the exact on-disk location of every package as
its `path` (including nested `node_modules` directories), so assembly is a flat
extraction into that location.  Workspace `link` entries become relative
symlinks and native platform payloads are replaced by source-built providers.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess


def cache_name(resolved):
    return hashlib.sha256(resolved.encode()).hexdigest()[:16] + '.tgz'


def extract(archive, destination):
    destination.mkdir(parents=True, exist_ok=True)
    subprocess.run(['tar', 'xf', str(archive), '-C', str(destination),
                    '--strip-components=1'], check=True)


def install_bins(root, package_dir):
    manifest = package_dir / 'package.json'
    if not manifest.is_file():
        return
    try:
        data = json.loads(manifest.read_text())
    except (ValueError, OSError):
        return
    bin_field = data.get('bin')
    if not bin_field:
        return
    entries = bin_field.items() if isinstance(bin_field, dict) else [(data.get('name', ''), bin_field)]
    bindir = root / 'node_modules' / '.bin'
    bindir.mkdir(parents=True, exist_ok=True)
    for name, target in entries:
        name = name.split('/')[-1]
        if not name:
            continue
        link = bindir / name
        if link.exists() or link.is_symlink():
            continue
        link.symlink_to(os.path.relpath(package_dir / target, bindir))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('inventory', type=Path)
    parser.add_argument('destination', type=Path)
    parser.add_argument('--cache', type=Path)
    parser.add_argument('--archive-paths', type=Path)
    parser.add_argument('--providers', type=Path,
                        help='JSON object mapping lock path -> source-built directory')
    parser.add_argument('--exclude', type=Path,
                        help='JSON list of lock paths to omit (excluded/platform payloads)')
    args = parser.parse_args()
    inventory = json.loads(args.inventory.read_text())
    destination = args.destination.resolve()
    providers = json.loads(args.providers.read_text()) if args.providers else {}
    excluded = set(json.loads(args.exclude.read_text())) if args.exclude else set()
    paths = {}
    if args.archive_paths:
        for line in args.archive_paths.read_text().splitlines():
            if not line.strip():
                continue
            path, archive = line.split('\t')
            paths[path] = Path(archive)
    for item in inventory['selected']:
        path = item['path']
        if path in excluded:
            continue
        if path in providers:
            continue
        if path in paths:
            archive = paths[path]
        elif args.cache:
            archive = args.cache / cache_name(item['resolved'])
        else:
            raise ValueError('No archive source for ' + path)
        if not archive.is_file():
            raise ValueError('Missing archive for ' + path + ': ' + str(archive))
        extract(archive, destination / path)
        install_bins(destination, destination / path)
    for item in inventory['workspace']:
        path = item['path']
        if not path or item.get('resolved') in (None, ''):
            continue
        target = destination / item['resolved']
        link = destination / path
        if link.exists() or link.is_symlink():
            continue
        link.parent.mkdir(parents=True, exist_ok=True)
        link.symlink_to(os.path.relpath(target, link.parent))
    for path, source in providers.items():
        link = destination / path
        if link.exists() or link.is_symlink():
            if link.is_dir() and not link.is_symlink():
                subprocess.run(['rm', '-rf', str(link)], check=True)
            else:
                link.unlink()
        link.parent.mkdir(parents=True, exist_ok=True)
        os.symlink(os.path.abspath(source), link)
    for item in inventory['workspace']:
        if item['path']:
            install_bins(destination, destination / item['path'])
    for path in providers:
        install_bins(destination, destination / path)
    print('Assembled ' + str(len(inventory['selected'])) + ' packages into ' + str(destination))


if __name__ == '__main__':
    main()
