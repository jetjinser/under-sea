"""Rebuild resvg offline vendor directly from locked source archives."""
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
parser.add_argument('--manifests',type=Path,required=True)
args=parser.parse_args()
inventory=json.loads(args.inventory.read_text())
lock=args.source/'Cargo.lock'
if hashlib.sha256(lock.read_bytes()).hexdigest()!=inventory['lock_sha256']:
    raise ValueError('Unreviewed resvg lock')
work=args.work.resolve();vendor=work/'vendor';vendor.mkdir(parents=True)
def checksum(root,package):
    files={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest()
           for p in root.rglob('*') if p.is_file() and p.name!='.cargo-checksum.json'}
    (root/'.cargo-checksum.json').write_text(json.dumps({'package':package,'files':files},sort_keys=True))
for package in tomllib.loads(lock.read_text())['package']:
    origin=package.get('source','')
    if not origin.startswith('registry+'):continue
    if origin!='registry+https://github.com/rust-lang/crates.io-index':
        raise ValueError('Unreviewed registry')
    identity=package['name']+'-'+package['version'];archive=args.inputs/(identity+'.crate')
    if hashlib.sha256(archive.read_bytes()).hexdigest()!=package['checksum']:
        raise ValueError('Registry checksum differs: '+identity)
    with tarfile.open(archive) as tar:tar.extractall(vendor,filter='data')
    root=vendor/identity
    if not root.is_dir():raise ValueError('Unexpected crate root')
    checksum(root,package['checksum'])
commit='6201182cc109d45eb3596e81dede60783592db90'
archive=args.inputs/('resvg-'+commit+'.tar.gz')
if hashlib.sha256(archive.read_bytes()).hexdigest()!='87666753acee978cca371b236539cec13c640955839aa867c1f3265167ef9682':
    raise ValueError('Fixed resvg Git source differs')
unpack=work/'git-unpack';unpack.mkdir()
with tarfile.open(archive) as tar:tar.extractall(unpack,filter='data')
for item in inventory['git_vendor_metadata']:
    original=unpack/item['archive_path']
    if hashlib.sha256((original/'Cargo.toml').read_bytes()).hexdigest()!=item['original_manifest_sha256']:
        raise ValueError('Original Git manifest differs: '+item['name'])
    manifest=args.manifests/Path(item['normalized_manifest']).name
    if hashlib.sha256(manifest.read_bytes()).hexdigest()!=item['normalized_manifest_sha256']:
        raise ValueError('Normalized manifest differs: '+item['name'])
    root=vendor/item['name'];shutil.copytree(original,root)
    shutil.copyfile(manifest,root/'Cargo.toml');checksum(root,None)
home=work/'cargo-home';home.mkdir()
(home/'config.toml').write_text(
    '[source.crates-io]\nreplace-with="fixed-vendor"\n'
    '[source."git+https://github.com/zimond/resvg?rev=6201182c"]\n'
    'git="https://github.com/zimond/resvg"\nrev="6201182c"\n'
    'replace-with="fixed-vendor"\n[source.fixed-vendor]\ndirectory='+json.dumps(str(vendor))+'\n'
    '[net]\noffline=true\n')
print('Prepared resvg registry and six fixed Git packages without Git cache',flush=True)
