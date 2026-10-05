"""Prepare exact registry crate sources for offline Node native builds."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import tarfile
import tomllib
from urllib.parse import urlsplit, parse_qs

root = Path.cwd()
vendor = root / 'guix-vendor'
vendor.mkdir()
for line in (root / 'crate-sources.tsv').read_text().splitlines():
    name, checksum, archive = line.split('\t')
    stage = root / 'crate-unpack' / name
    stage.mkdir(parents=True)
    with tarfile.open(archive) as source:
        source.extractall(stage, filter='data')
    entries = list(stage.iterdir())
    if len(entries) != 1 or not entries[0].is_dir():
        raise ValueError('Unexpected registry source layout: ' + name)
    destination = vendor / name
    shutil.move(entries[0], destination)
    files = {str(path.relative_to(destination)): hashlib.sha256(path.read_bytes()).hexdigest()
             for path in destination.rglob('*') if path.is_file() and path.name != '.cargo-checksum.json'}
    (destination / '.cargo-checksum.json').write_text(json.dumps({'package': checksum, 'files': files}, sort_keys=True))
git_config = ''
git_table = root / 'git-sources.tsv'
if git_table.exists():
    locked = tomllib.loads((root / 'Cargo.lock').read_text())['package']
    for index, line in enumerate(git_table.read_text().splitlines()):
        identity, name, archive = line.split('\t')
        parsed = urlsplit(identity.removeprefix('git+'))
        revision = parse_qs(parsed.query).get('rev', [])
        if parsed.hostname != 'github.com' or revision != [parsed.fragment] or len(parsed.fragment) != 40:
            raise ValueError('Unsupported exact Git identity: ' + identity)
        packages = [p for p in locked if p.get('source') == identity and p['name'] == name]
        if len(packages) != 1:
            raise ValueError('Git provider does not match authored lock: ' + identity)
        stage = root / 'git-unpack' / str(index)
        stage.mkdir(parents=True)
        with tarfile.open(archive) as source:
            source.extractall(stage, filter='data')
        entries = list(stage.iterdir())
        if len(entries) != 1 or not entries[0].is_dir():
            raise ValueError('Unexpected Git source layout')
        metadata = tomllib.loads((entries[0] / 'Cargo.toml').read_text())['package']
        if (metadata['name'], metadata['version']) != (name, packages[0]['version']):
            raise ValueError('Git package metadata differs from lock')
        git_vendor = root / 'guix-git-vendor' / str(index)
        git_vendor.mkdir(parents=True)
        destination = git_vendor / (name + '-' + metadata['version'])
        shutil.move(entries[0], destination)
        files = {str(p.relative_to(destination)): hashlib.sha256(p.read_bytes()).hexdigest()
                 for p in destination.rglob('*') if p.is_file() and p.name != '.cargo-checksum.json'}
        (destination / '.cargo-checksum.json').write_text(json.dumps({'package': None, 'files': files}, sort_keys=True))
        repository = parsed._replace(query='', fragment='').geturl()
        git_config += ('\n[source.guix-git-' + str(index) + ']\ngit = ' + json.dumps(repository)
                       + '\nrev = ' + json.dumps(parsed.fragment)
                       + '\nreplace-with = "guix-git-vendor-' + str(index) + '"\n'
                       + '[source.guix-git-vendor-' + str(index) + ']\ndirectory = '
                       + json.dumps(str(git_vendor)) + '\n')
home = Path(os.environ['CARGO_HOME'])
home.mkdir(parents=True, exist_ok=True)
(home / 'config.toml').write_text(
    '[source.crates-io]\nreplace-with = "guix-vendor"\n'
    '[source.guix-vendor]\ndirectory = ' + json.dumps(str(vendor)) + '\n'
    '[net]\noffline = true\n' + git_config)
