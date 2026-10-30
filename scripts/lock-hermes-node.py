#!/usr/bin/env python3
"""Lock Hermes Node source archives, separating native binary distributions."""
import argparse
import base64
import concurrent.futures
import hashlib
import json
import re
from pathlib import Path
import subprocess
import tarfile

from lock_lib import origin, scheme


def supported(values, target):
    positives = [value for value in values if not value.startswith('!')]
    return ('!' + target) not in values and (not positives or target in positives)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('source', type=Path)
    parser.add_argument('--cache', type=Path, default=Path('/tmp/under-sea-hermes-node/inputs'))
    parser.add_argument('--inventory', type=Path, default=Path('planning/hermes-node-inventory.json'))
    parser.add_argument('--output', type=Path, default=Path('modules/under-sea/packages/hermes-node-lock.scm'))
    parser.add_argument('--module', default='hermes-node-lock')
    parser.add_argument('--symbol', default='%hermes-node-sources')
    parser.add_argument('--fetch', action='store_true', help='Download and hash source candidates; otherwise only audit')
    args = parser.parse_args()
    with tarfile.open(args.archive) as archive:
        root = archive.getmembers()[0].name.split('/')[0]
        locked = archive.extractfile(root + '/package-lock.json').read()
    if locked != (args.source / 'package-lock.json').read_bytes():
        raise ValueError('Source/archive Node lock mismatch')
    lock = json.loads(locked)
    if lock['lockfileVersion'] != 3:
        raise ValueError('Unsupported npm lock format')
    sources, native, excluded, workspace = [], [], [], []
    for path, entry in lock['packages'].items():
        item = {'path': path, **{key: entry[key] for key in
                ('version', 'resolved', 'integrity', 'os', 'cpu', 'libc', 'hasInstallScript') if key in entry}}
        if any(not supported(entry.get(key, []), target)
               for key, target in [('os', 'linux'), ('cpu', 'x64'), ('libc', 'glibc')]):
            excluded.append(item)
        elif entry.get('os') or entry.get('cpu') or path.endswith('/electron'):
            # Platform payload packages (esbuild, oxide, rolldown, lightningcss,
            # Electron) must be replaced by source-built native components.
            native.append(item)
        elif entry.get('link') or not entry.get('resolved'):
            workspace.append(item)
        else:
            if not entry['resolved'].startswith('https://registry.npmjs.org/'):
                raise ValueError('Unreviewed Node source URL: ' + entry['resolved'])
            sources.append(item)
    inventory = {'platform': 'linux-x64-glibc', 'lockfileVersion': 3,
                 'selected': sources, 'native_candidates': native,
                 'excluded_platforms': excluded, 'workspace': workspace}
    args.inventory.write_text(json.dumps(inventory, indent=2) + '\n')
    print(f'{len(sources)} source candidates; {len(native)} native replacements; '
          f'{len(excluded)} foreign platform entries', flush=True)
    if not args.fetch:
        return
    args.cache.mkdir(parents=True, exist_ok=True)

    def fetch(item):
        integrity = item['integrity'].split()
        digests = [value for value in integrity if value.startswith('sha512-')]
        if len(digests) != 1:
            raise ValueError('Expected one SHA512 integrity: ' + item['path'])
        expected = base64.b64decode(digests[0][7:], validate=True)
        filename = hashlib.sha256(item['resolved'].encode()).hexdigest()[:16] + '.tgz'
        destination = args.cache / filename
        def valid(path):
            return path.exists() and hashlib.sha512(path.read_bytes()).digest() == expected
        if not valid(destination):
            temporary = destination.with_suffix('.part')
            urls = [item['resolved']]
            if item['resolved'].startswith('https://registry.npmjs.org/'):
                urls.append(item['resolved'].replace(
                    'https://registry.npmjs.org/', 'https://registry.yarnpkg.com/',
                    1))
                urls.append(item['resolved'].replace(
                    'https://registry.npmjs.org/', 'https://registry.npmmirror.com/',
                    1))
            error = None
            for url in urls:
                try:
                    subprocess.run(
                        ['curl', '-fLsS', '--retry', '20', '--retry-all-errors', '--retry-delay', '2', '--connect-timeout', '30',
                         '--max-time', '300', '-o', str(temporary), url], check=True)
                except subprocess.CalledProcessError as exc:
                    error = exc
                    continue
                if valid(temporary):
                    temporary.replace(destination)
                    break
                error = ValueError('Node source integrity mismatch: ' + item['path'])
            else:
                raise error or ValueError('Cannot fetch Node source: ' + item['path'])
        with tarfile.open(destination) as archive:
            for member in archive.getmembers():
                if not member.isfile():
                    continue
                if member.name.endswith(('.node', '.dll', '.exe', '.so', '.dylib', '.wasm')):
                    return None
                prefix = archive.extractfile(member).read(4)
                if prefix in (b'\x7fELF', b'\x00asm', b'\xfe\xed\xfa\xce',
                              b'\xce\xfa\xed\xfe', b'\xfe\xed\xfa\xcf', b'\xcf\xfa\xed\xfe'):
                    return None
                if member.name.endswith(('.js', '.mjs', '.cjs')):
                    text = archive.extractfile(member).read()
                    for encoded in re.findall(rb'''['"](AGFzb[A-Za-z0-9+/=]+)['"]''', text):
                        try:
                            decoded = base64.b64decode(encoded, validate=True)
                        except ValueError:
                            continue
                        if decoded[:8] == b'\x00asm\x01\x00\x00\x00':
                            return None
        return destination

    # Fetch shared archives once; retain each original node_modules path so
    # nested dependency versions can later be installed without flattening.
    unique = {}
    for item in sources:
        unique.setdefault((item['resolved'], item['integrity']), item)
    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
        archives = dict(zip(unique, pool.map(fetch, unique.values())))
    blocked = [item for item in sources if archives[(item['resolved'], item['integrity'])] is None]
    sources = [item for item in sources if archives[(item['resolved'], item['integrity'])] is not None]
    inventory['selected'] = sources
    inventory['native_candidates'].extend(blocked)
    inventory['audited_native_payloads'] = blocked
    args.inventory.write_text(json.dumps(inventory, indent=2) + '\n')
    if blocked:
        print('Excluded native archives after payload audit: ' + ', '.join(item['path'] for item in blocked), flush=True)
    output = [';;; Generated by scripts/lock-hermes-node.py; native payloads excluded.',
              f'(define-module (under-sea packages {args.module})',
              '  #:use-module (guix packages)', '  #:use-module (guix download)',
              '  #:use-module (guix base16))', f'(define-public {args.symbol}\n  (list']
    for item in sources:
        path = archives[(item['resolved'], item['integrity'])]
        output.append('    (list ' + scheme(item['path']) + ' ' + scheme(item['version'])
                      + ' ' + origin(item['resolved'], path.name, path) + ')')
    output += ['  ))', '']
    temporary = args.output.with_suffix('.scm.tmp')
    temporary.write_text('\n'.join(output))
    temporary.replace(args.output)
    print(f'Wrote {args.output}', flush=True)


if __name__ == '__main__':
    main()
