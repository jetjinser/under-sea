"""Stage the authenticated source matching Next's committed lru-cache bundle."""
import argparse
import hashlib
import json
from pathlib import Path
import tarfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('archive', type=Path)
args = parser.parse_args()
# Upstream's task references an undeclared hoisted dependency. Source rebuilding
# 7.18.3 matches its committed bundle except path-derived webpack module IDs.
expected = 'a515ad58d60fc9fe0d904a169f4e53ced2484ead0d73d4f3c78256a91e8fd47d'
if hashlib.sha256(args.archive.read_bytes()).hexdigest() != expected:
    raise ValueError('lru-cache source archive hash mismatch')
package = args.source / 'packages/next'
version = json.loads((package / 'package.json').read_text())['version']
if version != '16.0.8':
    raise ValueError('Only Next 16.0.8 source bundle has been compared')
target = args.source / 'node_modules/.sources/guix-lru-cache-7.18.3'
if target.exists():
    raise ValueError('Source input already staged')
with tarfile.open(args.archive) as archive:
    archive.extractall(target, filter='data')
implementation = target / 'package'
metadata = json.loads((implementation / 'package.json').read_text())
if (metadata['name'], metadata['version']) != ('lru-cache', '7.18.3'):
    raise ValueError('lru-cache source package identity mismatch')
alias = package / 'node_modules/lru-cache'
if alias.exists() or alias.is_symlink():
    raise ValueError('Existing lru-cache alias must not be overwritten')
alias.symlink_to(implementation.resolve())
