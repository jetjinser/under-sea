"""Rebuild CLI offline sources from authenticated registry and Git archives."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tarfile
import tomllib

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('source',type=Path)
parser.add_argument('inputs',type=Path)
parser.add_argument('work',type=Path)
parser.add_argument('--inventory',type=Path,required=True)
parser.add_argument('--tokio-manifest',type=Path,required=True)
args=parser.parse_args()
inventory=json.loads(args.inventory.read_text())
vendor=args.work.resolve()/'vendor';vendor.mkdir(parents=True)
lock=args.source/'Cargo.lock'
if hashlib.sha256(lock.read_bytes()).hexdigest()!=inventory['cli_workspace']['lock_sha256']:
    raise ValueError('Unreviewed CLI dependency lock')
def checksum(root,package):
    files={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest()
           for p in root.rglob('*') if p.is_file() and p.name!='.cargo-checksum.json'}
    (root/'.cargo-checksum.json').write_text(json.dumps({'package':package,'files':files},sort_keys=True))
for package in tomllib.loads(lock.read_text())['package']:
    if not package.get('source','').startswith('registry+'):
        continue
    if package['source']!='registry+https://github.com/rust-lang/crates.io-index':
        raise ValueError('Unreviewed registry source')
    identity=package['name']+'-'+package['version']
    archive=args.inputs/(identity+'.crate')
    if hashlib.sha256(archive.read_bytes()).hexdigest()!=package['checksum']:
        raise ValueError('Registry archive differs: '+identity)
    with tarfile.open(archive) as tar:tar.extractall(vendor,filter='data')
    root=vendor/identity
    if not root.is_dir():raise ValueError('Unexpected crate root')
    checksum(root,package['checksum'])
metadata=inventory['tokio_vendor_metadata'];commit=metadata['commit']
archive=args.inputs/('guybedford-tokio-'+commit+'.tar.gz')
if hashlib.sha256(archive.read_bytes()).hexdigest()!=metadata['archive_sha256']:
    raise ValueError('Tokio Git archive differs')
unpack=args.work.resolve()/'git-unpack';unpack.mkdir()
with tarfile.open(archive) as tar:tar.extractall(unpack,filter='data')
original=unpack/('tokio-'+commit)/'tokio'
if hashlib.sha256((original/'Cargo.toml').read_bytes()).hexdigest()!=metadata['original_manifest_sha256']:
    raise ValueError('Tokio original manifest differs')
if hashlib.sha256(args.tokio_manifest.read_bytes()).hexdigest()!=metadata['normalized_manifest_sha256']:
    raise ValueError('Tokio normalized manifest differs')
tokio=vendor/'tokio';shutil.copytree(original,tokio)
shutil.copyfile(args.tokio_manifest,tokio/'Cargo.toml')
# Cargo vendor copies the Git package README from its repository parent.
readme=unpack/('tokio-'+commit)/'README.md'
if not (tokio/'README.md').exists() and readme.exists():shutil.copyfile(readme,tokio/'README.md')
checksum(tokio,None)
home=args.work.resolve()/'cargo-home';home.mkdir()
(home/'config.toml').write_text(
    '[source.crates-io]\nreplace-with="fixed-vendor"\n'
    '[source."git+https://github.com/guybedford/tokio?tag=1.53.1-cf.emscripten"]\n'
    'git="https://github.com/guybedford/tokio"\ntag="1.53.1-cf.emscripten"\n'
    'replace-with="fixed-vendor"\n[source.fixed-vendor]\ndirectory='+json.dumps(str(vendor))+'\n'
    '[net]\noffline=true\n')
print('Prepared authenticated CLI registry/Tokio vendor without Cargo Git cache',flush=True)
