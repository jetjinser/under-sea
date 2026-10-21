#!/usr/bin/env python3
"""Generate a source-only Python runtime lock for an external PyPI closure.

Reuses the Hermes lock helpers (marker/fetch/origin/scheme) but is decoupled
from the Hermes source archive: the closure is selected from an arbitrary
uv.lock produced for a synthetic project.  Wheel-only distributions must be
supplied as independent source-built Guix components (``--components``) and are
listed separately rather than fetched as sdists.
"""
import argparse, concurrent.futures, json, tarfile, tomllib
from pathlib import Path

from lock_lib import fetch, marker, origin, scheme


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('lock', type=Path)
    p.add_argument('--root', required=True)
    p.add_argument('--module', required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--cache', type=Path, default=Path('/tmp/under-sea-browser-lock/inputs'))
    p.add_argument('--components', type=Path,
                   help='JSON {name: {version, module, recipe, output}} for wheel-only components')
    p.add_argument('--extra', action='append', default=[])
    p.add_argument('--exclude', action='append', default=[],
                   help='Package names provided transitively by a component bundle; '
                        'omit them from the source list')
    p.add_argument('--cargo-lock-overrides', type=Path,
                   help='JSON {package-name: Cargo.lock path} for sdists that ship no lock')
    args = p.parse_args(); args.cache.mkdir(parents=True, exist_ok=True)

    lock = tomllib.loads(args.lock.read_text())
    packages = {}
    for package in lock['package']:
        packages.setdefault(package['name'], []).append(package)

    def select(dep):
        candidates = [x for x in packages.get(dep['name'], [])
                      if 'version' not in dep or x['version'] == dep['version']]
        if len(candidates) != 1:
            raise ValueError(f'Ambiguous/missing dependency: {dep}')
        return candidates[0]

    selected, extras, graph = {}, {}, {}
    root_package = select({'name': args.root})
    unknown = set(args.extra) - set(root_package.get('optional-dependencies', {}))
    if unknown:
        raise ValueError(f'Unknown extras: {sorted(unknown)}')
    queue = [({'name': args.root}, args.extra)]
    while queue:
        dependency, wanted = queue.pop(0)
        name = dependency['name']
        pkg = select(dependency)
        if name in selected and selected[name]['version'] != pkg['version']:
            raise ValueError(f'Conflicting versions: {name}')
        old = extras.setdefault(name, set()); added = set(wanted) - old
        if name in selected and not added:
            continue
        old.update(wanted); selected[name] = pkg
        deps = list(pkg.get('dependencies', []))
        for extra in sorted(old):
            deps += pkg.get('optional-dependencies', {}).get(extra, [])
        graph[name] = []
        for dep in deps:
            if marker(dep.get('marker', 'True')):
                select(dep)
                if dep['name'] != name:
                    graph[name].append(dep['name'])
                queue.append((dep, dep.get('extra', [])))

    order, active, runtime_cycles = [], set(), []
    def visit(name):
        if name in order:
            return
        if name in active:
            runtime_cycles.append(name)
            return
        active.add(name)
        for dep in graph[name]:
            visit(dep)
        active.remove(name); order.append(name)
    visit(args.root); order.remove(args.root)

    components = json.loads(args.components.read_text()) if args.components else {}
    cargo_overrides = (json.loads(args.cargo_lock_overrides.read_text())
                       if args.cargo_lock_overrides else {})
    for name, component in components.items():
        if name not in selected or selected[name]['version'] != component['version']:
            raise ValueError('Independent component does not match selected lock: ' + name)
        if not component.get('recipe') or not component.get('module'):
            raise ValueError('Independent component lacks explicit Guix recipe: ' + name)
    excluded = set(args.exclude)
    for name in excluded:
        if name not in selected:
            raise ValueError('Excluded package not in closure: ' + name)
    source_order = [name for name in order if name not in components and name not in excluded]
    missing = [name for name in source_order if 'sdist' not in selected[name]]
    if missing:
        raise ValueError('No locked sdist for: ' + ', '.join(missing) +
                         ' (add as source-built component)')

    inputs = []
    for name in source_order:
        sdist = selected[name]['sdist']
        url = sdist['url']
        inputs.append((url, url.rsplit('/', 1)[1],
                       sdist['hash'].removeprefix('sha256:'), sdist['size']))
    print(f'{len(source_order)} Python sources; {len(components)} components', flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        sources = list(pool.map(lambda x: fetch(x, args.cache), inputs))

    crates = {}
    for pkgname, (_, name, path) in zip(source_order, sources):
        with tarfile.open(path) as tar:
            root = tar.getmembers()[0].name.split('/')[0]
            try:
                project = tomllib.loads(tar.extractfile(root + '/pyproject.toml').read().decode())
            except KeyError:
                continue
            backend = project.get('build-system', {}).get('build-backend', '')
            if 'maturin' not in backend and not any(
                    'setuptools-rust' in req
                    for req in project.get('build-system', {}).get('requires', [])):
                continue
            locks = []
            if pkgname in cargo_overrides:
                locks.append(tomllib.loads(Path(cargo_overrides[pkgname]).read_text()))
            else:
                for member in tar.getmembers():
                    if member.name.endswith('/Cargo.lock'):
                        locks.append(tomllib.loads(tar.extractfile(member).read().decode()))
                if not locks:
                    raise ValueError(
                        f'{pkgname} builds a Rust extension but ships no Cargo.lock; '
                        'supply one via --cargo-lock-overrides')
            for data in locks:
                for crate in data['package'] + data.get('patch', {}).get('unused', []):
                    if 'source' not in crate or not crate['source'].startswith('registry+'):
                        continue
                    if 'checksum' not in crate:
                        continue
                    if crate['name'].startswith('protoc-bin-vendored'):
                        continue
                    key = (crate['name'], crate['version'])
                    if key in crates and crates[key] != crate['checksum']:
                        raise ValueError('Conflicting crate checksum')
                    crates[key] = crate['checksum']
    crate_inputs = [(f'https://static.crates.io/crates/{n}/{n}-{v}.crate',
                     f'{n}-{v}.crate', c, None) for (n, v), c in sorted(crates.items())]
    print(f'{len(crates)} Rust crates', flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=24) as pool:
        crate_sources = list(pool.map(lambda x: fetch(x, args.cache), crate_inputs))

    if not args.module or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789-' for c in args.module):
        raise ValueError('Invalid Scheme module name')
    output = [';;; Generated by scripts/lock-hermes-browser.py; source inputs only.',
              f'(define-module (under-sea packages {args.module})',
              '  #:use-module (guix packages)',
              '  #:use-module (guix download)',
              '  #:use-module (guix base16))',
              '(define-public %hermes-python-sources\n  (list']
    for pkgname, (url, name, path) in zip(source_order, sources):
        output.append(f'    (list {scheme(pkgname)} {scheme(selected[pkgname]["version"])} {origin(url, name, path)})')
    output += ['  ))', '(define-public %hermes-python-component-requirements\n  (list']
    for name, component in sorted(components.items()):
        output.append('    (list ' + ' '.join(scheme(value) for value in
                      (name, component['version'], component['module'], component['recipe'],
                       component.get('output', 'out'))) + ')')
    output += ['  ))', '(define-public %hermes-crate-sources\n  (list']
    for (key, checksum), (url, name, path) in zip(sorted(crates.items()), crate_sources):
        output.append(f'    (list {scheme(key[0]+"-"+key[1])} {scheme(checksum)} {origin(url, name, path)})')
    output += ['  ))', '']
    temporary = args.output.with_suffix(args.output.suffix + '.tmp')
    temporary.write_text('\n'.join(output)); temporary.replace(args.output)
    print(f'Wrote {args.output}', flush=True)


if __name__ == '__main__':
    main()
