"""Compile both authored Yoga targets and their full JavaScript API."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

output = Path(sys.argv[1])
metadata = json.loads(Path('package.json').read_text())
if (metadata['name'], metadata['version']) != ('yoga-wasm-web', '0.3.3'):
    raise ValueError('Unexpected Yoga package identity')
cache = Path('guix-emscripten-cache').resolve()
os.environ['EM_CACHE'] = str(cache)
os.environ['EMCC_CORES'] = '1'
# Guix's native GNU build environment exposes host GCC headers and libraries.
# WASM compilation must resolve C/C++ headers exclusively from Emscripten's
# authored sysroot, not the host libstdc++ search paths.
for variable in ('CPATH', 'C_INCLUDE_PATH', 'CPLUS_INCLUDE_PATH',
                 'OBJC_INCLUDE_PATH', 'LIBRARY_PATH'):
    os.environ.pop(variable, None)
# Guix Clang also has an absolute native glibc include directory configured at
# build time. Disable those standard paths while retaining Clang builtins and
# explicitly supplying the target's authored musl/libc++ sysroot directories.
os.environ['EMCC_CFLAGS'] = (
    '-nostdlibinc -isystem ' + str(cache / 'sysroot/include/c++/v1') +
    ' -isystem ' + str(cache / 'sysroot/include/fakesdl') +
    ' -isystem ' + str(cache / 'sysroot/include/compat') +
    ' -isystem ' + str(cache / 'sysroot/include'))
subprocess.run(['make', '-j1', 'all'], check=True)
provider = output / 'lib/node_modules/yoga-wasm-web'
dist = provider / 'dist'
dist.mkdir(parents=True)
for name in ('asm', 'index', 'node', 'browser'):
    subprocess.run(['esbuild', name + '.js', '--bundle', '--format=esm',
                    '--platform=neutral', '--target=esnext',
                    '--external:node:*', '--minify',
                    '--outfile=' + str(dist / (name + '.js'))], check=True)
shutil.copyfile('tmp/yoga.wasm', dist / 'yoga.wasm')
for source in Path('dist').glob('*.d.ts'):
    shutil.copyfile(source, dist / source.name)
wrap = Path('yoga/javascript/src_js/wrapAsm.d.ts').read_text()
(dist / 'wrapAsm.d.ts').write_text(
    wrap.replace('./generated/YGEnums', './generated/YGEnums.js'))
(dist / 'generated').mkdir()
shutil.copyfile('yoga/javascript/src_js/generated/YGEnums.d.ts',
                dist / 'generated/YGEnums.d.ts')
for name in ('package.json', 'LICENSE', 'LICENSE_yoga-layout-wasm'):
    shutil.copyfile(name, provider / name)
licenses = provider / 'licenses'
licenses.mkdir()
shutil.copyfile('yoga/LICENSE', licenses / 'Yoga-LICENSE')
for name in ('asm.js', 'index.js', 'node.js', 'browser.js', 'yoga.wasm',
             'asm.d.ts', 'auto.d.ts', 'index.d.ts', 'wrapAsm.d.ts',
             'generated/YGEnums.d.ts'):
    if not (dist / name).is_file() or (dist / name).stat().st_size == 0:
        raise ValueError(f'Missing Yoga output: {name}')
print('Built Yoga WASM, asm.js, all four module entries and authored types')
