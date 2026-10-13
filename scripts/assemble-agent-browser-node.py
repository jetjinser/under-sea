"""Assemble exact peer-aware dashboard modules without npm install scripts."""
import argparse
import hashlib
import json
from pathlib import Path
import tarfile
import shutil
import re
import yaml

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('inventory', type=Path)
parser.add_argument('archives', type=Path)
parser.add_argument('lock', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--providers', type=Path, required=True,
                    help='JSON map of name@version to complete source-built package directories')
parser.add_argument('--build-source-removals', type=Path,
                    help='Audited exact archive paths removed only from build-time source inputs')
parser.add_argument('--archive-paths', type=Path,
                    help='Guix identity<TAB>store archive input paths, replacing temporary audit locations')
parser.add_argument('--workspace-source', type=Path,
                    help='Authored source tree for workspace-aware build inventories')
parser.add_argument('--lock-format', choices=('pnpm', 'yarn-v1', 'npm'), default='pnpm')
parser.add_argument('--npm-peer-audit', type=Path,
                    help='Verified exact npm peer ranges and bindings for this lock')
parser.add_argument('--peer-bindings', type=Path,
                    help='Reviewed exact Yarn peer package identities')
parser.add_argument('--yarn-peer-audit', type=Path,
                    help='Authenticated semver proof for exact Yarn peer bindings')
parser.add_argument('--compose-provider', action='append', default=[],
                    help='Copy source implementation and attach its locked dependencies')
parser.add_argument('--optional-replacements', type=Path,
                    help='Audited optional prebuilds replaced by a provider local build')
parser.add_argument('--package-dir-name', choices=('package', 'basename'), default='package',
                    help='Directory name for each extracted package under .sources')
args = parser.parse_args()
inventory = json.loads(args.inventory.read_text())
archives = json.loads(args.archives.read_text())
providers = json.loads(args.providers.read_text())
removals = (json.loads(args.build_source_removals.read_text())
            if args.build_source_removals else {})
digest = hashlib.sha256(args.lock.read_bytes()).hexdigest()
hash_field = {'yarn-v1': 'yarn_lock_sha256', 'npm': 'npm_lock_sha256',
              'pnpm': 'pnpm_lock_sha256'}[args.lock_format]
if digest != inventory[hash_field] or digest != archives[hash_field]:
    raise ValueError('Source lock, inventory and archive audit do not match')
lock = yaml.safe_load(args.lock.read_text()) if args.lock_format == 'pnpm' else None
if args.lock_format == 'npm':
    if not args.npm_peer_audit:
        raise ValueError('npm assembly requires verified peer metadata')
    peer_audit = json.loads(args.npm_peer_audit.read_text())
    if peer_audit['npm_lock_sha256'] != digest:
        raise ValueError('npm peer audit lock mismatch')
    actual = {(e['identity'], e['name'], e['range'], e['selected'], e['version'])
              for e in peer_audit['peer_bindings']}
    expected = {(identity, name, constraint, item['dependencies'][name],
                 inventory['snapshots'][item['dependencies'][name]]['version'])
                for identity, item in inventory['snapshots'].items()
                for name, constraint in item.get('authored_peer_constraints', {}).items()
                if name in item['dependencies']}
    if actual != expected:
        raise ValueError('npm peer audit does not cover exact selected graph')
records = {item['identity']: item for item in archives['archives']}
fixed_paths = set()
if args.archive_paths:
    for line in args.archive_paths.read_text().splitlines():
        identity, path = line.split('\t')
        if identity in fixed_paths or identity not in records or not Path(path).is_absolute():
            raise ValueError('Unexpected fixed archive input: ' + identity)
        fixed_paths.add(identity)
        records[identity]['archive'] = path
snapshots = inventory['snapshots']
composed = set(args.compose_provider)
replacements = json.loads(args.optional_replacements.read_text()) if args.optional_replacements else {}
if not composed.issubset(providers):
    raise ValueError('Composed implementation lacks source provider')
for identity, replacement in replacements.items():
    parent = replacement['provider']
    resource = Path(replacement['required_provider_resource'])
    if (parent not in composed or not replacement.get('reason') or resource.is_absolute()
            or '..' in resource.parts or not (Path(providers[parent]) / resource).is_file()):
        raise ValueError('Optional replacement requires audited source-built resource: ' + identity)
    for snapshot_name, snapshot in snapshots.items():
        for name, dependency in snapshot['dependencies'].items():
            target = dependency['identity'] if isinstance(dependency, dict) else dependency
            if target.split('(', 1)[0] != identity:
                continue
            optional = (dependency.get('group') == 'optionalDependencies' if isinstance(dependency, dict)
                        else name in (lock['snapshots'][snapshot_name].get('optionalDependencies', {})
                                      if lock and 'snapshots' in lock else
                                      snapshot.get('optional_dependency_names', [])))
            if not optional:
                raise ValueError('Cannot replace a required dependency: ' + identity)

def supported(values, target):
    positive = [value for value in values if not value.startswith('!')]
    return '!' + target not in values and (not positive or target in positive)

def available(identity):
    item = snapshots[identity]
    record = records.get(item['name'] + '@' + item['version'], {})
    if item['name'] + '@' + item['version'] in replacements:
        return False
    # Native musl packages do not consistently declare libc in registry metadata.
    return all(supported(item.get(key, []) or record.get(key, []), value) for key, value in
               [('os', 'linux'), ('cpu', 'x64'), ('libc', 'glibc')]) and not (
                   item['name'].endswith('-musl') or 'linuxmusl' in item['name'])

root = args.output.resolve()
if root.exists():
    raise ValueError('Output must be a new isolated module directory')
root.mkdir(parents=True)
store = root / '.sources'
store.mkdir()
directories = {}
workspace_directories = {}
if inventory.get('workspaces'):
    if not args.workspace_source:
        raise ValueError('Workspace inventory requires an explicit authored source tree')
    if hashlib.sha256((args.workspace_source / 'pnpm-lock.yaml').read_bytes()).hexdigest() != digest:
        raise ValueError('Workspace source lock differs from authenticated inventory')
    for identity in inventory['workspaces']:
        relative = Path(identity)
        if relative.is_absolute() or '..' in relative.parts:
            raise ValueError('Unsafe workspace path: ' + identity)
        source = args.workspace_source / relative
        target = root / '.workspaces' / relative
        shutil.copytree(source, target, symlinks=True,
                        ignore=shutil.ignore_patterns('node_modules', '.git'))
        workspace_directories[identity] = target
for identity, item in snapshots.items():
    if not available(identity):
        continue
    base = item['name'] + '@' + item['version']
    record = records[base]
    parent = store / hashlib.sha256(identity.encode()).hexdigest()
    parent.mkdir()
    target = parent / ('package' if args.package_dir_name == 'package'
                       else item['name'].rsplit('/', 1)[-1])
    if base in providers:
        provider = Path(providers[base]).resolve()
        metadata = json.loads((provider / 'package.json').read_text())
        expected_version = item['version']
        source_url = item.get('resolution', {}).get('tarball')
        if source_url:
            provenance = json.loads((provider / 'guix-source-identity.json').read_text())
            if provenance['url'] != source_url:
                raise ValueError('Source provider Git identity mismatch: ' + base)
            expected_version = provenance['version']
        if metadata['name'] != item['name'] or metadata['version'] != expected_version:
            raise ValueError('Source provider metadata mismatch: ' + base)
        if base in composed:
            # Recreate dependency links from this lock, rather than carrying a
            # provider's separate node_modules layout into the consumer graph.
            shutil.copytree(provider, target, symlinks=True,
                            ignore=lambda directory, names:
                            ['node_modules'] if Path(directory) == provider
                            and 'node_modules' in names else [])
            # Guix directories retain read-only modes through copytree. Only
            # our new package root needs writing for the dependency directory.
            target.chmod(target.stat().st_mode | 0o200)
        else:
            target.symlink_to(provider, target_is_directory=True)
    else:
        if args.archive_paths and base not in fixed_paths:
            raise ValueError('Missing fixed Guix source input: ' + base)
        removed = set(removals.get(base, {}).get('archive_paths', []))
        if removed and (removals[base].get('archive_sha256') != record['sha256'] or
                        not removals[base].get('reason') or
                        not removed.issubset(set(record.get('native_payloads', [])))):
            raise ValueError('Removal must identify audited native build-only files: ' + base)
        if set(record.get('native_payloads', [])) - removed:
            raise ValueError('Complete source provider required for native/WASM package: ' + base)
        archive = Path(record['archive'])
        if hashlib.sha256(archive.read_bytes()).hexdigest() != record['sha256']:
            raise ValueError('Archive hash changed: ' + base)
        target.mkdir()
        with tarfile.open(archive) as tar:
            members = tar.getmembers()
            prefix = members[0].name.split('/')[0] + '/'
            for member in members:
                if member.name in removed:
                    continue
                if member.name.rstrip('/') == prefix.rstrip('/'):
                    continue
                if not member.name.startswith(prefix):
                    raise ValueError('Unexpected archive root: ' + base)
                member.name = member.name[len(prefix):]
                tar.extract(member, target, filter='data')
    directories[identity] = target

def link(directory, name, target):
    path = directory / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.symlink_to(target, target_is_directory=True)

for identity, target in directories.items():
    # Provider directories are immutable store paths. Their own dependency closure
    # must already be complete; do not write dependency links into Guix store.
    base = snapshots[identity]['name'] + '@' + snapshots[identity]['version']
    if base in providers and base not in composed:
        continue
    if lock is None:
        optional = snapshots[identity].get('optional_dependency_names', [])
    else:
        locked_snapshot = (lock['snapshots'][identity] if 'snapshots' in lock
                           else lock['packages']['/' + identity])
        optional = locked_snapshot.get('optionalDependencies', {})
    for name, dependency in snapshots[identity]['dependencies'].items():
        if isinstance(dependency, dict):
            if dependency['kind'] != 'registry':
                raise ValueError('Registry snapshot unexpectedly links a workspace')
            dependency = dependency['identity']
        if dependency not in directories:
            if name in optional:
                continue
            raise ValueError('Required dependency unavailable: ' + identity + ' -> ' + dependency)
        link(target / 'node_modules', name, directories[dependency])
for identity, target in workspace_directories.items():
    for name, dependency in inventory['workspaces'][identity]['dependencies'].items():
        candidates = workspace_directories if dependency['kind'] == 'workspace' else directories
        destination = candidates.get(dependency['identity'])
        if destination is None:
            if dependency['group'] == 'optionalDependencies':
                continue
            raise ValueError('Required workspace dependency unavailable: ' + identity + ' -> ' + name)
        link(target / 'node_modules', name, destination)
if args.lock_format == 'yarn-v1':
    peer_bindings = json.loads(args.peer_bindings.read_text()) if args.peer_bindings else {}
    yarn_proofs = set()
    if args.yarn_peer_audit:
        proof = json.loads(args.yarn_peer_audit.read_text())
        if not args.peer_bindings or proof['yarn_lock_sha256'] != digest:
            raise ValueError('Yarn peer audit lock mismatch')
        for field, path in [('inventory', args.inventory), ('archives', args.archives),
                            ('bindings', args.peer_bindings)]:
            if proof[field + '_sha256'] != hashlib.sha256(path.read_bytes()).hexdigest():
                raise ValueError('Yarn peer audit input mismatch: ' + field)
        yarn_proofs = {(p['identity'], p['name'], p['range'], p['selected'], p['version'])
                       for p in proof['peer_bindings']}
    for identity, target in directories.items():
        item = snapshots[identity]
        record = records[item['name'] + '@' + item['version']]
        for name, constraint in record.get('peer_dependencies', {}).items():
            selected = peer_bindings.get(identity, {}).get(name)
            if not selected:
                if record.get('peer_dependencies_meta', {}).get(name, {}).get('optional'):
                    continue
                raise ValueError('Required Yarn peer binding missing: ' + identity + ' -> ' + name)
            if selected not in directories or snapshots[selected]['name'] != name:
                raise ValueError('Invalid reviewed peer identity: ' + selected)
            version = snapshots[selected]['version']
            if args.yarn_peer_audit:
                if (identity, name, constraint, selected, version) not in yarn_proofs:
                    raise ValueError('Missing exact Yarn semver proof: ' + identity + ' -> ' + name)
            elif constraint != '*':
                minimum = re.fullmatch(r'\^(\d+)(?:\.(\d+))?(?:\.(\d+))?', constraint)
                if not minimum or not re.fullmatch(r'\d+\.\d+\.\d+', version):
                    raise ValueError('Peer range needs explicit supported validation: ' + constraint)
                floor = tuple(int(v or 0) for v in minimum.groups())
                actual = tuple(map(int, version.split('.')))
                if floor[0] == 0 or actual[0] != floor[0] or actual < floor:
                    raise ValueError('Peer range mismatch: ' + identity + ' -> ' + selected)
            if name not in item['dependencies']:
                link(target / 'node_modules', name, directories[selected])
for name, identity in inventory.get('root_aliases', {}).items():
    if identity not in directories:
        raise ValueError('Required authored root alias unavailable: ' + identity)
    link(root, name, directories[identity])
for name, identity in inventory.get('root_node_modules_aliases', {}).items():
    if identity not in directories:
        raise ValueError('Required authored node_modules root alias unavailable: ' + identity)
    link(root / 'node_modules', name, directories[identity])
for name, identity in inventory.get('workspace_root_aliases', {}).items():
    if identity not in workspace_directories:
        raise ValueError('Required authored root workspace alias unavailable: ' + identity)
    link(root, name, workspace_directories[identity])
for group in ('dependencies', 'devDependencies', 'optionalDependencies'):
    for name, entry in inventory.get('root_dependencies', {}).get(group, {}).items():
        identity = name + '@' + entry['version']
        if identity not in directories and entry['version'] in directories:
            identity = entry['version']
        if identity not in directories:
            if group == 'optionalDependencies':
                continue
            raise ValueError('Required root dependency unavailable: ' + identity)
        link(root, name, directories[identity])
(root / 'guix-source-layout.json').write_text(json.dumps({
    hash_field: digest, 'lock_format': args.lock_format, 'snapshots': len(directories),
    'providers': providers, 'install_scripts_executed': False,
    'composed_providers': sorted(composed), 'optional_source_replacements': replacements,
    'reviewed_peer_bindings': peer_bindings if args.lock_format == 'yarn-v1' else {},
    'workspaces': {name: str(path) for name, path in workspace_directories.items()},
    'build_source_removals': removals,
    'functional_validation': 'deferred'}, indent=2) + '\n')
print('Assembled', len(directories), 'exact Linux/glibc peer snapshots')
