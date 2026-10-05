"""Compile all Acorn module and CLI entries for the Guix Node toolchain."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('output', type=Path)
parser.add_argument('node')
args = parser.parse_args()
source = Path('acorn')
metadata = json.loads((source / 'package.json').read_text())
if metadata['version'] != '8.7.1':
    raise ValueError('Unexpected authored Acorn version')
dist = source / 'dist'
dist.mkdir(exist_ok=True)
subprocess.run(['esbuild', str(source / 'src/index.js'), '--bundle',
                '--format=cjs', '--platform=neutral', '--target=node16',
                '--outfile=acorn/dist/acorn.cjs'], check=True)
body = (dist / 'acorn.cjs').read_text()
# Retain UMD's CommonJS, AMD and browser-global entry points and writable
# exported values. The toolchain variant runs on Guix's modern Node runtime.
umd = '''(function(global, factory) {
  if (typeof exports === 'object' && typeof module !== 'undefined') factory(exports);
  else if (typeof define === 'function' && define.amd) define(['exports'], factory);
  else factory(global.acorn = {});
})(typeof globalThis !== 'undefined' ? globalThis : typeof self !== 'undefined' ? self : this,
function(exports) {
  var module = {exports: exports};
'''
umd += body + '''
  Object.keys(module.exports).forEach(function(name) { exports[name] = module.exports[name]; });
  Object.defineProperty(exports, '__esModule', {value: true});
});
'''
(dist / 'acorn.js').write_text(umd)
(dist / 'acorn.cjs').unlink()
subprocess.run(['esbuild', str(source / 'src/index.js'), '--bundle',
                '--format=esm', '--platform=neutral', '--target=node16',
                '--outfile=acorn/dist/acorn.mjs'], check=True)
cli = source / 'src/bin/acorn.js'
text = cli.read_text()
anchor = 'import * as acorn from "acorn"'
if text.count(anchor) != 1:
    raise ValueError('Unexpected Acorn CLI parser import')
cli.write_text(text.replace(anchor, 'import * as acorn from "./acorn.js"'))
subprocess.run(['esbuild', str(cli), '--bundle', '--format=cjs',
                '--platform=node', '--target=node16', '--external:./acorn.js',
                '--outfile=acorn/dist/bin.js'], check=True)
provider = args.output / 'lib/node_modules/acorn'
provider.mkdir(parents=True)
shutil.copytree(dist, provider / 'dist')
shutil.copytree(source / 'bin', provider / 'bin')
shutil.copyfile(source / 'LICENSE', provider / 'LICENSE')
# This is the Emscripten/Guix Node variant. It does not claim the upstream
# transpilation pipeline's historical Node 0.4 compatibility.
metadata['engines']['node'] = '>=16'
(provider / 'package.json').write_text(json.dumps(metadata, indent=2) + '\n')
launcher = provider / 'bin/acorn'
text = launcher.read_text()
if text.split('\n', 1)[0] not in ('#!/usr/bin/env node', '#!' + args.node):
    raise ValueError('Unexpected Acorn launcher')
launcher.write_text('#!' + args.node + '\n' + text.split('\n', 1)[1])
launcher.chmod(0o755)
(args.output / 'bin').mkdir()
(args.output / 'bin/acorn').symlink_to(launcher)
print('Built full Acorn parser, UMD/ESM modules, type declarations and CLI')
