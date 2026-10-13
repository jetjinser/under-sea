"""Rebuild photon's offline Cargo vendor from locked crate archives."""
import argparse
import hashlib
import json
from pathlib import Path
import tarfile
import tomllib

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('inputs', type=Path)
parser.add_argument('work', type=Path)
parser.add_argument('--inventory', type=Path, required=True)
args = parser.parse_args()
inventory = json.loads(args.inventory.read_text())
lock = args.source / 'Cargo.lock'
if hashlib.sha256(lock.read_bytes()).hexdigest() != inventory['lock_sha256']:
    raise ValueError('Unreviewed photon lock')
work = args.work.resolve()
vendor = work / 'vendor'
vendor.mkdir(parents=True)


def checksum(root, package):
    files = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
             for p in root.rglob('*') if p.is_file() and p.name != '.cargo-checksum.json'}
    (root / '.cargo-checksum.json').write_text(
        json.dumps({'package': package, 'files': files}, sort_keys=True))


for package in tomllib.loads(lock.read_text())['package']:
    origin = package.get('source', '')
    if not origin.startswith('registry+'):
        continue
    if origin != 'registry+https://github.com/rust-lang/crates.io-index':
        raise ValueError('Unreviewed registry')
    identity = package['name'] + '-' + package['version']
    archive = args.inputs / (identity + '.crate')
    if hashlib.sha256(archive.read_bytes()).hexdigest() != package['checksum']:
        raise ValueError('Registry checksum differs: ' + identity)
    with tarfile.open(archive) as tar:
        tar.extractall(vendor, filter='data')
    root = vendor / identity
    if not root.is_dir():
        raise ValueError('Unexpected crate root')
    checksum(root, package['checksum'])
home = work / 'cargo-home'
home.mkdir()
(home / 'config.toml').write_text(
    '[source.crates-io]\nreplace-with="fixed-vendor"\n'
    '[source.fixed-vendor]\ndirectory=' + json.dumps(str(vendor)) + '\n'
    '[net]\noffline=true\n')
print('Prepared photon vendor of ' + str(len(list(vendor.iterdir()))) + ' crates', flush=True)
