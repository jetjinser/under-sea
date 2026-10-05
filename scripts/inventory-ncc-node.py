"""Inventory ncc's authored build imports against its exact Yarn v1 lock."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import shlex
import tarfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('archive', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--root-selector', action='append', default=[],
                    help='Explicit authored-lock selector for an undeclared source import')
parser.add_argument('--source-label', default='@vercel/ncc 0.34.0 authored gitHead')
parser.add_argument('--scan-prefix', action='append',
                    help='Authored JavaScript build directories; defaults to src/')
parser.add_argument('--scan-file', action='append',
                    help='Additional authored JavaScript build files; defaults to scripts/build.js')
parser.add_argument('--build-root', action='append', default=[],
                    help='Additional declared build tool referenced by authored scripts/configuration')
parser.add_argument('--lock-relative', default='yarn.lock')
parser.add_argument('--manifest-relative', default='package.json')
parser.add_argument('--additional-manifest', action='append', default=[])
args = parser.parse_args()
scan_prefixes = args.scan_prefix or ['src/']
scan_files = args.scan_file or ['scripts/build.js']
with tarfile.open(args.archive) as archive:
    prefix = archive.getmembers()[0].name.split('/')[0] + '/'
    for relative in [args.lock_relative, args.manifest_relative, *args.additional_manifest]:
        if Path(relative).is_absolute() or '..' in Path(relative).parts:
            raise ValueError('Unsafe archive input path: ' + relative)
    raw = archive.extractfile(prefix + args.lock_relative).read()
    metadata = json.loads(archive.extractfile(prefix + args.manifest_relative).read())
    for relative in args.additional_manifest:
        extra = json.loads(archive.extractfile(prefix + relative).read())
        for group in ('dependencies', 'devDependencies'):
            target = metadata.setdefault(group, {})
            for name, constraint in extra.get(group, {}).items():
                if name not in metadata.get('dependencies', {}) and name not in metadata.get('devDependencies', {}):
                    target[name] = constraint
    imports = set()
    babel_short_names = set()
    workspace_names = set()
    if metadata.get('workspaces') == ['packages/*']:
        for member in archive.getmembers():
            relative = member.name.removeprefix(prefix)
            if member.isfile() and re.fullmatch(r'packages/[^/]+/package\.json', relative):
                workspace_names.add(json.loads(archive.extractfile(member).read())['name'])
    for member in archive.getmembers():
        relative = member.name.removeprefix(prefix)
        if ('/__tests__/' in relative or re.search(r'\.(?:test|spec)\.tsx?$', relative)):
            continue
        if member.isfile() and (any(relative.startswith(prefix) for prefix in scan_prefixes)
                                and relative.endswith(('.js', '.ts', '.tsx')) or relative in scan_files):
            authored_text = archive.extractfile(member).read().decode()
            imports.update(re.findall(r'\brequire(?:\.resolve)?\([\'"]([^\'"]+)[\'"]\)',
                                      authored_text))
            imports.update(re.findall(r'\b(?:from|import)\s*[\'"]([^\'"]+)[\'"]',
                                      authored_text))
            # Babel accepts plugin/preset names as strings in build options.
            # These are module inputs even when no require() appears in source.
            imports.update(re.findall(r'[\'"](@babel/(?:plugin|preset)-[^\'"]+)[\'"]',
                                      authored_text))
            babel_short_names.update(re.findall(r'[\'"]([a-z][a-z0-9-]+)[\'"]', authored_text))
builtins = {'fs', 'crypto', 'os', 'path', 'process', 'vm', 'module', 'util', 'child_process',
            'assert', 'stream', 'events', 'http', 'https', 'url', 'zlib', 'buffer',
            'tty', 'readline', 'worker_threads', 'perf_hooks', 'timers'}
names = {('/'.join(name.split('/')[:2]) if name.startswith('@') else name.split('/')[0])
         for name in imports if not name.startswith('.') and name not in builtins}
workspace_imports = sorted(names & workspace_names)
names -= workspace_names
declared = metadata.get('dependencies', {}) | metadata.get('devDependencies', {})
for short_name in babel_short_names:
    for prefix in ('babel-plugin-', 'babel-preset-'):
        if prefix + short_name in declared:
            names.add(prefix + short_name)
for name in args.build_root:
    if name not in declared:
        raise ValueError('Additional build root is not declared: ' + name)
    names.add(name)
undeclared = names - declared.keys()
names -= undeclared
entries, current, group = {}, None, None
for line in raw.decode().splitlines():
    if not line or line.startswith('#'):
        continue
    if not line.startswith(' '):
        if not line.endswith(':'):
            raise ValueError('Unsupported Yarn header')
        current = {}
        for key in next(csv.reader([line[:-1]], skipinitialspace=True)):
            if key in entries:
                raise ValueError('Duplicate Yarn selector: ' + key)
            entries[key] = current
        group = None
    elif line.startswith('    '):
        words = shlex.split(line)
        if group not in ('dependencies', 'optionalDependencies') or len(words) != 2:
            raise ValueError('Unsupported nested Yarn field')
        current.setdefault(group, {})[words[0]] = words[1]
    elif line.strip().endswith(':'):
        group = line.strip()[:-1]
    else:
        words = shlex.split(line)
        if len(words) != 2:
            raise ValueError('Unsupported Yarn scalar')
        current[words[0]] = words[1]
        group = None
queue = [(name, declared[name]) for name in sorted(names)]
explicit_roots = {}
for selector in args.root_selector:
    entry = entries[selector]
    name, constraint = selector.rsplit('@', 1)
    if name not in undeclared or name in explicit_roots:
        raise ValueError('Override must resolve exactly one undeclared import: ' + selector)
    explicit_roots[name] = selector
    queue.append((name, constraint))
snapshots = {}
selectors = {}
while queue:
    name, constraint = queue.pop()
    selector = name + '@' + constraint
    entry = entries[selector]
    identity = name + '@' + entry['version']
    selectors[selector] = identity
    if identity in snapshots:
        if snapshots[identity]['integrity'] != entry.get('integrity'):
            raise ValueError('Conflicting exact Yarn package')
        continue
    edges = {}
    for group in ('dependencies', 'optionalDependencies'):
        for dependency, value in entry.get(group, {}).items():
            target = entries[dependency + '@' + value]
            edges[dependency] = dependency + '@' + target['version']
            queue.append((dependency, value))
    if not entry.get('integrity'):
        raise ValueError('Unauthenticated Yarn source: ' + selector)
    # Yarn npm aliases keep the declared edge name, but authenticate and extract
    # the actual registry package identity (e.g. wrap-ansi-cjs -> wrap-ansi).
    package_name = constraint[4:].rsplit('@', 1)[0] if constraint.startswith('npm:') else name
    snapshots[identity] = {'name': package_name, 'version': entry['version'],
                           'declared_name': name,
                           'integrity': entry['integrity'], 'resolved': entry['resolved'],
                           'dependencies': edges,
                           'optional_dependency_names': list(entry.get('optionalDependencies', {}))}
args.output.write_text(json.dumps({
    'source': args.source_label,
    'lock_relative': args.lock_relative, 'manifest_relative': args.manifest_relative,
    'additional_manifests': args.additional_manifest,
    'authored_workspace_imports': workspace_imports,
    'scan_prefixes': scan_prefixes, 'scan_files': scan_files,
    'additional_declared_build_roots': args.build_root,
    'yarn_lock_sha256': hashlib.sha256(raw).hexdigest(),
    'root_names': sorted(names | explicit_roots.keys()),
    'explicit_undeclared_import_roots': explicit_roots,
    'root_aliases': {name: selectors[name + '@' + declared[name]] for name in names}
                   | {name: selectors[selector] for name, selector in explicit_roots.items()},
    'selectors': selectors, 'snapshots': snapshots,
    'undeclared_import_candidates': {
        name: {selector: entry['version'] for selector, entry in entries.items()
               if selector.startswith(name + '@')}
        for name in sorted(undeclared)},
    'scope': 'Literal imports of selected authored build files; dynamic imports and assets require further audit',
    'functional_validation': 'Deferred'}, indent=2) + '\n')
print('Inventoried', len(names | explicit_roots.keys()), 'build roots and', len(snapshots), 'exact Yarn packages')
