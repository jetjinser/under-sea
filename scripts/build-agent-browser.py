#!/usr/bin/env python3
"""Prepare exact registry crate sources for an offline agent-browser build."""
import hashlib
import json
import shutil
import tarfile
from pathlib import Path

root = Path.cwd()
work = root / 'guix-work'
work.mkdir()
vendor = work / 'vendor'
vendor.mkdir()


def unpack(archive, destination):
    destination.mkdir(parents=True)
    with tarfile.open(archive) as tar:
        tar.extractall(destination, filter='data')
    entries = list(destination.iterdir())
    assert len(entries) == 1 and entries[0].is_dir(), archive
    return entries[0]


for line in (root / 'crate-sources.tsv').read_text().splitlines():
    name, checksum, archive = line.split('\t')
    dest = vendor / name
    shutil.move(unpack(archive, work / 'unpack' / name), dest)
    files = {
        str(p.relative_to(dest)): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in dest.rglob('*')
        if p.is_file() and p.name != '.cargo-checksum.json'}
    (dest / '.cargo-checksum.json').write_text(
        json.dumps({'package': checksum, 'files': files}, sort_keys=True))

config = root / '.cargo' / 'config.toml'
config.parent.mkdir(parents=True, exist_ok=True)
config.write_text(
    '[source.crates-io]\nreplace-with="guix-vendor"\n'
    '[source.guix-vendor]\ndirectory=' + json.dumps(str(vendor)) + '\n'
    '[net]\noffline=true\n')
print('Prepared offline agent-browser crate vendor', flush=True)
