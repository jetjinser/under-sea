"""Adapt the channel's source Rust sysroot configuration to WASI preview 1."""
import argparse
from pathlib import Path
import tomllib

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('configuration', type=Path)
parser.add_argument('wasi_root', type=Path)
args = parser.parse_args()
text = args.configuration.read_text()
data = tomllib.loads(text)
if data['build']['target'] != ['wasm32-unknown-unknown']:
    raise ValueError('Unexpected original Rust sysroot target')
if text.count('wasm32-unknown-unknown') != 2:
    raise ValueError('Unexpected Rust target configuration anchors')
root = args.wasi_root.resolve()
if not (root / 'lib/wasm32-wasi/libc.a').is_file():
    raise ValueError('WASI libc source-built archive missing')
# Rust 1.93 bootstrap looks up the target spelling wasm32-wasip1 while the
# channel's wasi-libc keeps the equivalent preview-one wasm32-wasi directory.
# Provide an isolated layout view, leaving the store dependency untouched.
view = args.configuration.resolve().parent / 'guix-wasi-preview-one-root'
view.mkdir()
(view / 'include').symlink_to(root / 'include', target_is_directory=True)
(view / 'lib').mkdir()
for entry in (root / 'lib').iterdir():
    (view / 'lib' / entry.name).symlink_to(entry, target_is_directory=entry.is_dir())
alias = view / 'lib/wasm32-wasip1'
if not alias.exists():
    alias.symlink_to(root / 'lib/wasm32-wasi', target_is_directory=True)
if not (alias / 'libc.a').is_file():
    raise ValueError('Rust WASI target libc archive view missing')
root = view
text = text.replace('wasm32-unknown-unknown', 'wasm32-wasip1')
anchor = '[target.wasm32-wasip1]\n'
if text.count(anchor) != 1:
    raise ValueError('Missing explicit Rust WASI target section')
# Known Guix store paths contain no TOML quoting characters.
if any(c in str(root) for c in ('"', '\\', '\n')):
    raise ValueError('Unsafe WASI root path')
text = text.replace(anchor, anchor + 'wasi-root = "' + str(root) + '"\n')
updated = tomllib.loads(text)
if updated['target']['wasm32-wasip1']['wasi-root'] != str(root):
    raise ValueError('WASI root not scoped to target')
args.configuration.write_text(text)
print('Configured matching source Rust standard library for wasm32-wasip1', flush=True)
