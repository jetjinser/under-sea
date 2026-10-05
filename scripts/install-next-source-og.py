"""Install source-built OG resources using the audited Next copy task layout.

This prepares an isolated Next source tree before its build, not a replacement
for building Next itself. No published JavaScript or WASM is used here.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('next_source', type=Path)
parser.add_argument('og_provider', type=Path)
parser.add_argument('satori_provider', type=Path)
args = parser.parse_args()
next_package = args.next_source / 'packages/next'
next_version = json.loads((next_package / 'package.json').read_text())['version']
# The authored copy_vercel_og tasks match in these two locked source versions.
# The additional 16.1.1 analyzer UI task remains a separate build requirement.
if next_version not in ('16.1.1', '16.0.8'):
    raise ValueError('Expected audited Next 16.1.1 or 16.0.8 source tree')
for provider, name, version in [(args.og_provider, '@vercel/og', '0.7.2'),
                               (args.satori_provider, 'satori', '0.15.2')]:
    metadata = json.loads((provider / 'package.json').read_text())
    if (metadata['name'], metadata['version']) != (name, version):
        raise ValueError('Provider identity mismatch: ' + str(provider))
target = next_package / 'src/compiled/@vercel/og'
if target.exists():
    raise ValueError('Remove the old OG payload explicitly before installation')
target.mkdir(parents=True)
dist = args.og_provider / 'dist'
required = ['index.node.js', 'index.edge.js', 'resvg.wasm', 'yoga.wasm',
            'noto-sans-v27-latin-regular.ttf']
for name in required:
    source = dist / name
    if not source.is_file() or source.stat().st_size == 0:
        raise ValueError('Missing source-built resource: ' + name)
    shutil.copy2(source, target / name)
shutil.copy2(args.og_provider / 'LICENSE', target / 'LICENSE')
shutil.copytree(args.og_provider / 'licenses', target / 'licenses')
for source in sorted(dist.rglob('*.d.ts')):
    destination = target / source.relative_to(dist)
    destination.parent.mkdir(parents=True, exist_ok=True)
    text = re.sub(r"['\"]satori['\"]", '"next/dist/compiled/@vercel/og/satori"',
                  source.read_text())
    destination.write_text(text.replace("typeof import('@resvg/resvg-wasm')", 'any'))
satori = target / 'satori'
satori.mkdir()
types = (args.satori_provider / 'dist/index.d.ts').read_text()
types = re.sub(r"import { Yoga } from ['\"]yoga-wasm-web['\"]", 'type Yoga = any', types)
(satori / 'index.d.ts').write_text(types)
shutil.copy2(args.satori_provider / 'LICENSE', satori / 'LICENSE')
metadata = {'name': '@vercel/og', 'version': '0.7.2', 'license': 'MPL-2.0',
            'type': 'module', 'main': './index.node.js',
            'exports': {'.': {'edge-light': './index.edge.js',
                              'import': './index.node.js',
                              'node': './index.node.js',
                              'default': './index.node.js'},
                        './package.json': './package.json'}}
(target / 'package.json').write_text(json.dumps(metadata, indent=2) + '\n')
artifacts = {str(p.relative_to(target)): hashlib.sha256(p.read_bytes()).hexdigest()
             for p in sorted(target.rglob('*')) if p.is_file()}
(target / 'source-providers.json').write_text(json.dumps({
    'next_version': next_version,
    'og': str(args.og_provider), 'satori': str(args.satori_provider),
    'artifacts': artifacts, 'functional_validation': 'Deferred'}, indent=2) + '\n')
