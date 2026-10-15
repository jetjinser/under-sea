#!/usr/bin/env python3
"""Lock pikevm's exact registry sources for offline Linux builds."""
import hashlib
import json
from pathlib import Path
import tomllib

source = Path('/home/jinser/models/pikevm-src')
cache = Path('/tmp/under-sea-pikevm-sources/inputs')
output = Path('/home/jinser/pkgs/under-sea/modules/under-sea/packages/pikevm-lock.scm')
commit = '55ccff62fc39fb7745f6dceaf5f19605cafa3dc0'
version = '0.1.0'
cache.mkdir(parents=True, exist_ok=True)

lock = tomllib.loads((source / 'Cargo.lock').read_text())
crates = sorted((p['name'], p['version'], p['checksum'])
                for p in lock['package'] if p.get('source', '').startswith('registry+'))
print(f'Locking {len(crates)} registry crates', flush=True)

import urllib.request
def download(item):
    name, chksum = item
    url = f'https://static.crates.io/crates/{name}/{name}-{chksum[:1] if False else ""}'.rstrip('/')
    # static.crates.io path: /crate/version with version being the crate's own
    return None  # replaced below

sources = []
for name, ver, chk in sorted((p['name'], p['version'], p.get('checksum', ''))
                             for p in lock['package'] if p.get('source', '').startswith('registry+')):
    url = f'https://static.crates.io/crates/{name}/{name}-{ver}.crate'
    filename = f'{name}-{ver}.crate'
    dest = cache / filename
    if dest.exists() and hashlib.sha256(dest.read_bytes()).hexdigest() == chk:
        sources.append((name, chk, dest))
        continue
    print(f'  downloading {filename}...', flush=True)
    for attempt in range(3):
        try:
            urllib.request.urlretrieve(url, dest)
            break
        except Exception as e:
            print(f'  retry {attempt+1}: {e}', flush=True)
    got = hashlib.sha256(dest.read_bytes()).hexdigest()
    assert got == chk, f'checksum mismatch: {filename}'
    sources.append((name, chk, dest))
    print(f'  {filename}: sha256 OK', flush=True)

lines = [';;; Generated for the pikevm package; exact registry sources.',
         '(define-module (under-sea packages pikevm-lock)',
         '  #:use-module (guix packages)', '  #:use-module (guix download)',
         '  #:use-module (guix base16))',
         '(define-public %pikevm-version ' + json.dumps(version) + ')',
         '(define-public %pikevm-source',
         '  (origin (method git-fetch)',
         '          (uri (git-reference',
         '                (url "https://github.com/jwiegley/pikevm")',
         '                (commit ' + json.dumps(commit) + ')))',
         '          (file-name (git-file-name "pikevm" version))',
         '          (sha256 (base16-string->bytevector "PIKEVM_TREE_HASH"))))',
         '(define-public %pikevm-crate-sources (list']
for name, ver, chk, dest in sources:
    url = f'https://static.crates.io/crates/{name}/{name}-{ver}.crate'
    lines.append('  (list ' + json.dumps(name + '-' + ver) + ' '
                 + json.dumps(chk) + ' '
                 + f'(origin (method url-fetch) (uri {json.dumps(url)}) '
                 + f'(sha256 (base16-string->bytevector {json.dumps(hashlib.sha256(dest.read_bytes()).hexdigest())}))))')
lines.append('))')
output.write_text('\n'.join(lines) + '\n')
print(f'Wrote {output}')
