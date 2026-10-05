"""Build vscode-oniguruma's authored WASM using the pinned Emscripten source."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tarfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('vscode_archive', type=Path)
parser.add_argument('oniguruma_archive', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
root = Path.cwd()
cache = root / 'guix-emscripten-cache'
cache.mkdir()
os.environ['EM_CACHE'] = str(cache)
os.environ['XDG_CACHE_HOME'] = str(root / 'guix-xdg-cache')
Path(os.environ['XDG_CACHE_HOME']).mkdir()
os.environ['SHELL'] = shutil.which('bash')
if not os.environ['SHELL']:
    raise RuntimeError('Pinned build environment has no Bash executable')
os.environ['CONFIG_SHELL'] = os.environ['SHELL']
for variable in ('CPATH', 'C_INCLUDE_PATH', 'CPLUS_INCLUDE_PATH',
                 'OBJC_INCLUDE_PATH', 'OBJCPLUS_INCLUDE_PATH', 'LIBRARY_PATH'):
    os.environ.pop(variable, None)
source = root / 'oniguruma-source'
source.mkdir()
with tarfile.open(args.oniguruma_archive) as archive:
    archive.extractall(source, filter='data')
names = [p for p in source.iterdir() if p.is_dir()]
if len(names) != 1 or names[0].name != 'oniguruma-08d36110c5670c815ad6d6f969e578049d209080':
    raise ValueError('Unexpected pinned Oniguruma submodule source')
vscode = root / 'vscode-oniguruma-source'
vscode.mkdir()
with tarfile.open(args.vscode_archive) as archive:
    archive.extractall(vscode, filter='data')
projects = [p for p in vscode.iterdir() if p.is_dir()]
if len(projects) != 1 or projects[0].name != 'vscode-oniguruma-1.7.0':
    raise ValueError('Unexpected vscode-oniguruma source version')
project = projects[0]
dependency = project / 'deps/oniguruma'
shutil.rmtree(dependency)
shutil.copytree(names[0], dependency)
subprocess.run(['sh', 'autogen.sh'], cwd=dependency, check=True)
if not (dependency / 'configure').is_file():
    subprocess.run(['autoconf'], cwd=dependency, check=True)
if not (dependency / 'configure').is_file():
    raise ValueError('Pinned Oniguruma autoreconf did not produce configure')
# Guix build chroots have no mutable /bin.  Autoconf emits explicit /bin/sh
# invocations (including for config.sub), so point generated scripts at the
# fixed Bash input in the build environment.
for path in dependency.rglob('*'):
    if not path.is_file():
        continue
    data = path.read_bytes()
    if b'\0' not in data and b'/bin/sh' in data:
        path.chmod(path.stat().st_mode | 0o200)
        path.write_bytes(data.replace(b'/bin/sh', os.fsencode(os.environ['SHELL'])))
subprocess.run(['emconfigure', 'bash', str(dependency / 'configure'),
                '--host=wasm32-unknown-emscripten'],
               cwd=dependency, check=True)
subprocess.run(['emmake', 'make', '-j1', 'SHELL=' + os.environ['SHELL']],
               cwd=dependency, check=True)
library = dependency / 'src/.libs/libonig.a'
if not library.is_file():
    raise ValueError('Emscripten Oniguruma archive was not built')
subprocess.run(['emcc', '-O2', str(library), 'src/onig.cc',
                '-Isrc', '-Ideps/oniguruma/src', '-o', 'out/onig.js',
                '-s', 'ENVIRONMENT=shell', '-s', 'FILESYSTEM=0', '-s', 'MODULARIZE=1',
                '-s', 'EXPORT_NAME=Onig', '-s', 'ALLOW_MEMORY_GROWTH=1',
                '-s', "EXPORTED_RUNTIME_METHODS=['UTF8ToString']"], cwd=project, check=True)
subprocess.run(['node', 'scripts/remove-print.js'], cwd=project, check=True)
wasm = project / 'out/onig.wasm'
if not wasm.is_file() or wasm.read_bytes()[:8] != b'\0asm\1\0\0\0':
    raise ValueError('Expected source-built WebAssembly v1 module')
destination = args.output / 'share/oniguruma-wasm'
destination.mkdir(parents=True)
shutil.copy2(wasm, destination / 'onig.wasm')
shutil.copy2(project / 'LICENSE.txt', destination / 'LICENSE-vscode-oniguruma.txt')
shutil.copy2(dependency / 'COPYING', destination / 'LICENSE-oniguruma.txt')
(destination / 'source-provenance.txt').write_text(
    'vscode-oniguruma 1.7.0\n'
    'source-sha256 0e472a9d670d3301024435c04c09870bce2779c22a099185c2988d99b1cea190\n'
    'oniguruma 08d36110c5670c815ad6d6f969e578049d209080\n'
    'oniguruma-sha256 197bdc01b6e71245ca95e652827fe53c4b1532a4175870f62157b5f909fa0e6f\n'
    'wasm-sha256 ' + hashlib.sha256(wasm.read_bytes()).hexdigest() + '\n')
print('Installed source-built Oniguruma WASM')
