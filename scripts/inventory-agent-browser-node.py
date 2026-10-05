#!/usr/bin/env python3
"""Inventory the dashboard's exact pnpm snapshot closure without flattening peers."""
import argparse
import hashlib
import json
from pathlib import Path
import tarfile
import yaml

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('archive',type=Path)
parser.add_argument('source',type=Path)
parser.add_argument('--output',type=Path,default=Path('planning/hermes-agent-browser-node-inventory.json'))
args=parser.parse_args()
locked=(args.source/'pnpm-lock.yaml').read_bytes()
with tarfile.open(args.archive) as archive:
    root=archive.getmembers()[0].name.split('/')[0]
    if archive.extractfile(root+'/pnpm-lock.yaml').read()!=locked:
        raise ValueError('Archive/source pnpm lock mismatch')
lock=yaml.safe_load(locked)
if str(lock['lockfileVersion'])!='9.0':
    raise ValueError('Unsupported pnpm lock version')
importer=lock['importers']['packages/dashboard']
queue=[]
for group in ('dependencies','devDependencies','optionalDependencies'):
    for name,entry in importer.get(group,{}).items():
        queue.append(name+'@'+entry['version'])
seen={}
while queue:
    identity=queue.pop()
    if identity in seen:continue
    if identity not in lock['snapshots']:
        raise ValueError('Missing exact pnpm snapshot: '+identity)
    base=identity.split('(',1)[0]
    metadata=lock['packages'][base]
    resolution=metadata['resolution']
    if 'integrity' not in resolution:
        raise ValueError('Unreviewed non-registry source: '+base)
    name,version=base.rsplit('@',1)
    snapshot=lock['snapshots'][identity]
    edges={}
    for group in ('dependencies','optionalDependencies'):
        for dependency,dep_version in snapshot.get(group,{}).items():
            target=dependency+'@'+dep_version
            if target not in lock['snapshots']:
                raise ValueError('Unresolved dependency: '+target)
            edges[dependency]=target
            queue.append(target)
    seen[identity]={'name':name,'version':version,'integrity':resolution['integrity'],
                    'os':metadata.get('os',[]),'cpu':metadata.get('cpu',[]),
                    'libc':metadata.get('libc',[]),'dependencies':edges,
                    'requires_native_review':bool(metadata.get('os') or metadata.get('cpu'))}
args.output.write_text(json.dumps({'source':'agent-browser 0.26.0','importer':'packages/dashboard',
    'pnpm_lock_sha256':hashlib.sha256(locked).hexdigest(),
    'root_dependencies':importer,'snapshots':seen,
    'status':'Exact peer-aware closure inventoried; archive integrity, native replacement and build remain pending'},indent=2)+'\n')
print('Inventoried',len(seen),'exact snapshots;',len({(x['name'],x['version']) for x in seen.values()}),'unique archives')
