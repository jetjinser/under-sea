"""Map exact Next React aliases to authenticated source release resources."""
import argparse
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('release', type=Path)
parser.add_argument('requirements', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
release = args.release.resolve()
evidence = json.loads((release / 'react-release-artifacts.json').read_text())
requirements = json.loads(args.requirements.read_text())
if requirements['source_commit'] != '52684925368a41a0c9fbfca9016cdcbb72fc9d1e':
    raise ValueError('Unexpected Next React source requirement')
providers = {}
for alias, identity in requirements['additional_root_aliases'].items():
    base = identity.split('(', 1)[0]
    name, version = base.rsplit('@', 1)
    channel = 'oss-experimental' if '-experimental-' in version else 'oss-stable'
    relative = channel + '/' + name
    package = release / 'share/react-release' / relative
    metadata = json.loads((package / 'package.json').read_text())
    if (metadata['name'], metadata['version']) != (name, version):
        raise ValueError('React consumer identity mismatch: ' + alias)
    if evidence['identities'].get(relative) != version:
        raise ValueError('Source release evidence missing: ' + relative)
    prefix = relative + '/'
    files = {p: digest for p, digest in evidence['artifacts'].items() if p.startswith(prefix)}
    if not files:
        raise ValueError('No authenticated source release artifacts: ' + relative)
    for path, digest in files.items():
        resource = release / 'share/react-release' / path
        if hashlib.sha256(resource.read_bytes()).hexdigest() != digest:
            raise ValueError('Source release artifact changed: ' + path)
    if base in providers and providers[base] != str(package):
        raise ValueError('Conflicting source provider: ' + base)
    providers[base] = str(package)
args.output.write_text(json.dumps(providers, indent=2) + '\n')
print('Mapped', len(providers), 'exact source React providers')
