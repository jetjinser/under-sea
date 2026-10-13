#!/usr/bin/env python3
"""Lock Linux/Python 3.12 Hermes components and Rust dependencies from source."""
import argparse, ast, concurrent.futures, hashlib, json, os, runpy, subprocess, tarfile, tomllib
from pathlib import Path

helpers = runpy.run_path(str(Path(__file__).with_name('lock-sing-box.py')))
origin, scheme = helpers['origin'], helpers['scheme']
ENV = dict(sys_platform='linux', platform_machine='x86_64', platform_release='6.6.0', platform_system='Linux', platform_python_implementation='CPython', python_version='3.12', python_full_version='3.12.12', implementation_name='cpython', implementation_version='3.12.12', os_name='posix', extra='')

def marker(expression):
    def walk(node):
        if isinstance(node, ast.Expression): return walk(node.body)
        if isinstance(node, ast.Name): return ENV[node.id]
        if isinstance(node, ast.Constant): return node.value
        if isinstance(node, ast.BoolOp):
            vals = [walk(x) for x in node.values]
            return all(vals) if isinstance(node.op, ast.And) else any(vals)
        if isinstance(node, ast.Compare):
            left = walk(node.left)
            for op, rightnode in zip(node.ops, node.comparators):
                right = walk(rightnode)
                a, b = left, right
                if isinstance(op, (ast.Lt, ast.LtE, ast.Gt, ast.GtE)):
                    a, b = tuple(map(int, a.split('.'))), tuple(map(int, b.split('.')))
                if isinstance(op, ast.Eq): ok = a == b or (str(b).endswith('.*') and str(a).startswith(str(b)[:-1]))
                elif isinstance(op, ast.NotEq): ok = not (a == b or (str(b).endswith('.*') and str(a).startswith(str(b)[:-1])))
                elif isinstance(op, ast.Lt): ok = a < b
                elif isinstance(op, ast.LtE): ok = a <= b
                elif isinstance(op, ast.Gt): ok = a > b
                elif isinstance(op, ast.GtE): ok = a >= b
                elif isinstance(op, ast.In): ok = a in b
                elif isinstance(op, ast.NotIn): ok = a not in b
                else: raise ValueError(expression)
                if not ok: return False
                left = right
            return True
        raise ValueError(f'Unsupported lock marker: {expression}')
    return walk(ast.parse(expression, mode='eval'))

def fetch(item, cache, crate_mirror=None):
    url, name, expected, size = item
    download_url = url
    if crate_mirror and url.startswith('https://static.crates.io/crates/'):
        download_url = crate_mirror.rstrip('/') + '/' + '/'.join(url.split('/')[-2:])
    dest = cache / name
    def valid(): return dest.exists() and hashlib.sha256(dest.read_bytes()).hexdigest() == expected
    if not valid():
        tmp = dest.with_suffix(dest.suffix + '.part')
        if size and size > 2 * 1024 * 1024:
            parts = cache / (name + '.parts'); parts.mkdir(exist_ok=True)
            chunk = 512 * 1024
            prefix = tmp.read_bytes() if tmp.exists() else b''
            def segment(index):
                start, end = index * chunk, min(size, (index + 1) * chunk) - 1
                part = parts / str(index)
                if not part.exists() and start < len(prefix): part.write_bytes(prefix[start:end+1])
                for attempt in range(20):
                    count = part.stat().st_size if part.exists() else 0
                    if count == end - start + 1: return part
                    headers, download = parts / f'{index}.headers', parts / f'{index}.download'
                    result = subprocess.run(['curl', '-fLsS', '--connect-timeout', '30', '--max-time', '120', '--range', f'{start+count}-{end}', '-D', str(headers), '-o', str(download), download_url])
                    if headers.exists() and download.exists() and f'content-range: bytes {start+count}-{end}/{size}' in headers.read_text().lower():
                        with part.open('ab') as target: target.write(download.read_bytes())
                    elif result.returncode == 0:
                        # Some source hosts ignore Range and return the whole
                        # archive. Accept that only after full hash validation.
                        data = download.read_bytes()
                        if len(data) != size or hashlib.sha256(data).hexdigest() != expected:
                            raise ValueError('Server ignored Range without returning the verified complete source')
                        part.write_bytes(data[start:end+1])
                        return part
                raise ValueError('Incomplete source segment')
            with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
                chunks = list(pool.map(segment, range((size+chunk-1)//chunk)))
            with tmp.open('wb') as target:
                for part in chunks: target.write(part.read_bytes())
        else:
            direct = ['--noproxy', '*', '-4'] if url.startswith('https://static.crates.io/') and not crate_mirror else []
            subprocess.run(['curl', *direct, '-fL', '--retry', '8', '--retry-all-errors', '--connect-timeout', '30', '--max-time', '1800', '-C', '-', '-sS', '-o', str(tmp), download_url], check=True)
        if hashlib.sha256(tmp.read_bytes()).hexdigest() != expected: raise ValueError(f'Checksum mismatch: {name}')
        tmp.replace(dest)
    return url, name, dest

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('archive', type=Path)
    p.add_argument('source', type=Path)
    p.add_argument('--cache', type=Path, default=Path('/tmp/under-sea-hermes-lock/inputs'))
    p.add_argument('--output', type=Path, default=Path('modules/under-sea/packages/hermes-lock.scm'))
    p.add_argument('--module', default='hermes-lock', help='Generated module name under (under-sea packages ...)')
    p.add_argument('--crate-mirror', help='Optional crates source mirror; Cargo.lock hashes remain authoritative')
    p.add_argument('--extra', action='append', default=[], help='Root Hermes extra (repeatable; follows nested extras)')
    p.add_argument('--inventory', type=Path, help='Write selected source inventory without downloading or replacing the lock')
    p.add_argument('--source-overrides', type=Path, help='Reviewed JSON source origins for wheel-only lock entries')
    p.add_argument('--rust-git-sources', type=Path, help='Reviewed exact Cargo Git identities and source archive hashes')
    p.add_argument('--cargo-lock-overrides', type=Path,
                   help='JSON {package-name: Cargo.lock path} for sdists that ship no lock')
    p.add_argument('--python-components', type=Path, help='Reviewed name/version/recipe JSON for independent source-built Python components')
    p.add_argument('--source-audit', action='append', type=Path, default=[],
                   help='Source payload audit JSON (repeatable); reject audited native libraries without source')
    p.add_argument('--record-unbuildable', action='store_true',
                   help='Record audited source-unavailable components explicitly while locking the remaining sources; does not produce a complete runtime')
    args = p.parse_args(); args.cache.mkdir(parents=True, exist_ok=True)
    with tarfile.open(args.archive) as tar:
        root = tar.getmembers()[0].name.split('/')[0]
        for file in ('uv.lock', 'pyproject.toml'):
            if tar.extractfile(root+'/'+file).read() != (args.source/file).read_bytes(): raise ValueError('Source/archive mismatch')
    lock = tomllib.loads((args.source/'uv.lock').read_text())
    packages = {}
    for package in lock['package']: packages.setdefault(package['name'], []).append(package)
    if args.source_overrides:
        for name, replacement in json.loads(args.source_overrides.read_text()).items():
            candidates = [pkg for pkg in packages.get(name, [])
                          if pkg['version'] == replacement['version']]
            if len(candidates) != 1:
                raise ValueError(f'Source override does not match locked package: {name}')
            if 'sdist' in candidates[0]:
                raise ValueError(f'Refusing to override existing locked sdist: {name}')
            candidates[0]['sdist'] = {key: replacement[key] for key in ('url', 'hash', 'size')}
    def select(dep):
        candidates = [x for x in packages[dep['name']] if 'version' not in dep or x['version'] == dep['version']]
        if len(candidates) != 1: raise ValueError(f'Ambiguous dependency: {dep}')
        return candidates[0]
    selected, extras, graph = {}, {}, {}
    root_package = select({'name': 'hermes-agent'})
    unknown = set(args.extra) - set(root_package.get('optional-dependencies', {}))
    if unknown: raise ValueError(f'Unknown Hermes extras: {sorted(unknown)}')
    queue = [({'name': 'hermes-agent'}, args.extra)]
    while queue:
        dependency, wanted = queue.pop(0)
        name = dependency['name']
        pkg = select(dependency)
        if name in selected and selected[name]['version'] != pkg['version']:
            raise ValueError(f'Conflicting versions in selected runtime: {name}')
        old = extras.setdefault(name, set()); added = set(wanted) - old
        if name in selected and not added: continue
        old.update(wanted); selected[name] = pkg
        deps = list(pkg.get('dependencies', []))
        for extra in sorted(old): deps += pkg.get('optional-dependencies', {}).get(extra, [])
        graph[name] = []
        for dep in deps:
            if marker(dep.get('marker', 'True')):
                select(dep)
                if dep['name'] != name: graph[name].append(dep['name'])
                queue.append((dep, dep.get('extra', [])))
    order, active, runtime_cycles = [], set(), []
    def visit(name):
        if name in order: return
        # Runtime SDKs may mutually depend on one another (for example Vercel).
        # Wheels are built without dependency resolution; install each source
        # once and retain the cycle in the inventory for build-backend review.
        if name in active:
            runtime_cycles.append(name)
            return
        active.add(name)
        for dep in graph[name]: visit(dep)
        active.remove(name); order.append(name)
    visit('hermes-agent'); order.remove('hermes-agent')
    components = json.loads(args.python_components.read_text()) if args.python_components else {}
    for name, component in components.items():
        if name not in selected or selected[name]['version'] != component['version']:
            raise ValueError('Independent component does not match selected lock: ' + name)
        if not component.get('recipe') or not component.get('module'):
            raise ValueError('Independent component lacks explicit Guix recipe: ' + name)
        for key in ('module', 'recipe', 'output'):
            value = component.get(key, 'out' if key == 'output' else '')
            if not value or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789-' for c in value):
                raise ValueError('Invalid independent component ' + key + ': ' + name)
    source_order = [name for name in order if name not in components]
    source_audits = [json.loads(path.read_text()) for path in args.source_audit]
    for audit in source_audits:
        name = audit['name']
        if name not in selected or selected[name]['version'] != audit['version']:
            raise ValueError('Source payload audit does not match selected lock: ' + name)
        if selected[name].get('sdist', {}).get('hash') != audit['archive_sha256']:
            raise ValueError('Source payload audit archive identity mismatch: ' + name)
    unbuildable = [audit for audit in source_audits
                   if audit.get('native_payloads') and not audit.get('c_cpp_sources')]
    if args.record_unbuildable and not unbuildable:
        raise ValueError('No audited source-unavailable component to record')
    if args.inventory:
        args.inventory.write_text(json.dumps({'extras': sorted(extras['hermes-agent']),
            'independent_python_components': components,
            'source_payload_audits': source_audits,
            'source_unavailable_components': unbuildable,
            'runtime_cycle_nodes': sorted(set(runtime_cycles)),
            'packages': [{'name': name, 'version': selected[name]['version'],
                          'extras': sorted(extras[name]), 'sdist': selected[name].get('sdist'),
                          'dependencies': sorted(set(graph[name]))}
                         for name in order]}, indent=2) + '\n')
        print(f'Wrote {args.inventory}: {len(order)} packages; '
              f'{len(components)} independent recipe providers; '
              f'{sum("sdist" not in selected[name] for name in source_order)} lack a source provider '
              '(archive payload audits and build completion remain separate)', flush=True)
        return
    for audit in unbuildable:
        if not args.record_unbuildable:
            raise ValueError('Cannot generate a complete source lock: audited native engine '
                             'sources absent for ' + audit['name'])
    unavailable_names = {audit['name'] for audit in unbuildable}
    source_order = [name for name in source_order if name not in unavailable_names]
    inputs = []
    for name in source_order:
        if 'sdist' not in selected[name]:
            raise ValueError(f'No locked source archive for {name} {selected[name]["version"]}; source-build recipe required')
        sdist = selected[name]['sdist']; url = sdist['url']
        inputs.append((url, url.rsplit('/',1)[1], sdist['hash'].removeprefix('sha256:'), sdist['size']))
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool: sources = list(pool.map(lambda x: fetch(x,args.cache), inputs))
    crates, git_sources = {}, {}
    git_origins = json.loads(args.rust_git_sources.read_text()) if args.rust_git_sources else {}
    cargo_overrides = json.loads(args.cargo_lock_overrides.read_text()) if args.cargo_lock_overrides else {}
    for pkgname, (_, name, path) in zip(source_order, sources):
        with tarfile.open(path) as tar:
            root = tar.getmembers()[0].name.split('/')[0]
            try:
                project = tomllib.loads(tar.extractfile(root + '/pyproject.toml').read().decode())
            except KeyError:
                continue
            build_system = project.get('build-system', {})
            backend = build_system.get('build-backend', '')
            if 'maturin' not in backend and not any('setuptools-rust' in req for req in build_system.get('requires', [])):
                # NumPy's vendored Meson contains synthetic Cargo.lock test
                # fixtures; they are not part of its native build closure.
                continue
            if pkgname in cargo_overrides:
                locks = [tomllib.loads(Path(cargo_overrides[pkgname]).read_text())]
            else:
                locks = [tomllib.loads(tar.extractfile(member).read().decode())
                         for member in tar.getmembers()
                         if member.name.endswith('/Cargo.lock')]
                if not locks:
                    raise ValueError(
                        f'{pkgname} builds a Rust extension but ships no Cargo.lock; '
                        'supply one via --cargo-lock-overrides')
            for data in locks:
                # Cargo also inspects declared but version-incompatible
                # Git patches during offline metadata resolution.
                for crate in data['package'] + data.get('patch', {}).get('unused', []):
                    if 'source' not in crate: continue
                    # These crates distribute precompiled protoc binaries.
                    # The builder replaces them with Guix's source-built protoc.
                    if crate['name'].startswith('protoc-bin-vendored'): continue
                    if not crate['source'].startswith('registry+'):
                        identity = crate['source']
                        if identity not in git_origins:
                            raise ValueError(f'Unpinned Rust Git source in {name}: {identity}')
                        git_sources[identity] = git_origins[identity]
                        continue
                    key = (crate['name'], crate['version'])
                    if key in crates and crates[key] != crate['checksum']: raise ValueError('Conflicting crate checksum')
                    crates[key] = crate['checksum']
    crate_inputs = [(f'https://static.crates.io/crates/{name}/{name}-{ver}.crate', f'{name}-{ver}.crate', checksum, None) for (name,ver),checksum in sorted(crates.items())]
    print(f'{len(sources)} Python sources; {len(crates)} Rust crates', flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=24) as pool: crate_sources = list(pool.map(lambda x: fetch(x,args.cache,args.crate_mirror), crate_inputs))
    git_archives = {identity: fetch((item['url'], item['file-name'], item['sha256'], None), args.cache)
                    for identity, item in sorted(git_sources.items())}
    version = tomllib.loads((args.source/'pyproject.toml').read_text())['project']['version']
    tag = root.removeprefix('hermes-agent-')
    archive_origin = origin(f'https://codeload.github.com/NousResearch/hermes-agent/tar.gz/refs/tags/v{tag}', args.archive.name, args.archive)
    if not args.module or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789-' for c in args.module):
        raise ValueError('Invalid Scheme module name')
    output = [';;; Generated by scripts/lock-hermes.py; source inputs only.', f'(define-module (under-sea packages {args.module})', '  #:use-module (guix packages)', '  #:use-module (guix download)', '  #:use-module (guix base16))', f'(define-public %hermes-version {scheme(version)})', f'(define-public %hermes-release {scheme(tag)})', f'(define-public %hermes-source {archive_origin})', '(define-public %hermes-python-sources\n  (list']
    for pkgname,(url,name,path) in zip(source_order,sources):
        output.append(f'    (list {scheme(pkgname)} {scheme(selected[pkgname]["version"])} {origin(url,name,path)})')
    output += ['  ))', '(define-public %hermes-python-component-requirements\n  (list']
    for name, component in sorted(components.items()):
        output.append('    (list ' + ' '.join(scheme(value) for value in
                      (name, component['version'], component['module'], component['recipe'],
                       component.get('output', 'out'))) + ')')
    output += ['  ))', '(define-public %hermes-source-unavailable-components\n  (list']
    for audit in unbuildable:
        output.append('    (list ' + ' '.join(scheme(value) for value in
                      (audit['name'], audit['version'], audit['archive_sha256'],
                       'Native engine source absent; runtime remains incomplete')) + ')')
    output += ['  ))', '(define-public %hermes-crate-sources\n  (list']
    for (key,checksum),(url,name,path) in zip(sorted(crates.items()),crate_sources):
        output.append(f'    (list {scheme(key[0]+"-"+key[1])} {scheme(checksum)} {origin(url,name,path)})')
    output += ['  ))', '(define-public %hermes-git-sources\n  (list']
    for identity, (url, name, path) in git_archives.items():
        output.append(f'    (list {scheme(identity)} {scheme(git_sources[identity]["name"])} {origin(url,name,path)})')
    output += ['  ))', '']
    temporary = args.output.with_suffix(args.output.suffix + '.tmp')
    temporary.write_text('\n'.join(output)); temporary.replace(args.output)
    print(f'Wrote {args.output}', flush=True)
if __name__ == '__main__': main()
