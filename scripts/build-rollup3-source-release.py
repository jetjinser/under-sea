"""Build and install all authored Rollup 3.29.5 release artifacts."""
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
parser.add_argument('output', type=Path)
args = parser.parse_args()
source = args.source.resolve()
metadata = json.loads((source / 'package.json').read_text())
if metadata['name'] != 'rollup' or metadata['version'] != '3.29.5':
    raise ValueError('Expected Rollup 3.29.5 authored release')
modules = source / 'node_modules'
layout = json.loads((modules / 'guix-source-layout.json').read_text())
lock_hash = hashlib.sha256((source / 'package-lock.json').read_bytes()).hexdigest()
if layout.get('npm_lock_sha256') != lock_hash or layout.get('install_scripts_executed') is not False:
    raise ValueError('Release modules must use authenticated authored lock')
output = args.output.resolve()
if output.exists():
    raise ValueError('Output must be fresh')
environment = dict(os.environ, NODE_PATH=str(modules),
                   SOURCE_DATE_EPOCH=os.environ.get('SOURCE_DATE_EPOCH', '1'))
subprocess.run([str(args.node.resolve()), str(modules / 'rollup/dist/bin/rollup'),
                '--config', 'rollup.config.ts', '--configPlugin', 'typescript'],
               cwd=source, env=environment, check=True)
required = ['dist/rollup.js', 'dist/es/rollup.js', 'dist/bin/rollup',
            'dist/rollup.d.ts', 'dist/loadConfigFile.js', 'dist/loadConfigFile.d.ts',
            'dist/getLogFilter.js', 'dist/getLogFilter.d.ts', 'dist/es/getLogFilter.js',
            'browser/dist/rollup.browser.js', 'browser/dist/es/rollup.browser.js',
            'browser/dist/rollup.browser.d.ts']
for relative in required:
    if not (source / relative).is_file():
        raise ValueError('Missing authored release artifact: ' + relative)
output.mkdir(parents=True)
shutil.copytree(source / 'dist', output / 'dist')
shutil.copytree(source / 'browser/dist', output / 'browser/dist')
for relative in ('package.json', 'LICENSE.md', 'README.md',
                 'browser/package.json', 'browser/LICENSE.md'):
    shutil.copy2(source / relative, output / relative)
artifacts = {str(p.relative_to(output)): hashlib.sha256(p.read_bytes()).hexdigest()
             for p in sorted(output.rglob('*')) if p.is_file()}
(output / 'guix-source-artifacts.json').write_text(json.dumps({
    'version': metadata['version'], 'npm_lock_sha256': lock_hash,
    'source_date_epoch': environment['SOURCE_DATE_EPOCH'], 'artifacts': artifacts,
    'scope': 'Full authored CJS/ESM/CLI/types/browser release',
    'functional_validation': 'deferred'}, indent=2) + '\n')
