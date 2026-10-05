"""Stage matching source-built SWC and error-code plugin for a Next build.

This only copies build inputs; it does not execute either artifact.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('swc_module', type=Path)
parser.add_argument('plugin_resources', type=Path)
parser.add_argument('--audit', required=True, type=Path)
args = parser.parse_args()
package = args.source / 'packages/next'
version = json.loads((package / 'package.json').read_text())['version']
audit = json.loads(args.audit.read_text())['versions'][version]
metadata = json.loads((args.swc_module / 'package.json').read_text())
if (metadata['name'], metadata['version']) != ('@next/swc-linux-x64-gnu', version):
    raise ValueError('Native SWC identity does not match consuming framework')

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

plugin_source = args.source / 'crates/next-error-code-swc-plugin'
for relative, field in [('Cargo.lock', 'cargo_lock_sha256'),
                        ('Cargo.toml', 'manifest_sha256'),
                        ('src/lib.rs', 'source_sha256')]:
    if sha(plugin_source / relative) != audit[field]:
        raise ValueError('Error plugin authored source identity mismatch: ' + relative)
plugin_target = package / 'next_error_code_swc_plugin.wasm'
if sha(plugin_target) != audit['published_wasm_sha256']:
    raise ValueError('Expected original error plugin payload before replacement')
plugin = args.plugin_resources / plugin_target.name
if plugin.read_bytes()[:8] != b'\x00asm\x01\x00\x00\x00':
    raise ValueError('Source-built plugin is not a WebAssembly v1 module')
if sha(args.plugin_resources / 'Cargo.lock') != audit['cargo_lock_sha256']:
    raise ValueError('Source-built plugin lock does not match authored source')
binding = args.swc_module / 'next-swc.linux-x64-gnu.node'
if binding.read_bytes()[:4] != b'\x7fELF':
    raise ValueError('Source-built native SWC is not ELF')
native = args.source / 'packages/next-swc/native'
native.mkdir(parents=True, exist_ok=True)
destination = native / binding.name
if destination.exists() or destination.is_symlink():
    raise ValueError('Native SWC target already exists; use a fresh source tree')
shutil.copy2(binding, destination)
plugin_target.unlink()
shutil.copy2(plugin, plugin_target)
record = {'next_version': version, 'swc_provider': str(args.swc_module),
          'plugin_provider': str(args.plugin_resources),
          'artifacts': {str(p.relative_to(args.source)): sha(p)
                        for p in (destination, plugin_target)},
          'functional_validation': 'deferred'}
(args.source / 'guix-native-inputs.json').write_text(json.dumps(record, indent=2) + '\n')
