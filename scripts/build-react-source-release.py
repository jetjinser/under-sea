"""Stage and execute React's complete authored release-channel compilation."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('modules', type=Path)
parser.add_argument('stage', type=Path)
parser.add_argument('--node', required=True)
parser.add_argument('--metadata-script', type=Path,
                    default=Path(__file__).with_name('patch-react-source-metadata.py'))
parser.add_argument('--compiler-modules', type=Path,
                    help='Separate authored compiler/yarn.lock module layout')
args = parser.parse_args()
source = args.source.resolve()
modules = args.modules.resolve()
stage = args.stage.resolve()
if stage.exists():
    raise ValueError('Build stage must be fresh')
layout = json.loads((modules / 'guix-source-layout.json').read_text())
digest = hashlib.sha256((source / 'yarn.lock').read_bytes()).hexdigest()
if digest != 'c320fd73c4bab5bb2a9abef7d36a35d94de92ea9b1d2b9416e2a2134b0e16e5c':
    raise ValueError('Unexpected React source lock')
if digest not in layout.values():
    raise ValueError('Module layout lock differs from React source')
excluded = ['node_modules', '.git', 'build']
if stage.parent == source:
    excluded.append(stage.name)
if modules.parent == source:
    excluded.append(modules.name)
if args.compiler_modules and args.compiler_modules.resolve().parent == source:
    excluded.append(args.compiler_modules.name)
shutil.copytree(source, stage, symlinks=True,
                ignore=lambda directory, names:
                [name for name in names if name in excluded]
                if Path(directory) == source else [])
subprocess.run([sys.executable,
                str(args.metadata_script.resolve()),
                str(stage)], check=True)
local_modules = stage / 'node_modules'
local_modules.mkdir()
for entry in modules.iterdir():
    (local_modules / entry.name).symlink_to(entry.resolve(), target_is_directory=entry.is_dir())
manifest = json.loads((stage / 'package.json').read_text())
if manifest['workspaces'] != ['packages/*']:
    raise ValueError('Unexpected authored workspace scope')
for package_manifest in sorted((stage / 'packages').glob('*/package.json')):
    name = json.loads(package_manifest.read_text())['name']
    target = local_modules / name
    if target.exists() or target.is_symlink():
        raise ValueError('Workspace conflicts with registry package: ' + name)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.symlink_to(package_manifest.parent, target_is_directory=True)
if args.compiler_modules:
    compiler_modules = args.compiler_modules.resolve()
    compiler_layout = json.loads((compiler_modules / 'guix-source-layout.json').read_text())
    compiler_digest = hashlib.sha256((stage / 'compiler/yarn.lock').read_bytes()).hexdigest()
    if (compiler_layout.get('yarn_lock_sha256') != compiler_digest
            or compiler_layout.get('install_scripts_executed') is not False):
        raise ValueError('Compiler source module layout mismatch')
    (stage / 'compiler/node_modules').symlink_to(compiler_modules, target_is_directory=True)
    compiler_package = stage / 'compiler/packages/babel-plugin-react-compiler'
    compiler_metadata = json.loads((compiler_package / 'package.json').read_text())
    if compiler_metadata['name'] != 'babel-plugin-react-compiler':
        raise ValueError('Compiler workspace identity changed')
    (local_modules / compiler_metadata['name']).symlink_to(compiler_package, target_is_directory=True)
env = os.environ.copy()
env['PATH'] = str(Path(args.node).parent) + os.pathsep + env['PATH']
env.setdefault('SOURCE_DATE_EPOCH', '1')
subprocess.run([args.node, './scripts/rollup/build-all-release-channels.js'],
               cwd=stage, env=env, check=True)
(stage / 'guix-react-release-build.json').write_text(json.dumps({
    'yarn_lock_sha256': digest, 'modules': str(modules),
    'build_command': ['./scripts/rollup/build-all-release-channels.js'],
    'functional_validation': 'deferred'}, indent=2) + '\n')
