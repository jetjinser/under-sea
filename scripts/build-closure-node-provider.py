"""Install authored Closure Node sources with a fixed source-built JVM."""
import argparse
import json
from pathlib import Path
import tarfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('archive', type=Path)
parser.add_argument('java_provider', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
output = args.output / 'lib/node_modules/google-closure-compiler'
if output.exists():
    raise ValueError('Output must be fresh')
java_module = args.java_provider / 'lib/node_modules/google-closure-compiler-java'
evidence = json.loads((java_module / 'guix-source-java-provider.json').read_text())
java = evidence['java']
if not Path(java).is_file():
    raise ValueError('Fixed Java executable missing')
with tarfile.open(args.archive) as archive:
    metadata = json.loads(archive.extractfile('package/package.json').read())
    if (metadata['name'], metadata['version']) != ('google-closure-compiler', '20230206.0.0'):
        raise ValueError('Unexpected Node provider identity')
    for member in archive.getmembers():
        if not member.isfile():
            continue
        relative = Path(member.name).relative_to('package')
        if '..' in relative.parts:
            raise ValueError('Unsafe source path')
        destination = output / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(archive.extractfile(member).read())
        destination.chmod(member.mode & 0o777)
entry = output / 'lib/node/closure-compiler.js'
text = entry.read_text()
token = "Compiler.prototype.javaPath = 'java';"
if text.count(token) != 1:
    raise ValueError('Authored Java path declaration changed')
entry.write_text(text.replace(token, 'Compiler.prototype.javaPath = ' + json.dumps(java) + ';'))
(output.parent / 'google-closure-compiler-java').symlink_to(java_module)
(output / 'guix-source-node-provider.json').write_text(json.dumps({
    'java_provider': str(java_module), 'java': java,
    'registry_dependencies': metadata['dependencies'],
    'optional_dependencies': metadata['optionalDependencies'],
    'dependency_integration': 'consumer source module graph required',
    'functional_validation': 'deferred'}, indent=2) + '\n')
