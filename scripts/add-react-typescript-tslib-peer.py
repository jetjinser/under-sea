"""Add the audited tslib peer required by React's authored Hooks bundle."""
import argparse
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('inventory', type=Path)
parser.add_argument('archives', type=Path)
parser.add_argument('peer_audit', type=Path)
parser.add_argument('--source-archives', type=Path, required=True,
                    help='Authenticated repository Rollup source archive audit')
parser.add_argument('--archive', type=Path, required=True,
                    help='Cached tslib 2.8.1 archive to pass as a fixed Guix input')
args = parser.parse_args()

inventory = json.loads(args.inventory.read_text())
archives = json.loads(args.archives.read_text())
peer_audit = json.loads(args.peer_audit.read_text())
source_archives = json.loads(args.source_archives.read_text())
identity = 'tslib@2.8.1'
if identity in inventory['snapshots'] or identity in inventory['root_aliases']:
    raise ValueError('tslib supplemental peer already exists')
source = next(row for row in source_archives['archives']
              if row['identity'] == identity)
inventory['root_aliases']['tslib'] = identity
inventory.setdefault('root_node_modules_aliases', {})['tslib'] = identity
inventory['snapshots'][identity] = {
    'name': 'tslib', 'version': '2.8.1', 'declared_name': 'tslib',
    'resolved': source['url'], 'dependencies': {},
    'optional_dependency_names': [],
    'supplemental_reason': (
        '@rollup/plugin-typescript 12.1.2 unconditionally preflights tslib '
        'while bundling React Hooks. This optional peer is absent from the '
        'React Yarn roots; the exact source is fixed by the repository '
        'Rollup 4.34.9 lock.')}
source = dict(source)
source['archive'] = str(args.archive)
source['supplemental_reason'] = inventory['snapshots'][identity]['supplemental_reason']
archives['archives'].append(source)
args.archive.resolve(strict=True)
args.inventory.write_text(json.dumps(inventory, indent=2) + '\n')
args.archives.write_text(json.dumps(archives, indent=2) + '\n')
peer_audit['inventory_sha256'] = hashlib.sha256(args.inventory.read_bytes()).hexdigest()
peer_audit['archives_sha256'] = hashlib.sha256(args.archives.read_bytes()).hexdigest()
args.peer_audit.write_text(json.dumps(peer_audit, indent=2) + '\n')
print('Added fixed tslib@2.8.1 supplemental optional peer source')
