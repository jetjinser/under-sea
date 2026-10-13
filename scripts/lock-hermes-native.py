#!/usr/bin/env python3
"""Pin the exact native source releases used by Hermes's Node lock."""
import argparse
import concurrent.futures
import hashlib
from pathlib import Path
import runpy
import shutil
import tarfile
import tomllib

helpers = runpy.run_path(str(Path(__file__).with_name('lock-hermes.py')))
origin, scheme, fetch = helpers['origin'], helpers['scheme'], helpers['fetch']
COMPONENTS = {
    'rolldown': ('rolldown/rolldown', 'v1.2.1'),
    'tailwind': ('tailwindlabs/tailwindcss', 'v4.3.3'),
    'lightningcss': ('parcel-bundler/lightningcss', 'v1.32.0'),
    'swc': ('swc-project/swc', 'd7932596f2b1c99d04b9a8911d69458ed149ae59'),
    'rspack': ('web-infra-dev/rspack', 'v1.6.7'),
    'rollup': ('rollup/rollup', 'v4.34.9'),
}
RSPACK_GIT = 'git+https://github.com/mcountryman/simd-adler32.git?rev=b279034d9eb554c3e5e0af523db044f08d8297ba#b279034d9eb554c3e5e0af523db044f08d8297ba'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archives', type=Path, default=Path('/tmp'))
    parser.add_argument('--cache', type=Path, default=Path('/tmp/under-sea-hermes-native/inputs'))
    parser.add_argument('--output', type=Path, default=Path('under-sea/packages/hermes-native-lock.scm'))
    parser.add_argument('--component', action='append', choices=sorted(COMPONENTS),
                        help='Lock only the selected component (repeatable)')
    parser.add_argument('--tailwind-version', default='4.3.3')
    parser.add_argument('--lightningcss-version', default='1.32.0')
    parser.add_argument('--rspack-version', default='1.6.7')
    parser.add_argument('--rollup-version', default='4.34.9')
    parser.add_argument('--module', default='hermes-native-lock')
    parser.add_argument('--cargo-lock-overrides', type=Path,
                        help='JSON {component: Cargo.lock path} for archives that ship no lock')
    args = parser.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)
    cargo_overrides = json.loads(args.cargo_lock_overrides.read_text()) if args.cargo_lock_overrides else {}
    crates, component_crates, sources, component_git = {}, {}, {}, {}
    if not args.module or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789-' for c in args.module):
        raise ValueError('Invalid Scheme module name')
    for version in (args.tailwind_version, args.lightningcss_version, args.rspack_version, args.rollup_version):
        if len(version.split('.')) != 3 or not all(part.isdigit() for part in version.split('.')):
            raise ValueError('Expected exact native release version')
    components=dict(COMPONENTS)
    components['tailwind']=('tailwindlabs/tailwindcss','v'+args.tailwind_version)
    components['lightningcss']=('parcel-bundler/lightningcss','v'+args.lightningcss_version)
    components['rspack']=('web-infra-dev/rspack','v'+args.rspack_version)
    components['rollup']=('rollup/rollup','v'+args.rollup_version)
    for name, (repository, tag) in components.items():
        if name not in (args.component or ('rolldown', 'tailwind', 'lightningcss')):
            continue
        archive = args.archives / ('hermes-' + name + '-source.tar.gz')
        with tarfile.open(archive) as source:
            root = source.getmembers()[0].name.split('/')[0]
            if root != repository.rsplit('/',1)[-1]+'-'+tag.removeprefix('v'):
                raise ValueError('Native source archive/release mismatch: '+name)
            lock_path = {'swc': '/bindings/Cargo.lock', 'rollup': '/rust/Cargo.lock'}.get(name, '/Cargo.lock')
            override = cargo_overrides.get(name)
            if override:
                lock = tomllib.loads(Path(override).read_text())
            else:
                try:
                    lock = tomllib.loads(source.extractfile(root + lock_path).read().decode())
                except KeyError:
                    raise ValueError(
                        f'{name} archive has no {lock_path}; '
                        'supply one via --cargo-lock-overrides')
        reference = tag if name == 'swc' else 'refs/tags/' + tag
        sources[name] = (f'https://codeload.github.com/{repository}/tar.gz/{reference}', archive)
        component_crates[name] = []
        component_git[name] = []
        for crate in lock['package']:
            if 'source' not in crate:
                continue
            if not crate['source'].startswith('registry+'):
                if name == 'rspack' and crate['source'] == RSPACK_GIT and (crate['name'], crate['version']) == ('simd-adler32', '0.3.7'):
                    git_source = fetch((
                        'https://codeload.github.com/mcountryman/simd-adler32/tar.gz/b279034d9eb554c3e5e0af523db044f08d8297ba',
                        'rspack-simd-adler32-b279034-source.tar.gz',
                        '164ce6fb0a7d70c6713de282972e88058ae716b4a61191e63f1b005169c09f74', None), args.cache)
                    component_git[name].append((crate['source'], crate['name'], git_source))
                    continue
                raise ValueError(f'Unreviewed native Git dependency: {name}: {crate}')
            key = (crate['name'], crate['version'])
            if key in crates and crates[key] != crate['checksum']:
                raise ValueError('Conflicting native crate checksum')
            crates[key] = crate['checksum']
            component_crates[name].append(key)
    jobs = []
    for (name, version), checksum in sorted(crates.items()):
        filename = f'{name}-{version}.crate'
        destination = args.cache / filename
        for cache in [Path('/tmp/under-sea-hermes-lock/inputs'), Path('/tmp/under-sea-codex-lock/inputs')]:
            candidate = cache / filename
            if not destination.exists() and candidate.exists() and hashlib.sha256(candidate.read_bytes()).hexdigest() == checksum:
                shutil.copyfile(candidate, destination)
        jobs.append((f'https://static.crates.io/crates/{name}/{filename}', filename, checksum, None))
    print(f'{len(crates)} native registry crate sources', flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
        downloaded = dict(zip(sorted(crates), pool.map(lambda job: fetch(job, args.cache, 'https://static.crates.io/crates'), jobs)))
    output = [';;; Generated by scripts/lock-hermes-native.py; source-only native inputs.',
              f'(define-module (under-sea packages {args.module})',
              '  #:use-module (guix packages)', '  #:use-module (guix download)',
              '  #:use-module (guix base16))']
    for component, (url, archive) in sources.items():
        output.append(f'(define-public %hermes-{component}-source {origin(url, archive.name, archive)})')
        output.append(f'(define-public %hermes-{component}-crates\n  (list')
        for key in sorted(component_crates[component]):
            url, filename, archive = downloaded[key]
            output.append(f'    (list {scheme(key[0]+"-"+key[1])} {scheme(crates[key])} {origin(url,filename,archive)})')
        output.append('  ))')
        output.append(f'(define-public %hermes-{component}-git-sources\n  (list')
        for identity, name, (url, filename, archive) in component_git[component]:
            output.append(f'    (list {scheme(identity)} {scheme(name)} {origin(url,filename,archive)})')
        output.append('  ))')
    temporary = args.output.with_suffix('.scm.tmp')
    temporary.write_text('\n'.join(output) + '\n')
    temporary.replace(args.output)
    print(f'Wrote {args.output}', flush=True)


if __name__ == '__main__':
    main()
