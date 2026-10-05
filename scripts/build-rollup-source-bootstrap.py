"""Compile a private Rollup bootstrap from its authored TypeScript entrypoints.

This is a build tool stage, not the final authored Rollup release build.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('esbuild', type=Path)
parser.add_argument('native_module', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--inline-import-only', type=Path,
                    help='Authenticated consumer module layout for import-only source inputs')
parser.add_argument('--input-archives', type=Path)
parser.add_argument('--archive-paths', type=Path,
                    help='Fixed Guix identity<TAB>archive paths for inlined inputs')
args = parser.parse_args()
source = args.source.resolve()
metadata = json.loads((source / 'package.json').read_text())
if metadata['version'] not in ('4.34.8', '3.29.2'):
    raise ValueError('Unaudited source bootstrap version')
binding = None
if metadata['version'] == '3.29.2':
    if str(args.native_module) != '-':
        raise ValueError('Rollup 3 bootstrap has no native binding')
else:
    native_metadata = json.loads((args.native_module / 'package.json').read_text())
    if native_metadata['version'] != metadata['version'] or native_metadata['name'] != '@rollup/rollup-linux-x64-gnu':
        raise ValueError('Bootstrap source and native identity mismatch')
    binding = args.native_module / 'rollup.linux-x64-gnu.node'
    if binding.read_bytes()[:4] != b'\x7fELF':
        raise ValueError('Missing source-built ELF binding')
output = args.output.resolve()
if output.exists():
    raise ValueError('Use a fresh bootstrap output')
entries = {'dist/rollup.js': 'src/node-entry.ts',
           'dist/loadConfigFile.js': 'cli/run/loadConfigFile.ts',
           'dist/getLogFilter.js': 'src/utils/getLogFilter.ts',
           'dist/parseAst.js': 'src/utils/parseAst.ts',
           'dist/bin/rollup': 'cli/cli.ts'}
if metadata['version'] == '3.29.2':
    entries.pop('dist/parseAst.js')
inline_flags = []
inline_evidence = {}
if args.inline_import_only:
    if not args.input_archives:
        raise ValueError('Inlining requires authenticated archive records')
    records = {r['identity']: r for r in json.loads(args.input_archives.read_text())['archives']}
    if args.archive_paths:
        for line in args.archive_paths.read_text().splitlines():
            identity, path = line.split('\t')
            if identity not in records or not Path(path).is_absolute():
                raise ValueError('Unexpected fixed inline archive identity')
            records[identity]['archive'] = path
    locked = json.loads((source / 'package-lock.json').read_text())['packages']
    for name in ('locate-character', 'is-reference'):
        package = (args.inline_import_only / name).resolve()
        info = json.loads((package / 'package.json').read_text())
        expected = locked['node_modules/' + name]
        record = records[name + '@' + expected['version']]
        if info['name'] != name or info['version'] != expected['version']:
            raise ValueError('Import-only source version mismatch: ' + name)
        archive = Path(record['archive'])
        if hashlib.sha256(archive.read_bytes()).hexdigest() != record['sha256']:
            raise ValueError('Authenticated archive changed: ' + name)
        # Compare the exact authored source used for inlining with its archive.
        import tarfile
        entry = info['exports']['import']
        if entry != './src/index.js':
            raise ValueError('Unreviewed import-only entry: ' + name)
        source_file = package / entry
        with tarfile.open(archive) as tar:
            authored = tar.extractfile('package/src/index.js').read()
        if source_file.read_bytes() != authored:
            raise ValueError('Inline source differs from authenticated archive: ' + name)
        import base64
        algorithm, value = expected['integrity'].split('-', 1)
        if hashlib.new(algorithm, archive.read_bytes()).digest() != base64.b64decode(value):
            raise ValueError('Bootstrap lock integrity mismatch: ' + name)
        inline_flags.append('--alias:' + name + '=' + str(source_file))
        inline_evidence[name] = {'version': info['version'], 'archive_sha256': record['sha256'],
                                 'source_sha256': hashlib.sha256(authored).hexdigest()}
for destination, entry in entries.items():
    target = output / destination
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([str(args.esbuild.resolve()), entry, '--bundle', '--platform=node',
                    '--format=cjs', '--target=node18', '--packages=external',
                    '--alias:package.json=./package.json', '--alias:help.md=./cli/help.md',
                    '--loader:.md=text', '--outfile=' + str(target), *inline_flags], cwd=source, check=True)
    # Authored native.js is bundled and discovers its local binding by __dirname.
    if binding:
        local = target.parent / binding.name
        if not local.exists():
            shutil.copy2(binding, local)
    if destination == 'dist/bin/rollup':
        target.chmod(target.stat().st_mode | 0o111)
metadata['type'] = 'commonjs'
type_sources = {'rollup': ('src/rollup/types.d.ts', None),
                'loadConfigFile': ('cli/run/loadConfigFileType.d.ts', '../../src/rollup/types'),
                'getLogFilter': ('src/utils/getLogFilterType.d.ts', '../rollup/types'),
                'parseAst': ('src/utils/parseAstType.d.ts', '../rollup/types')}
if metadata['version'] == '3.29.2':
    type_sources.pop('parseAst')
for name, (entry, replacement) in type_sources.items():
    content = (source / entry).read_text()
    if replacement:
        content = content.replace(replacement, './rollup', 1)
    (output / 'dist' / (name + '.d.ts')).write_text(content)
metadata['exports'] = {
    ('.' if name == 'rollup' else './' + name): {
        'types': './dist/' + name + '.d.ts', 'default': './dist/' + name + '.js'}
    for name in type_sources}
metadata['exports']['./dist/*'] = './dist/*'
(output / 'package.json').write_text(json.dumps(metadata, indent=2) + '\n')
shutil.copy2(source / 'LICENSE.md', output / 'LICENSE.md')
artifacts = {str(p.relative_to(output)): hashlib.sha256(p.read_bytes()).hexdigest()
             for p in output.rglob('*') if p.is_file()}
(output / 'guix-bootstrap-artifacts.json').write_text(json.dumps({
    'source_version': metadata['version'], 'source': str(source),
    'native_provider': str(args.native_module) if binding else None, 'artifacts': artifacts,
    'inlined_import_only_sources': inline_evidence,
    'scope': 'Private source bootstrap; authored final release build still required',
    'functional_validation': 'deferred'}, indent=2) + '\n')
