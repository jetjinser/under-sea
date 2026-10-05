"""Recover verbatim authored OG TypeScript from authenticated source maps."""
import argparse
import base64
import hashlib
import json
from pathlib import Path, PurePosixPath
import tarfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('archive', type=Path)
parser.add_argument('metadata', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
metadata = json.loads(args.metadata.read_text())
if (metadata['name'], metadata['version']) != ('@vercel/og', '0.7.2'):
    raise ValueError('Unexpected OG release')
integrity = metadata['dist']['integrity']
if not integrity.startswith('sha512-') or ' ' in integrity:
    raise ValueError('Expected exact SHA512 release integrity')
if hashlib.sha512(args.archive.read_bytes()).digest() != base64.b64decode(integrity[7:], validate=True):
    raise ValueError('Release archive integrity mismatch')
sources = {}
with tarfile.open(args.archive) as archive:
    for variant in ('edge', 'node'):
        mapping = json.load(archive.extractfile(f'package/dist/index.{variant}.js.map'))
        if len(mapping['sources']) != len(mapping['sourcesContent']):
            raise ValueError('Incomplete source map')
        for name, content in zip(mapping['sources'], mapping['sourcesContent']):
            if not name.startswith('../src/'):
                continue
            relative = PurePosixPath(name[3:])
            if '..' in relative.parts or relative.is_absolute() or not content:
                raise ValueError('Invalid authored source entry: ' + name)
            if name in sources and sources[name] != content:
                raise ValueError('Edge/Node authored source mismatch: ' + name)
            sources[name] = content
    expected = {'../src/index.edge.ts', '../src/index.node.ts',
                '../src/emoji/index.ts', '../src/language/index.ts',
                '../src/og.ts', '../src/figma/index.tsx'}
    if set(sources) != expected:
        raise ValueError('Authored source inventory changed')
    if args.output.exists():
        raise ValueError('Recovery output must be a fresh directory')
    args.output.mkdir(parents=True)
    for name, content in sources.items():
        target = args.output / name[3:]
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)
    for member in archive.getmembers():
        if member.isfile() and (member.name in ('package/LICENSE', 'package/package.json')
                                or member.name.startswith('package/dist/') and member.name.endswith('.d.ts')):
            relative = PurePosixPath(member.name[len('package/'):])
            if '..' in relative.parts:
                raise ValueError('Invalid authored declaration path')
            target = args.output / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.extractfile(member).read())
provenance = {
    'release': '@vercel/og@0.7.2', 'gitHead': metadata['gitHead'],
    'archive_sha256': hashlib.sha256(args.archive.read_bytes()).hexdigest(),
    'integrity': integrity,
    'source_origin': 'Verbatim first-party TypeScript sourcesContent in official release source maps',
    'sources': {name: hashlib.sha256(content.encode()).hexdigest() for name, content in sources.items()},
    'compiled_js_or_wasm_copied': False,
    'remaining': ['Build against exact satori and source-built resvg/Yoga providers',
                  'Default Noto font resource provenance/license',
                  'Next bundle integration'],
    'functional_validation': 'deferred'}
(args.output / 'guix-source-provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
print('Recovered', len(sources), 'verbatim authored TypeScript sources; no compiled JS/WASM copied')
