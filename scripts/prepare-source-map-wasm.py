"""Vendor authenticated source-map WASM registry inputs for offline Cargo."""
import hashlib
import json
from pathlib import Path
import sys
import tarfile
import tomllib

source, archives, work = map(Path, sys.argv[1:4])
lock = source / 'source-map-mappings-wasm-api/Cargo.lock'
vendor = work.resolve() / 'vendor'
vendor.mkdir(parents=True)
for package in tomllib.loads(lock.read_text())['package']:
    if 'source' not in package:
        continue
    if package['source'] != 'registry+https://github.com/rust-lang/crates.io-index':
        raise ValueError('Unexpected registry')
    identity = package['name'] + '-' + package['version']
    archive = archives / (identity + '.crate')
    if hashlib.sha256(archive.read_bytes()).hexdigest() != package['checksum']:
        raise ValueError('Source checksum mismatch: ' + identity)
    with tarfile.open(archive) as tar:
        tar.extractall(vendor, filter='data')
    root = vendor / identity
    if not root.is_dir():
        raise ValueError('Unexpected crate root')
    files = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
             for p in root.rglob('*') if p.is_file() and p.name != '.cargo-checksum.json'}
    (root / '.cargo-checksum.json').write_text(json.dumps(
        {'package': package['checksum'], 'files': files}, sort_keys=True))
home = work.resolve() / 'cargo-home'
home.mkdir()
(home / 'config.toml').write_text(
    '[source.crates-io]\nreplace-with="locked-vendor"\n'
    '[source.locked-vendor]\ndirectory='+json.dumps(str(vendor))+'\n'
    '[net]\noffline=true\n')
print('Prepared source-map WASM offline vendor', flush=True)
