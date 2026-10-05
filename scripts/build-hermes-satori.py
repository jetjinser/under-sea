"""Build both full Satori variants using its authored tsup configuration."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('output', type=Path)
parser.add_argument('--node', required=True)
parser.add_argument('--esbuild', required=True)
parser.add_argument('--modules', type=Path, required=True)
args = parser.parse_args()
metadata = json.loads(Path('package.json').read_text())
if metadata['name'] != 'satori' or metadata['version'] != '0.0.0-development':
    raise ValueError('Unexpected authored Satori manifest')
if Path('node_modules').exists():
    raise ValueError('Source tree must not have uncontrolled node_modules')
Path('node_modules').symlink_to(args.modules.resolve(), target_is_directory=True)
env = os.environ.copy()
env['NODE_ENV'] = 'production'
env['ESBUILD_BINARY_PATH'] = args.esbuild
env.pop('WASM', None)
command = [args.node, 'node_modules/tsup/dist/cli-default.js']
subprocess.run(command, env=env, check=True)
env['WASM'] = '1'
subprocess.run(command, env=env, check=True)
required = ('index.js', 'index.cjs', 'index.wasm.js', 'index.wasm.cjs',
            'index.d.ts', 'index.d.cts')
for name in required:
    path = Path('dist') / name
    if not path.is_file() or not path.stat().st_size:
        raise ValueError('Missing Satori production output: ' + name)
provider = args.output / 'lib/node_modules/satori'
provider.mkdir(parents=True)
shutil.copytree('dist', provider / 'dist')
shutil.copyfile('LICENSE', provider / 'LICENSE')
metadata['version'] = '0.15.2'
(provider / 'package.json').write_text(json.dumps(metadata, indent=2) + '\n')
# Keep the exact source build's dependency graph until the published-runtime
# graph is supplied and integrated separately; do not flatten peer identities.
(provider / 'node_modules').symlink_to(args.modules.resolve(), target_is_directory=True)
print('Built Satori default/WASM ESM/CJS and declarations with authored transforms')
