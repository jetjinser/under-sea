"""Compile and install the authored React Compiler plugin without functional tests."""
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
parser.add_argument('modules', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
source = args.source.resolve()
modules = args.modules.resolve()
lock = source / 'compiler/yarn.lock'
lock_hash = hashlib.sha256(lock.read_bytes()).hexdigest()
if lock_hash != 'c0688fa846cd619cda6fac64f5a2c9f8e8cff7fcafe8e8c57b31e739063af9fc':
    raise ValueError('Compiler authored lock mismatch')
layout = json.loads((modules / 'guix-source-layout.json').read_text())
if layout.get('yarn_lock_sha256') != lock_hash or layout.get('install_scripts_executed') is not False:
    raise ValueError('Unauthenticated Compiler module layout')
plugin = source / 'compiler/packages/babel-plugin-react-compiler'
config = plugin / 'tsup.config.ts'
expected = json.loads((source / 'compiler/packages/babel-plugin-react-compiler/package.json').read_text())
if expected['name'] != 'babel-plugin-react-compiler':
    raise ValueError('Unexpected plugin identity')
output = args.output.resolve()
if output.exists() or (plugin / 'node_modules').exists():
    raise ValueError('Build and output directories must be fresh')
(plugin / 'node_modules').symlink_to(modules, target_is_directory=True)
environment = dict(os.environ, NODE_PATH=str(modules))
subprocess.run([str(args.node.resolve()), str(modules / 'tsup/dist/cli-default.js')],
               cwd=plugin, env=environment, check=True)
if not (plugin / 'dist/index.js').is_file():
    raise ValueError('Missing authored Compiler entry')
output.mkdir(parents=True)
shutil.copytree(plugin / 'dist', output / 'dist')
shutil.copy2(plugin / 'package.json', output / 'package.json')
shutil.copy2(source / 'LICENSE', output / 'LICENSE')
if (plugin / 'README.md').is_file():
    shutil.copy2(plugin / 'README.md', output / 'README.md')
artifacts = {str(p.relative_to(output)): hashlib.sha256(p.read_bytes()).hexdigest()
             for p in sorted(output.rglob('*')) if p.is_file()}
(output / 'guix-source-artifacts.json').write_text(json.dumps({
    'compiler_yarn_lock_sha256': lock_hash,
    'config_sha256': hashlib.sha256(config.read_bytes()).hexdigest(),
    'artifacts': artifacts, 'functional_validation': 'deferred'}, indent=2) + '\n')
