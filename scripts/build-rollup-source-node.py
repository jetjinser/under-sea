"""Build the authored Rollup Node release; functional validation is deferred."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('node', type=Path)
parser.add_argument('native_module', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
source = args.source.resolve()
metadata = json.loads((source / 'package.json').read_text())
if metadata['name'] != 'rollup' or metadata['version'] != '4.34.9':
    raise ValueError('Expected authored Rollup 4.34.9 source')
lock_hash = hashlib.sha256((source / 'package-lock.json').read_bytes()).hexdigest()
if lock_hash != '61f67a40df06c4ddebeb152fa070c6347971679f2347896ffdc868bc4392e9b5':
    raise ValueError('Authored lock mismatch')
modules = source / 'node_modules'
layout = json.loads((modules / 'guix-source-layout.json').read_text())
if layout.get('npm_lock_sha256') != lock_hash or layout.get('install_scripts_executed') is not False:
    raise ValueError('Build module layout must match the authenticated authored lock')
native = args.native_module.resolve()
native_metadata = json.loads((native / 'package.json').read_text())
if native_metadata['name'] != '@rollup/rollup-linux-x64-gnu' or native_metadata['version'] != metadata['version']:
    raise ValueError('Native provider version mismatch')
if (native / 'Cargo.lock').read_bytes() != (source / 'rust/Cargo.lock').read_bytes():
    raise ValueError('Native workspace lock mismatch')
binding = native / 'rollup.linux-x64-gnu.node'
if binding.read_bytes()[:4] != b'\x7fELF':
    raise ValueError('Source-built ELF binding required')
output = args.output.resolve()
if output.exists():
    raise ValueError('Output must be fresh')
environment = dict(os.environ, NODE_PATH=str(modules),
                   SOURCE_DATE_EPOCH=os.environ.get('SOURCE_DATE_EPOCH', '1'))
subprocess.run([str(args.node.resolve()), str(modules / 'rollup/dist/bin/rollup'),
                '--config', 'rollup.config.ts', '--configPlugin', 'typescript',
                '--configIsBuildNode', '--forceExit'], cwd=source,
               env=environment, check=True)
required = ['rollup.js', 'es/rollup.js', 'native.js', 'bin/rollup',
            'rollup.d.ts', 'loadConfigFile.js', 'loadConfigFile.d.ts',
            'getLogFilter.js', 'getLogFilter.d.ts', 'es/getLogFilter.js',
            'parseAst.js', 'parseAst.d.ts', 'es/parseAst.js', 'es/package.json']
for relative in required:
    if not (source / 'dist' / relative).is_file():
        raise ValueError('Missing authored Node artifact: ' + relative)
output.mkdir(parents=True)
shutil.copytree(source / 'dist', output / 'dist')
shutil.copy2(binding, output / 'dist' / binding.name)
for relative in ('package.json', 'LICENSE.md', 'README.md'):
    shutil.copy2(source / relative, output / relative)
artifacts = {str(p.relative_to(output)): hashlib.sha256(p.read_bytes()).hexdigest()
             for p in sorted(output.rglob('*')) if p.is_file()}
(output / 'guix-source-artifacts.json').write_text(json.dumps({
    'version': metadata['version'], 'npm_lock_sha256': lock_hash,
    'native_provider': str(native), 'source_date_epoch': environment['SOURCE_DATE_EPOCH'],
    'artifacts': artifacts, 'scope': 'Authored Node CJS/ESM/CLI/types; browser/WASM release remains separate',
    'functional_validation': 'deferred'}, indent=2) + '\n')
