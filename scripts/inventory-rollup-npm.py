"""Resolve Rollup build inputs through its authored npm lock v3 layout."""
import argparse
import hashlib
import json
import re
from pathlib import Path, PurePosixPath

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('audit', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--runtime-only', action='store_true',
                    help='Only authored src/cli inputs for source bootstrap compilation')
parser.add_argument('--include-browser', action='store_true',
                    help='Include browser-specific authored release source imports')
args = parser.parse_args()
raw = (args.source / 'package-lock.json').read_bytes()
lock = json.loads(raw)
if lock['lockfileVersion'] != 3:
    raise ValueError('Expected authored npm lock v3')
packages = lock['packages']
roots = set() if args.runtime_only else set(json.loads(args.audit.read_text())['literal_build_tool_roots'])
if not args.runtime_only:
    roots.update(('rollup', 'typescript', '@types/node', 'tslib'))
manifest = json.loads((args.source / 'package.json').read_text())
declared = {**manifest.get('dependencies', {}), **manifest.get('devDependencies', {})}
# TypeScript resolves authored ambient declaration packages independently of JS imports.
if not args.runtime_only:
    roots.update(name for name in declared if name.startswith('@types/'))
entry_evidence = {}
for folder in ('src', 'cli', *(('browser/src',) if args.include_browser else ())):
    for source in sorted((args.source / folder).rglob('*.ts')):
        for request in re.findall(r'''(?:from\s+|import\s*\()[\'"]([^\'"]+)''', source.read_text()):
            if request.startswith(('.', 'node:')):
                continue
            name = '/'.join(request.split('/')[:2]) if request.startswith('@') else request.split('/')[0]
            if name in declared:
                roots.add(name)
                entry_evidence.setdefault(name, []).append(str(source.relative_to(args.source)))
if args.runtime_only:
    roots.discard('rollup')  # Self-referencing type imports do not provide bootstrap JS.

def resolve(location, name):
    base = PurePosixPath(location)
    for ancestor in (base, *base.parents):
        candidate = str(ancestor / 'node_modules' / name)
        if candidate in packages:
            return candidate
    return None

aliases = {}
for name in roots:
    target = resolve('', name)
    if target is None:
        raise ValueError('Unresolved authored build root: ' + name)
    aliases[name] = target
queue = list(aliases.values())
snapshots = {}
while queue:
    location = queue.pop()
    if location in snapshots:
        continue
    package = packages[location]
    if package.get('link') or not package.get('integrity'):
        raise ValueError('Unreviewed source identity: ' + location)
    name = package.get('name', location.rsplit('node_modules/', 1)[1])
    edges, optional = {}, set(package.get('optionalDependencies', {}))
    optional.update(name for name, entry in package.get('peerDependenciesMeta', {}).items()
                    if entry.get('optional'))
    for group in ('dependencies', 'optionalDependencies', 'peerDependencies'):
        for dependency in package.get(group, {}):
            target = resolve(location, dependency)
            if target is None:
                if dependency in optional:
                    continue
                raise ValueError('Unresolved required npm edge: ' + location + ': ' + dependency)
            edges[dependency] = target
            queue.append(target)
    snapshots[location] = {'name': name, 'version': package['version'],
        'integrity': package['integrity'], 'resolved': package.get('resolved'),
        'dependencies': edges, 'optional_dependency_names': sorted(optional),
        'os': package.get('os', []), 'cpu': package.get('cpu', []),
        'libc': package.get('libc', []), 'authored_peer_constraints': package.get('peerDependencies', {})}
args.output.write_text(json.dumps({'source': 'Rollup ' + manifest['version'] + ' authored build graph',
    'npm_lock_sha256': hashlib.sha256(raw).hexdigest(), 'root_aliases': aliases,
    'snapshots': snapshots, 'status': 'Exact authored npm layout; archive and peer range authentication pending',
    'entry_source_evidence': entry_evidence,
    'functional_validation': 'deferred'}, indent=2) + '\n')
print('Resolved', len(aliases), 'build roots and', len(snapshots), 'npm package locations')
