"""Lock Satori's production and declaration build closure from authored pnpm 6."""
import argparse
import hashlib
import json
from pathlib import Path
import tarfile
import yaml

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('archive', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
with tarfile.open(args.archive) as archive:
    root = archive.getmembers()[0].name.rstrip('/')
    data = archive.extractfile(root + '/pnpm-lock.yaml').read()
lock = yaml.safe_load(data)
if str(lock['lockfileVersion']) != '6.0':
    raise ValueError('Expected authored pnpm 6 source lock')
importer = lock['importers']['.']
selected = ('tsup', 'typescript', 'twrnc', 'esbuild-plugin-replace',
            '@types/node', '@types/react', '@types/opentype.js')
roots = {'dependencies': importer['dependencies'],
         'devDependencies': {name: importer['devDependencies'][name] for name in selected}}
queue = [name + '@' + item['version'] for group in roots.values() for name, item in group.items()]
snapshots = {}
while queue:
    identity = queue.pop()
    if identity in snapshots:
        continue
    source = lock['packages']['/' + identity]
    base = identity.split('(', 1)[0]
    name, version = base.rsplit('@', 1)
    integrity = source['resolution'].get('integrity')
    if not integrity:
        raise ValueError('Registry integrity missing: ' + identity)
    edges = {}
    for group in ('dependencies', 'optionalDependencies'):
        for dependency, value in source.get(group, {}).items():
            target = dependency + '@' + value
            if '/' + target not in lock['packages']:
                raise ValueError('Unresolved source dependency: ' + target)
            edges[dependency] = target
            queue.append(target)
    snapshots[identity] = {'name': name, 'version': version, 'integrity': integrity,
                          'os': source.get('os', []), 'cpu': source.get('cpu', []),
                          'libc': source.get('libc', []), 'dependencies': edges,
                          'optional_dependency_names': list(source.get('optionalDependencies', {}))}
args.output.write_text(json.dumps({
    'source': 'satori gitHead b54f510807b7f5b8503e02509a83dc3ede06d317',
    'pnpm_lock_sha256': hashlib.sha256(data).hexdigest(),
    'root_dependencies': roots, 'snapshots': snapshots,
    'scope': 'All authored runtime plus bundler, declarations and inlined twrnc build dependencies',
    'status': 'Inventory only; native tool source replacements and actual source build pending',
    'functional_validation': 'deferred'}, indent=2) + '\n')
print('Locked', len(snapshots), 'peer snapshots from authored pnpm 6')
