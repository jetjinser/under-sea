"""Install reviewed Node sources and bundle Hermes TUI without npm downloads."""
import base64
import hashlib
import json
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
from html.parser import HTMLParser
from urllib.parse import urlsplit, unquote


class DashboardAssets(HTMLParser):
    """Check the installed entry's local resource paths without running JS."""
    def __init__(self, directory):
        super().__init__()
        self.directory = directory.resolve()

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        path = attrs.get('src') if tag in ('script', 'img') else (
            attrs.get('href') if tag == 'link' else None)
        if not path:
            return
        url = urlsplit(path)
        if url.scheme or url.netloc:
            return
        relative = unquote(url.path).lstrip('/')
        if not relative:
            return
        target = (self.directory / relative).resolve()
        if not target.is_relative_to(self.directory) or not target.is_file():
            raise ValueError('Dashboard entry references missing local asset: ' + path)

root = Path.cwd()
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--target', choices=('tui', 'web', 'prepare'), default='tui')
parser.add_argument('--native-components', type=Path)
parser.add_argument('--three-source', type=Path)
parser.add_argument('--three-builder', type=Path)
parser.add_argument('--oniguruma-wasm', type=Path)
parser.add_argument('--shiki-wasm-audit', type=Path)
args = parser.parse_args()
for index, line in enumerate((root / 'node-sources.tsv').read_text().splitlines()):
    path, archive = line.split('\t')
    relative = Path(path)
    if relative.is_absolute() or '..' in relative.parts or 'node_modules' not in relative.parts:
        raise ValueError('Invalid locked Node installation path: ' + path)
    staging = root / 'node-unpack' / str(index)
    staging.mkdir(parents=True)
    with tarfile.open(archive) as source:
        source.extractall(staging, filter='data')
    entries = list(staging.iterdir())
    if len(entries) != 1 or not entries[0].is_dir():
        raise ValueError('Unexpected npm source archive layout: ' + path)
    destination = root / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(entries[0], destination)

lock = json.loads((root / 'package-lock.json').read_text())
if args.native_components:
    for line in args.native_components.read_text().splitlines():
        name, version, package = line.split('\t')
        path = 'node_modules/' + name
        if lock['packages'].get(path, {}).get('version') != version:
            raise ValueError('Native Node component differs from lock: ' + name)
        source = Path(package) / 'lib/node_modules' / name
        metadata = json.loads((source / 'package.json').read_text())
        if metadata['name'] != name or metadata['version'] != version:
            raise ValueError('Source-built Node package identity mismatch: ' + name)
        destination = root / path
        if destination.exists():
            raise ValueError('Native Node component already supplied: ' + name)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(source, destination)
for path, item in lock['packages'].items():
    if item.get('link'):
        target = (root / item['resolved']).resolve()
        if not target.is_relative_to(root) or not target.is_dir():
            raise ValueError('Invalid workspace source link: ' + path)
        destination = root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.symlink_to(target, target_is_directory=True)

if bool(args.oniguruma_wasm) != bool(args.shiki_wasm_audit):
    raise ValueError('Oniguruma WASM requires its authenticated Shiki archive audit')
if args.oniguruma_wasm:
    wasm = args.oniguruma_wasm.read_bytes()
    if wasm[:8] != b'\0asm\1\0\0\0':
        raise ValueError('Source-built Oniguruma output is not WebAssembly v1')
    replacement = base64.b64encode(wasm)
    provenance = []
    pattern = re.compile(rb'''['"](AGFzb[A-Za-z0-9+/=]+)['"]''')
    for item in json.loads(args.shiki_wasm_audit.read_text()):
        relative = Path(item['module_path'])
        if relative.is_absolute() or '..' in relative.parts:
            raise ValueError('Unsafe Shiki inline WASM module path')
        module = root / relative
        data = module.read_bytes()
        matches = []
        for match in pattern.finditer(data):
            try:
                payload = base64.b64decode(match.group(1), validate=True)
            except ValueError:
                continue
            if payload[:8] == b'\0asm\1\0\0\0':
                matches.append((match, payload))
        if len(matches) != 1:
            raise ValueError('Expected exactly one inline WASM in ' + str(relative))
        match, original = matches[0]
        if (len(original) != item['wasm_bytes']
                or hashlib.sha256(original).hexdigest() != item['wasm_sha256']):
            raise ValueError('Shiki archive inline WASM differs from locked audit: '
                             + str(relative))
        module.chmod(module.stat().st_mode | 0o200)
        module.write_bytes(data[:match.start(1)] + replacement + data[match.end(1):])
        provenance.append({
            'name': item['name'], 'version': item['version'],
            'archive_sha256': item['archive_sha256'],
            'module_path': str(relative),
            'replaced_wasm_sha256': hashlib.sha256(original).hexdigest(),
            'source_built_wasm_sha256': hashlib.sha256(wasm).hexdigest(),
            'source_built_wasm_bytes': len(wasm),
            'functional_validation': 'deferred'})
    (root / 'hermes-shiki-wasm-source-replacements.json').write_text(
        json.dumps(provenance, indent=2) + '\n')

if args.three_source:
    if not args.three_builder:
        raise ValueError('Three source requires its source build script')
    if lock['packages'].get('node_modules/three', {}).get('version') != '0.180.0':
        raise ValueError('Three source version differs from Node lock')
    # Extract the engine source only. Addon native/WASM payloads are tracked
    # separately and must not leak into the frontend through this archive.
    staging = root / 'three-source'
    staging.mkdir()
    selected = ('src/', 'utils/build/rollup.config.js', 'package.json', 'LICENSE')
    with tarfile.open(args.three_source) as archive:
        members = []
        for member in archive.getmembers():
            prefix, separator, relative = member.name.partition('/')
            if prefix != 'three.js-r180':
                raise ValueError('Unexpected official Three archive root')
            if separator and any(relative == item or relative.startswith(item)
                                 for item in selected):
                members.append(member)
        archive.extractall(staging, members=members, filter='data')
    source = staging / 'three.js-r180'
    (source / 'node_modules').symlink_to(root / 'node_modules', target_is_directory=True)
    (source / 'scripts').mkdir()
    shutil.copyfile(args.three_builder, source / 'scripts/build-hermes-three.mjs')
    subprocess.run(['node', 'scripts/build-hermes-three.mjs'], cwd=source, check=True)
    destination = root / 'node_modules/three'
    if destination.exists():
        raise ValueError('Three already supplied by another source')
    destination.mkdir()
    for directory in ('src', 'build'):
        shutil.copytree(source / directory, destination / directory)
    for filename in ('package.json', 'LICENSE'):
        shutil.copyfile(source / filename, destination / filename)

# Upstream directly bundles the local Ink and shared sources. The esbuild
# JavaScript API uses ESBUILD_BINARY_PATH, supplied by the Guix source build.
if args.target == 'tui':
    subprocess.run(['node', 'ui-tui/scripts/build.mjs'], check=True)
elif args.target == 'web':
    # Upstream Vite outputs outside web/. Remove any bundled old assets so
    # installation can only consume this build's output.
    shutil.rmtree(root / 'hermes_cli/web_dist', ignore_errors=True)
    subprocess.run(['node', str(root / 'node_modules/typescript/bin/tsc'), '-b'],
                   cwd=root / 'web', check=True)
    subprocess.run(['node', str(root / 'node_modules/vite/bin/vite.js'), 'build'],
                   cwd=root / 'web', check=True)
    if not (root / 'hermes_cli/web_dist/index.html').is_file():
        raise ValueError('Vite did not produce the dashboard entry point')
    DashboardAssets(root / 'hermes_cli/web_dist').feed(
        (root / 'hermes_cli/web_dist/index.html').read_text())
