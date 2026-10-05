#!/usr/bin/env python3
"""Generate Codex SDK declarations using its locked TypeScript/type sources."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('archives', type=Path)
parser.add_argument('work', type=Path)
parser.add_argument('--node', default='node')
parser.add_argument('--codex-bin', type=Path)
parser.add_argument('--esbuild', type=Path)
parser.add_argument('--install-prefix', type=Path)
parser.add_argument('--version')
args = parser.parse_args()
if args.install_prefix and (not args.esbuild or not args.version):
    raise ValueError('Installation requires JavaScript compilation and release version')
lock = (args.source.parent.parent / 'pnpm-lock.yaml').read_text()
args.work.mkdir(parents=True, exist_ok=False)
shutil.copytree(args.source / 'src', args.work / 'src')
# The upstream tsup build bundles declarations.  Here they remain separate,
# so relative ESM imports need explicit extensions for NodeNext consumers.
# Apply this to source before tsc so declaration maps match installed source.
for source_file in (args.work / 'src').rglob('*.ts'):
    text = source_file.read_text()
    def esm_import(match):
        path = match['path']
        if Path(path).suffix:
            return match[0]
        return match['prefix'] + path + '.js' + match['quote']
    source_file.write_text(re.sub(
        r'''(?P<prefix>\bfrom\s+(?P<quote>["']))(?P<path>\.[^"']+)(?P=quote)''',
        esm_import, text))
if bool(args.codex_bin) != bool(args.esbuild):
    raise ValueError('JavaScript build requires both source CLI and esbuild')
if args.codex_bin:
    if not args.codex_bin.is_file() or not args.esbuild.is_file():
        raise ValueError('Missing source-built CLI or esbuild')
    execution = args.work / 'src/exec.ts'
    text = execution.read_text()
    anchor = '      const resolved = findCodexPath();'
    if text.count(anchor) != 1:
        raise ValueError('Unexpected SDK default executable resolution')
    execution.write_text(text.replace(anchor,
        '      const resolved = { executablePath: ' +
        json.dumps(str(args.codex_bin.resolve())) + ', pathDirs: [] };'))
for archive, name, version in (
    ('typescript-5.9.2', 'typescript', '5.9.2'),
    ('types-node-20.19.18', '@types/node', '20.19.18'),
    ('undici-types-6.21.0', 'undici-types', '6.21.0'),
    ('mcp-sdk-1.26.0', '@modelcontextprotocol/sdk', '1.26.0'),
    ('zod-3.25.76', 'zod', '3.25.76'),
):
    identity = name + '@' + version
    key = "'" + identity + "'" if name.startswith('@') else identity
    match = re.search(r'^  ' + re.escape(key) +
                      r':\n    resolution: \{integrity: (sha512-[^}]+)\}', lock, re.M)
    archive_path = args.archives / (archive + '.tgz')
    integrity = 'sha512-' + base64.b64encode(
        hashlib.sha512(archive_path.read_bytes()).digest()).decode()
    if not match or integrity != match[1]:
        raise ValueError('Compiler/type archive differs from official lock: ' + identity)
    staging = args.work / ('unpack-' + archive)
    staging.mkdir()
    with tarfile.open(archive_path) as source:
        source.extractall(staging, filter='data')
    entries = list(staging.iterdir())
    if len(entries) != 1 or not entries[0].is_dir():
        raise ValueError('Unexpected compiler/type archive root: ' + archive)
    package = json.loads((entries[0] / 'package.json').read_text())
    if package['name'] != name or package['version'] != version:
        raise ValueError('Compiler/type source identity mismatch: ' + archive)
    target = args.work / 'node_modules' / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(entries[0], target)
config = json.loads((args.source / 'tsconfig.json').read_text())
# Compile the SDK's public source only; test/config types are development
# consumers and are not required to emit its distribution declarations.
config['include'] = ['src']
config['compilerOptions'].update(types=['node'], emitDeclarationOnly=True,
                                outDir='types', declaration=True,
                                declarationMap=True, sourceMap=False)
(args.work / 'tsconfig.json').write_text(json.dumps(config, indent=2) + '\n')
subprocess.run([args.node, str((args.work / 'node_modules/typescript/bin/tsc').resolve()),
                '-p', str((args.work / 'tsconfig.json').resolve())], check=True)
if not (args.work / 'types/index.d.ts').is_file():
    raise ValueError('Missing SDK public declaration entry')
print('Compiled SDK public declarations with locked TypeScript 5.9.2')
if args.esbuild:
    destination = args.work / 'dist'
    shutil.copytree(args.work / 'types', destination)
    subprocess.run([str(args.esbuild.resolve()), str(args.work / 'src/index.ts'),
                    '--bundle', '--platform=node', '--format=esm', '--target=node18',
                    '--sourcemap', '--outfile=' + str(destination / 'index.js')], check=True)
    print('Compiled SDK ESM and source map with explicit source-built CLI default')
    if args.install_prefix:
        package_root = args.install_prefix / 'lib/node_modules/@openai/codex-sdk'
        package_root.mkdir(parents=True, exist_ok=False)
        shutil.copytree(destination, package_root / 'dist')
        # Declaration maps refer to ../src: ship the patched, matching source.
        shutil.copytree(args.work / 'src', package_root / 'src')
        metadata = json.loads((args.source / 'package.json').read_text())
        metadata['version'] = args.version
        metadata.pop('scripts', None)
        metadata.pop('devDependencies', None)
        metadata.pop('packageManager', None)
        # This import survives in the public declarations even though ESM has
        # no MCP runtime import. Consumers must be able to resolve its types.
        metadata['dependencies'] = {'@modelcontextprotocol/sdk': '1.26.0'}
        metadata['files'] = ['dist', 'src', 'LICENSE', 'README.md']
        (package_root / 'package.json').write_text(
            json.dumps(metadata, indent=2) + '\n')
        license_path = args.source.parent.parent / 'LICENSE'
        if not license_path.is_file():
            raise ValueError('Missing upstream SDK license')
        shutil.copy2(license_path, package_root / 'LICENSE')
        if (args.source / 'README.md').is_file():
            shutil.copy2(args.source / 'README.md', package_root / 'README.md')
        print('Installed SDK distribution, matching sources and upstream license')
