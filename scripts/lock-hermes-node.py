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
from urllib.parse import quote

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
    parser.add_argument('--lockfile', default='package-lock.json',
                        help='lockfile path within the source tree and archive')
    parser.add_argument('--module', default='hermes-node-lock')
    parser.add_argument('--symbol', default='%hermes-node-sources')
    parser.add_argument('--production-only', action='store_true',
                        help='exclude packages marked dev in package-lock.json')
    parser.add_argument('--fetch', action='store_true', help='Download and hash source candidates; otherwise only audit')
    args = parser.parse_args()
    with tarfile.open(args.archive) as archive:
        root = archive.getmembers()[0].name.split('/')[0]
        locked = archive.extractfile(root + '/' + args.lockfile).read()
    if locked != (args.source / args.lockfile).read_bytes():
        raise ValueError('Source/archive Node lock mismatch: ' + args.lockfile)
    lock = json.loads(locked)
    if lock.get('lockfileVersion') not in (2, 3) or not isinstance(lock.get('packages'), dict):
        raise ValueError('Unsupported npm lock format')
    lock_version = lock['lockfileVersion']
    sources, native, excluded, workspace = [], [], [], []
    for path, entry in lock['packages'].items():
        if args.production_only and entry.get('dev', False):
            continue
        item = {'path': path, **{key: entry[key] for key in
                ('version', 'resolved', 'integrity', 'os', 'cpu', 'libc', 'hasInstallScript') if key in entry}}
        if item.get('resolved', '').startswith('https://registry.nlark.com/'):
            # Legacy shrinkwrap URLs from a dead registry can be canonicalized
            # to npm's immutable package archive; the lock integrity remains
            # the authority for accepting the bytes.
            package = path.rsplit('node_modules/', 1)[-1]
            item['resolved'] = (
                'https://registry.npmjs.org/' + quote(package, safe='@/')
                + '/-/' + quote(package.rsplit('/', 1)[-1] + '-' + item['version'], safe='@+._-')
                + '.tgz')
        if (lock_version == 2 and path.startswith('node_modules/')
                and not item.get('resolved') and item.get('version')):
            package = path.rsplit('node_modules/', 1)[-1]
            filename = package.rsplit('/', 1)[-1]
            item['resolved'] = (
                'https://registry.npmjs.org/' + quote(package, safe='@/')
                + '/-/' + quote(filename + '-' + item['version'], safe='@+._-')
                + '.tgz')
        if any(not supported(entry.get(key, []), target)
               for key, target in [('os', 'linux'), ('cpu', 'x64'), ('libc', 'glibc')]):
            excluded.append(item)
        elif entry.get('os') or entry.get('cpu') or path.endswith('/electron'):
            # Platform payload packages (esbuild, oxide, rolldown, lightningcss,
            # Electron) must be replaced by source-built native components.
            native.append(item)
        elif entry.get('link') or not item.get('resolved'):
            workspace.append(item)
        else:
            if not any(item['resolved'].startswith(prefix) for prefix in (
                    'https://registry.npmjs.org/',
                    'https://registry.npmmirror.com/',
                    'https://registry.nlark.com/',
                    'https://registry.yarnpkg.com/')):
                raise ValueError('Unreviewed Node source URL: ' + item['resolved'])
            sources.append(item)
    inventory = {'platform': 'linux-x64-glibc', 'lockfileVersion': lock_version,
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
        algorithm = 'sha512'
        if not digests:
            digests = [value for value in integrity if value.startswith('sha1-')]
            algorithm = 'sha1'
        if len(digests) != 1:
            raise ValueError('Expected one supported npm integrity: ' + item['path'])
        expected = base64.b64decode(digests[0][len(algorithm) + 1:], validate=True)
        filename = hashlib.sha256(item['resolved'].encode()).hexdigest()[:16] + '.tgz'
        destination = args.cache / filename
        def valid(path):
            return (path.exists()
                    and hashlib.new(algorithm, path.read_bytes()).digest() == expected)
        if not valid(destination):
            temporary = destination.with_suffix('.part')
            urls = [item['resolved']]
            if item['resolved'].startswith('https://registry.npmjs.org/'):
                # The Yarn registry serves the same npm tarballs and is
                # reachable in environments where registry.npmjs.org is not.
                # Integrity is checked against package-lock.json below, so
                # trying it first is safe and avoids spending minutes retrying
                # an unreachable primary registry for every package.
                urls.insert(0, item['resolved'].replace(
                    'https://registry.npmjs.org/', 'https://registry.yarnpkg.com/',
                    1))
                urls.append(item['resolved'].replace(
                    'https://registry.npmjs.org/', 'https://registry.npmmirror.com/',
                    1))
            error = None
            for url in urls:
                try:
                    subprocess.run(
                        ['curl', '-fLsS', '--retry', '2', '--retry-all-errors',
                         '--retry-delay', '1', '--connect-timeout', '10',
                         '--max-time', '120', '-o', str(temporary), url], check=True)
                except subprocess.CalledProcessError as exc:
                    error = exc
                    continue
                if valid(temporary):
                    temporary.replace(destination)
                    break
                error = ValueError('Node source integrity mismatch: ' + item['path'])
            else:
                raise error or ValueError('Cannot fetch Node source: ' + item['path'])
        # Stream compressed tarballs once.  Random-access reads from a gzip
        # tar repeatedly decompress from the start and become quadratic for
        # large packages such as openclaw.
        with tarfile.open(destination, mode='r|*') as archive:
            for member in archive:
                if not member.isfile():
                    continue
                if member.name.endswith(('.node', '.dll', '.exe', '.so', '.dylib', '.wasm')):
                    return None
                stream = archive.extractfile(member)
                prefix = stream.read(4)
                if prefix in (b'\x7fELF', b'\x00asm', b'\xfe\xed\xfa\xce',
                              b'\xce\xfa\xed\xfe', b'\xfe\xed\xfa\xcf', b'\xcf\xfa\xed\xfe'):
                    return None
                if member.name.endswith(('.js', '.mjs', '.cjs')):
                    text = prefix + stream.read()
                    if b'AGFzb' in text:
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
