"""Build authored Next browser polyfills with the locked workspace tools."""
import argparse
import hashlib
import json
from pathlib import Path
import shlex
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
args = parser.parse_args()
source = args.source.resolve()
version = json.loads((source / 'packages/next/package.json').read_text())['version']
if version not in ('16.0.8', '16.1.1'):
    raise ValueError('Expected audited Next source version')
artifacts = {}
for suffix in ('module', 'nomodule'):
    workspace = source / ('packages/next-polyfill-' + suffix)
    metadata = json.loads((workspace / 'package.json').read_text())
    if (metadata['name'], metadata['version']) != ('@next/polyfill-' + suffix, version):
        raise ValueError('Polyfill workspace identity mismatch')
    output = 'dist/polyfill-' + suffix + '.js'
    command = ['microbundle', '-i', 'src/index.js', '-o', output, '-f', 'iife',
               '--no-sourcemap', '--external', 'none', '--no-pkg-main']
    if shlex.split(metadata['scripts']['build']) != command:
        raise ValueError('Authored polyfill build command changed; review required')
    subprocess.run([str(workspace / 'node_modules/.bin/microbundle'), *command[1:]],
                   cwd=workspace, check=True)
    artifact = workspace / output
    if not artifact.is_file() or artifact.stat().st_size == 0:
        raise ValueError('Source polyfill build produced no artifact')
    artifacts[str(artifact.relative_to(source))] = hashlib.sha256(artifact.read_bytes()).hexdigest()
(source / 'guix-polyfill-artifacts.json').write_text(json.dumps({
    'next_version': version, 'artifacts': artifacts,
    'functional_validation': 'deferred'}, indent=2) + '\n')
