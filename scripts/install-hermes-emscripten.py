"""Install authored Emscripten sources and fixed source-built Yoga tools."""
import argparse
from pathlib import Path
import shutil

parser = argparse.ArgumentParser(description=__doc__)
for name in ('output', 'python', 'shell', 'node', 'llvm', 'binaryen', 'acorn', 'closure'):
    parser.add_argument('--' + name, required=True)
args = parser.parse_args()
out = Path(args.output)
root = out / 'share/emscripten'
root.mkdir(parents=True)
for item in Path('.').iterdir():
    if item.name in ('test', '.git'):
        continue
    if item.is_dir():
        shutil.copytree(item, root / item.name)
    else:
        shutil.copy2(item, root / item.name)
modules = root / 'node_modules'
modules.mkdir(exist_ok=True)
(modules / 'acorn').symlink_to(Path(args.acorn) / 'lib/node_modules/acorn')
config = root / 'guix-config.py'
config.write_text(
    'import os\n'
    f'LLVM_ROOT = {args.llvm + "/bin"!r}\n'
    f'BINARYEN_ROOT = {args.binaryen!r}\n'
    f'NODE_JS = [{args.node!r}]\n'
    f'CLOSURE_COMPILER = [{args.closure + "/bin/closure-compiler"!r}]\n'
    'CACHE = os.environ.get("EM_CACHE") or os.path.join(' 
    'os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), '
    '"hermes-emscripten-3.1.31")\n'
    'PORTS = os.path.join(CACHE, "ports")\n'
)
bin_dir = out / 'bin'
bin_dir.mkdir()
for name in ('emcc', 'em++', 'emar', 'emranlib', 'emnm', 'emcmake',
             'emconfigure', 'emmake', 'emsize', 'embuilder', 'emrun'):
    entry = root / ('tools/emnm.py' if name == 'emnm' else name + '.py')
    if not entry.is_file():
        raise ValueError(f'Missing authored Emscripten entry: {entry}')
    launcher = bin_dir / name
    launcher.write_text(
        f'#!{args.shell}\n'
        f'export EM_CONFIG="{config}"\n'
        f'exec "{args.python}" "{entry}" "$@"\n'
    )
    launcher.chmod(0o755)
print('Installed authored Emscripten with fixed LLVM, Binaryen, Acorn and Closure')
