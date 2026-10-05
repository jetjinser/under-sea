"""Provide wasm-bindgen's fixed unused mio Git patch as an offline source."""
import argparse
import hashlib
import json
from pathlib import Path
import tarfile
import tomllib

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('archive', type=Path)
parser.add_argument('checksum')
parser.add_argument('destination', type=Path)
parser.add_argument('config', type=Path)
args = parser.parse_args()
commit = '0788dbb67883cb6191503af999471def54e3fb77'
if hashlib.sha256(args.archive.read_bytes()).hexdigest() != args.checksum:
    raise ValueError('Fixed mio source archive checksum differs')
destination = args.destination.resolve()
destination.mkdir()
with tarfile.open(args.archive) as archive:
    roots = {member.name.split('/')[0] for member in archive.getmembers()}
    if roots != {'mio-' + commit}:
        raise ValueError('Unexpected fixed mio archive root')
    archive.extractall(destination, filter='data')
root = destination / ('mio-' + commit)
package = tomllib.loads((root/'Cargo.toml').read_text())['package']
if (package['name'], package['version']) != ('mio', '1.2.3'):
    raise ValueError('Unexpected fixed mio package identity')
files = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
         for p in root.rglob('*') if p.is_file() and p.name != '.cargo-checksum.json'}
(root/'.cargo-checksum.json').write_text(json.dumps(
    {'package': None, 'files': files}, sort_keys=True))
original = args.config.read_text()
if 'source.fixed-mio' in original:
    raise ValueError('Duplicate mio source replacement')
args.config.write_text(original +
    '\n[source."git+https://github.com/guybedford/mio?tag=1.2.3-cf.emscripten"]\n'
    'git="https://github.com/guybedford/mio"\n'
    'tag="1.2.3-cf.emscripten"\nreplace-with="fixed-mio"\n'
    '[source.fixed-mio]\ndirectory=' + json.dumps(str(destination)) + '\n')
print('Prepared authenticated offline mio Git source replacement', flush=True)
