"""Install authored source-map JavaScript with a source-built matching WASM."""
import json
from pathlib import Path
import shutil
import subprocess
import sys

output, wasm, version = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
metadata = json.loads(Path('package.json').read_text())
if metadata['name'] != 'source-map' or metadata['version'] != version:
    raise ValueError('Unexpected source-map source identity')
if wasm.read_bytes()[:4] != b'\x00asm':
    raise ValueError('Source-built mappings provider is not WASM')
provider = output / 'lib/node_modules/source-map'
provider.mkdir(parents=True)
# Never install the prebuilt fixture from the authored Git source tree.
shutil.copytree('lib', provider / 'lib', ignore=shutil.ignore_patterns('*.wasm'))
shutil.copyfile(wasm, provider / 'lib/mappings.wasm')
for name in ('package.json', 'source-map.js', 'source-map.d.ts', 'LICENSE', 'README.md'):
    shutil.copyfile(name, provider / name)
if Path('node_modules').is_dir():
    shutil.copytree('node_modules', provider / 'node_modules')
subprocess.run(['esbuild', 'source-map.js', '--bundle', '--format=cjs',
                '--platform=browser', '--target=node8', '--external:fs',
                '--external:path', '--external:url', '--minify', '--outfile=guix-source-map.cjs'], check=True)
body = Path('guix-source-map.cjs').read_text()
umd = '''(function(root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else if (typeof define === 'function' && define.amd) define([], factory);
  else root.sourceMap = factory();
})(typeof self !== 'undefined' ? self : this, function() {
  var module = {exports: {}};
  var exports = module.exports;
'''
umd += body + '\nreturn module.exports;\n});\n'
(provider / 'dist').mkdir()
(provider / 'dist/source-map.js').write_text(umd)
print('Installed full source-map Node API, UMD, types and source-built WASM', version)
