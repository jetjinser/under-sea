"""Select the complete CLI workspace while preserving all bins and features."""
import argparse
import hashlib
from pathlib import Path
import re
import tomllib

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('lock', type=Path)
parser.add_argument('--original-lock', type=Path, required=True)
args = parser.parse_args()
def identities(path):
    return {(p['name'],p['version'],p['source'],p.get('checksum'))
            for p in tomllib.loads(path.read_text())['package'] if 'source' in p}
if not identities(args.lock) <= identities(args.original_lock):
    raise ValueError('CLI lock changes an authenticated external identity')
manifest = args.source/'Cargo.toml'
text = manifest.read_text()
if tomllib.loads(text)['package']['version'] != '0.2.129':
    raise ValueError('Unexpected wasm-bindgen source version')
cli = tomllib.loads((args.source/'crates/cli/Cargo.toml').read_text())
bins = {item['name'] for item in cli['bin']}
if bins != {'wasm-bindgen','wasm-bindgen-test-runner','wasm2es6js'}:
    raise ValueError('CLI binary set changed')
if cli['features']['default'] != ['rustls-tls']:
    raise ValueError('CLI default feature set changed')
pattern = r'(?ms)(\[workspace\]\n.*?^members = \[).*?^\]'
patched, count = re.subn(pattern,
    lambda m: m.group(1)+'\n  "crates/cli",\n]', text, count=1)
if count != 1:
    raise ValueError('Unexpected workspace members declaration')
manifest.write_text(patched)
(args.source/'Cargo.lock').write_bytes(args.lock.read_bytes())
print('Prepared all three CLI binaries with unchanged default features; lock '
      + hashlib.sha256(args.lock.read_bytes()).hexdigest(), flush=True)
