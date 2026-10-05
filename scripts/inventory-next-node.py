"""Inventory Next's authored build closure, retaining workspace and peer identities."""
import argparse
import hashlib
import json
import posixpath
import re
from pathlib import Path
import yaml

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--importer', action='append',
                    help='Additional build asset workspace, e.g. apps/bundle-analyzer')
parser.add_argument('--include-task-roots', action='store_true',
                    help='Include authored root dependencies referenced by framework build tasks')
args = parser.parse_args()
raw = (args.source / 'pnpm-lock.yaml').read_bytes()
source_metadata = json.loads((args.source / 'packages/next/package.json').read_text())
if source_metadata['name'] != 'next':
    raise ValueError('Expected authored Next source package')
lock = yaml.safe_load(raw)
if str(lock['lockfileVersion']) != '9.0':
    raise ValueError('Expected authored pnpm 9 lock')
queue = [('workspace', name) for name in ['packages/next'] + (args.importer or [])]
root_aliases, workspace_root_aliases, task_roots = {}, {}, {}
if args.include_task_roots:
    package = args.source / 'packages/next'
    files = list(package.glob('taskfile*.js')) + list((package / 'src/bundles').rglob('*.js'))
    files += [package / 'next-runtime.webpack-config.js', package / 'check-error-codes.js']
    declared = {name: entry for group in ('dependencies', 'devDependencies', 'optionalDependencies')
                for name, entry in lock['importers']['.'].get(group, {}).items()}
    own = {name for group in ('dependencies', 'devDependencies', 'optionalDependencies')
           for name in lock['importers']['packages/next'].get(group, {})}
    for file in sorted(set(files)):
        if not file.is_file():
            continue
        text = file.read_text()
        requests = re.findall(r'''(?:require|bundleRequire)(?:\.resolve)?\(\s*['"]([^'"]+)['"]''', text)
        # The authored React vendor task executes both explicit branches. Retain
        # their exact root aliases rather than guessing a hoisted React version.
        templates = re.findall(r'''require\.resolve\(\s*`([^`]+)`''', text)
        for template in templates:
            if '${channel}' in template:
                if "const channel = opts.experimental ? `experimental-builtin` : `builtin`" not in text:
                    raise ValueError('React channel branches changed; review required')
                requests.extend(template.replace('${channel}', branch)
                                for branch in ('builtin', 'experimental-builtin'))
            elif '${packageSuffix}' in template:
                if 'const packageSuffix = opts.experimental ? `-experimental` : ``' not in text:
                    raise ValueError('React package suffix branches changed; review required')
                requests.extend(template.replace('${packageSuffix}', branch)
                                for branch in ('', '-experimental'))
        for request in requests:
            name = '/'.join(request.split('/')[:2]) if request.startswith('@') else request.split('/')[0]
            if name in declared and name not in own:
                task_roots.setdefault(name, []).append(str(file.relative_to(args.source)))
    for name in sorted(task_roots):
        version = declared[name]['version']
        if version.startswith('link:'):
            target = posixpath.normpath(version[5:])
            if target not in lock['importers']:
                raise ValueError('Unresolved root task workspace: ' + target)
            workspace_root_aliases[name] = target
            queue.append(('workspace', target))
        else:
            target = name + '@' + version
            if target not in lock['snapshots'] and version in lock['snapshots']:
                target = version
            if target not in lock['snapshots']:
                raise ValueError('Unresolved root task dependency: ' + name)
            root_aliases[name] = target
            queue.append(('registry', target))
workspaces, snapshots, non_registry = {}, {}, {}
while queue:
    kind, identity = queue.pop()
    seen = workspaces if kind == 'workspace' else snapshots
    if identity in seen:
        continue
    source = lock['importers' if kind == 'workspace' else 'snapshots'][identity]
    edges = {}
    seen[identity] = {'dependencies': edges}
    for group in ('dependencies', 'devDependencies', 'optionalDependencies'):
        if kind != 'workspace' and group == 'devDependencies':
            continue
        for name, entry in source.get(group, {}).items():
            version = entry['version'] if isinstance(entry, dict) else entry
            if version.startswith('link:'):
                if kind != 'workspace':
                    raise ValueError('Unexpected linked registry dependency')
                target = posixpath.normpath(posixpath.join(identity, version[5:]))
                if target.startswith('../') or target not in lock['importers']:
                    raise ValueError('Unresolved workspace: ' + target)
                queue.append(('workspace', target))
                edges[name] = {'kind': 'workspace', 'identity': target, 'group': group}
            else:
                target = name + '@' + version
                # pnpm aliases retain the real package name in their version.
                if target not in lock['snapshots'] and version in lock['snapshots']:
                    target = version
                if target not in lock['snapshots']:
                    raise ValueError('Unresolved snapshot: ' + target)
                queue.append(('registry', target))
                edges[name] = {'kind': 'registry', 'identity': target, 'group': group}
    if kind == 'registry':
        base = identity.split('(', 1)[0]
        metadata = lock['packages'][base]
        name, version = base.split('@', 2)[1:] if base.startswith('@') else base.split('@', 1)
        if base.startswith('@'):
            name = '@' + name
        seen[identity].update(name=name, version=version,
                              resolution=metadata['resolution'],
                              integrity=metadata['resolution'].get('integrity'),
                              os=metadata.get('os', []), cpu=metadata.get('cpu', []),
                              libc=metadata.get('libc', []))
        if 'integrity' not in metadata['resolution']:
            non_registry[base] = metadata['resolution']
args.output.write_text(json.dumps({
    'source': 'next ' + source_metadata['version'] + ' authored source',
    'pnpm_lock_sha256': hashlib.sha256(raw).hexdigest(),
    'additional_build_asset_importers': args.importer or [],
    'authored_task_root_evidence': task_roots,
    'root_aliases': root_aliases, 'workspace_root_aliases': workspace_root_aliases,
    'scope': 'Next package full declared build/runtime closure and linked workspaces; '
             'includes test/storybook candidates requiring subsequent build-task classification',
    'workspaces': workspaces, 'snapshots': snapshots,
    'non_registry_sources_requiring_review': non_registry,
    'status': 'Inventory only; no source archive audit or dependency execution',
    'functional_validation': 'Deferred'}, indent=2) + '\n')
print('Inventoried', len(workspaces), 'workspaces,', len(snapshots), 'snapshots,',
      len(non_registry), 'non-registry sources')
