#!/usr/bin/env python3
"""Lock Sherpa ONNX's reviewed CPU/Python source archive declarations."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import subprocess
from urllib.parse import urlsplit

inventory = json.loads(Path('planning/hermes-sherpa-source-inventory.json').read_text())
cache = Path('/tmp/under-sea-hermes-sherpa-sources')
cache.mkdir(parents=True, exist_ok=True)
items = [x for x in inventory['archive_declarations']
         if not x['module'].startswith('onnxruntime')
         and x['module'] != 'googletest.cmake']

def fetch(item):
    if len(item['primary_urls']) != 1 or len(item['sha256']) != 1:
        raise ValueError('Ambiguous source declaration: ' + item['module'])
    url = item['primary_urls'][0]
    parsed = urlsplit(url)
    if parsed.netloc == 'github.com':
        repository, reference = parsed.path.strip('/').split('/archive/', 1)
        kind = 'zip' if reference.endswith('.zip') else 'tar.gz'
        reference = reference.removesuffix('.' + kind)
        url = f'https://codeload.github.com/{repository}/{kind}/{reference}'
    elif parsed.netloc in ('gitlab.com', 'files.portaudio.com'):
        kind = 'tar.gz'
    else:
        raise ValueError('Unreviewed source host: ' + url)
    name = Path(item['module']).stem
    filename = 'sherpa-' + name + '-source.' + kind
    archive = cache / filename
    if not archive.exists():
        temporary = archive.with_suffix('.partial')
        subprocess.run(['curl', '-fsSL', '--retry', '3', url, '-o', str(temporary)], check=True)
        temporary.rename(archive)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    if digest != item['sha256'][0]:
        raise ValueError('Upstream SHA256 mismatch: ' + name)
    print('Verified ' + name, flush=True)
    return name, url, filename, digest

with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    sources = sorted(pool.map(fetch, items))
lines = [';;; Verified Sherpa ONNX CPU source declarations; recursive audit pending.',
         '(define-module (under-sea packages hermes-sherpa-lock)',
         '  #:use-module (guix packages)', '  #:use-module (guix download)',
         '  #:use-module (guix base16))',
         '(define-public %hermes-sherpa-sources', ' (list']
for name, url, filename, digest in sources:
    lines.append(f'  (list "{name}" (origin (method url-fetch) (uri "{url}") '
                 f'(file-name "{filename}") '
                 f'(sha256 (base16-string->bytevector "{digest}"))))')
lines.append(' ))')
Path('modules/under-sea/packages/hermes-sherpa-lock.scm').write_text('\n'.join(lines) + '\n')
print(f'Locked {len(sources)} source archives; no ONNX Runtime binaries downloaded.')
