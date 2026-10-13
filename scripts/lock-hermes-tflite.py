#!/usr/bin/env python3
"""Lock reviewed TFLite CPU source archives outside the Guix build sandbox.

This top-level lock is not yet a recursive XNNPACK/ruy dependency lock.
"""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import subprocess
import tarfile

inventory = json.loads(Path('planning/hermes-tflite-inventory.json').read_text())
cache = Path('/tmp/under-sea-hermes-tflite-sources')
cache.mkdir(parents=True, exist_ok=True)
items = []
for item in inventory['git_inputs']:
    if item['target_scope'] != 'CPU/Python required':
        continue
    name = Path(item['module']).stem
    repository = item['repository'].removesuffix('.git')
    if repository.startswith('https://github.com/'):
        url = repository.replace('https://github.com/', 'https://codeload.github.com/')
        url += '/tar.gz/' + item['revision']
    elif repository == 'https://gitlab.com/libeigen/eigen':
        url = repository + '/-/archive/' + item['revision'] + '/eigen.tar.gz'
    else:
        raise ValueError('Unreviewed repository: ' + repository)
    items.append((name, url, None))
for item in inventory['url_inputs']:
    items.append((Path(item['module']).stem, item['url'], item['sha256']))

def fetch(item):
    name, url, expected = item
    archive = cache / (name + '.tar.gz')
    if not archive.exists():
        temporary = archive.with_suffix('.partial')
        subprocess.run(['curl', '-fsSL', '--retry', '3', url, '-o', str(temporary)], check=True)
        temporary.rename(archive)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    if expected and digest != expected:
        raise ValueError('Upstream SHA256 mismatch: ' + name)
    with tarfile.open(archive) as source:
        for member in source:
            if member.name.startswith('/') or '..' in Path(member.name).parts:
                raise ValueError('Unsafe archive member: ' + name)
    print('Verified ' + name, flush=True)
    return name, url, digest

with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    sources = sorted(pool.map(fetch, items))
lines = [';;; TFLite top-level CPU source archives; recursive closure still pending.',
         '(define-module (under-sea packages hermes-tflite-lock)',
         '  #:use-module (guix packages)', '  #:use-module (guix download)',
         '  #:use-module (guix base16))',
         '(define-public %hermes-tflite-sources', ' (list']
for name, url, digest in sources:
    lines.append(f'  (list "{name}" (origin (method url-fetch) (uri "{url}") '
                 f'(file-name "tflite-{name}-source.tar.gz") '
                 f'(sha256 (base16-string->bytevector "{digest}"))))')
lines.append(' ))')
Path('modules/under-sea/packages/hermes-tflite-lock.scm').write_text('\n'.join(lines) + '\n')
print(f'Locked {len(sources)} top-level CPU source archives.')
