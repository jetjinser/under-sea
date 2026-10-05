"""Compile recovered OG Node/Edge sources with source-built rendering engines."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tarfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('output', type=Path)
for name in ('satori', 'resvg', 'yoga', 'font_archive', 'font_license'):
    parser.add_argument('--' + name.replace('_', '-'), type=Path, required=True)
args = parser.parse_args()
metadata = json.loads(Path('package.json').read_text())
if (metadata['name'], metadata['version']) != ('@vercel/og', '0.7.2'):
    raise ValueError('Unexpected recovered OG package')
modules = Path('node_modules')
modules.mkdir()
providers = {'satori': args.satori, '@resvg/resvg-wasm': args.resvg,
             'yoga-wasm-web': args.yoga}
for name, provider in providers.items():
    target = modules / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.symlink_to(provider.resolve(), target_is_directory=True)
output = args.output / 'lib/node_modules/@vercel/og'
dist = output / 'dist'
dist.mkdir(parents=True)
for variant in ('node', 'edge'):
    subprocess.run(['esbuild', 'src/index.' + variant + '.ts', '--bundle',
                    '--format=esm', '--platform=' + ('node' if variant == 'node' else 'browser'),
                    '--target=es2022', '--sourcemap', '--minify',
                    '--external:./resvg.wasm?module', '--external:./yoga.wasm?module',
                    '--outfile=' + str(dist / ('index.' + variant + '.js'))], check=True)
shutil.copyfile(args.resvg / 'index_bg.wasm', dist / 'resvg.wasm')
shutil.copyfile(args.yoga / 'dist/yoga.wasm', dist / 'yoga.wasm')
with tarfile.open(args.font_archive) as archive:
    font = archive.extractfile('package/dist/noto-sans-v27-latin-regular.ttf').read()
if hashlib.sha256(font).hexdigest() != 'd2a8188db7fdd567bbd94017cec0622373d47206d45281b7c501f0775cdee83a':
    raise ValueError('Original OG font resource changed')
(dist / 'noto-sans-v27-latin-regular.ttf').write_bytes(font)
for source in Path('dist').rglob('*.d.ts'):
    target = dist / source.relative_to('dist')
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
for name in ('package.json', 'LICENSE', 'guix-source-provenance.json'):
    shutil.copyfile(name, output / name)
licenses = output / 'licenses'
licenses.mkdir()
shutil.copyfile(args.font_license, licenses / 'Noto-OFL.txt')
(licenses / 'Noto-copyright.txt').write_text(
    'Copyright 2015-2021 Google LLC. All Rights Reserved.\n'
    'Noto Sans Regular 2.007; original unmodified font resource.\n')
(output / 'guix-rendering-providers.json').write_text(json.dumps({
    'source_providers': {name: str(path.resolve()) for name, path in providers.items()},
    'compiled_release_js_or_wasm_used': False,
    'font': 'Original static resource under SIL OFL 1.1',
    'functional_validation': 'deferred'}, indent=2) + '\n')
print('Built complete recovered OG Node/Edge source bundles with source WASM engines')
