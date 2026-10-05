"""Rebuild ncc's full authored distribution with source-built WASM providers."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('output', type=Path)
parser.add_argument('--node', required=True)
parser.add_argument('--modules', type=Path, required=True)
args = parser.parse_args()
metadata = json.loads(Path('package.json').read_text())
if (metadata['name'], metadata['version']) != ('@vercel/ncc', '0.34.0'):
    raise ValueError('Unexpected ncc authored source identity')
if Path('node_modules').exists():
    raise ValueError('Build requires a fresh authenticated module layout')
Path('node_modules').symlink_to(args.modules, target_is_directory=True)
Path('dist/ncc/loaders').mkdir(parents=True, exist_ok=True)
builder = Path('scripts/build.js')
text = builder.read_text()
anchor = 'const minify = true;'
if text.count(anchor) != 1:
    raise ValueError('Unexpected ncc build script')
helper = '''function writeAssets(assets) {
  const base = require('path').resolve(__dirname, '../dist/ncc');
  for (const [name, asset] of Object.entries(assets)) {
    const destination = require('path').resolve(base, name);
    if (!destination.startsWith(base + require('path').sep))
      throw new Error('Unexpected emitted resource path: ' + name);
    require('fs').mkdirSync(require('path').dirname(destination), {recursive:true});
    writeFileSync(destination, asset.source);
  }
}
'''
text = text.replace(anchor, helper + anchor)
for label, variable in [('cli', 'cliAssets'), ('index', 'indexAssets'),
                        ('relocate-loader', 'relocateLoaderAssets'),
                        ('shebang-loader', 'shebangLoaderAssets'),
                        ('ts-loader', 'tsLoaderAssets'),
                        ('stringify-loader', 'stringifyLoaderAssets'),
                        ('source-map-support/register', 'sourcemapAssets')]:
    anchor = "  checkUnknownAssets('" + label + "'"
    if text.count(anchor) != 1:
        raise ValueError('Unexpected ncc asset stage: ' + label)
    text = text.replace(anchor, '  writeAssets(' + variable + ');\n' + anchor)
builder.write_text(text)
env = dict(os.environ, NODE_ENV='production', NODE_OPTIONS='--max-old-space-size=4096')
subprocess.run([args.node, 'scripts/build.js', '--no-cache'], env=env, check=True)
for name in ['index.js', 'cli.js', 'mappings.wasm', 'LICENSES.txt',
             'loaders/ts-loader.js', 'sourcemap-register.js']:
    path = Path('dist/ncc') / name
    if not path.is_file() or not path.stat().st_size:
        raise ValueError('Missing ncc generated resource: ' + name)
provider = args.output / 'lib/node_modules/@vercel/ncc'
provider.mkdir(parents=True)
shutil.copytree('dist', provider / 'dist')
shutil.copyfile('package.json', provider / 'package.json')
shutil.copyfile('LICENSE', provider / 'LICENSE')
bin_dir = args.output / 'bin'
bin_dir.mkdir()
entry = bin_dir / 'ncc'
entry.write_text('#!' + args.node + '\nrequire(' + json.dumps(str(provider / 'dist/ncc/cli.js')) + ');\n')
entry.chmod(0o755)
(provider / 'guix-source-layout.json').write_text(json.dumps({
    'modules': str(args.modules), 'build_script': 'Authored build with complete asset installation',
    'functional_validation': 'Deferred'}, indent=2) + '\n')
