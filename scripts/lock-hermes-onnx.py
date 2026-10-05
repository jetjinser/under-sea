#!/usr/bin/env python3
"""Lock exact ONNX Runtime CPU/Python source dependencies outside Guix builds."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import subprocess
from urllib.parse import urlsplit
import zipfile

inventory = json.loads(Path('planning/hermes-onnxruntime-inventory.json').read_text())
selected = set('abseil_cpp re2 protobuf date mp11 json pytorch_cpuinfo microsoft_gsl '
               'safeint flatbuffers onnx eigen dlpack pybind11 cxxopts mimalloc'.split())
cache = Path('/tmp/under-sea-hermes-onnx-sources')
cache.mkdir(parents=True, exist_ok=True)

def fetch(item):
    name = item['name']
    parsed = urlsplit(item['url'])
    if parsed.netloc != 'github.com' or '/archive/' not in parsed.path:
        raise ValueError('Expected a GitHub source archive: ' + name)
    repository, reference = parsed.path.strip('/').split('/archive/', 1)
    if name == 'eigen':
        reference = reference.split('/')[0]
    else:
        reference = reference.removesuffix('.zip')
    url = f'https://codeload.github.com/{repository}/zip/{reference}'
    archive = cache / (name + '.zip')
    if not archive.exists():
        subprocess.run(['curl', '-fsSL', '--retry', '3', url, '-o', str(archive)], check=True)
    data = archive.read_bytes()
    if hashlib.sha1(data).hexdigest() != item['upstream_sha1']:
        raise ValueError('Upstream source hash mismatch: ' + name)
    with zipfile.ZipFile(archive) as source:
        for member in source.infolist():
            if member.filename.startswith('/') or '..' in Path(member.filename).parts:
                raise ValueError('Unsafe source archive path: ' + name)
    return name, url, item['upstream_sha1'], hashlib.sha256(data).hexdigest()

items = [item for item in inventory['external_inputs'] if item['name'] in selected]
if {item['name'] for item in items} != selected:
    raise ValueError('Missing reviewed ONNX source input')
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    sources = sorted(pool.map(fetch, items))
lines = [';;; Exact upstream ONNX Runtime CPU/Python external source archives.',
         '(define-module (under-sea packages hermes-onnx-lock)',
         '  #:use-module (guix packages)', '  #:use-module (guix download)',
         '  #:use-module (guix base16))', '(define-public %hermes-onnx-sources', ' (list']
for name, url, sha1, sha256 in sources:
    lines.append(f'  (list "{name}" "{sha1}" (origin (method url-fetch) '
                 f'(uri "{url}") (file-name "onnx-{name}-source.zip") '
                 f'(sha256 (base16-string->bytevector "{sha256}"))))')
lines.append(' ))')
Path('under-sea/packages/hermes-onnx-lock.scm').write_text('\n'.join(lines) + '\n')
print(f'Locked {len(sources)} verified upstream source archives; no protoc binary downloaded.')
