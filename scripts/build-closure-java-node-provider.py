"""Replace the npm Java payload with a launcher for source-built Closure."""
import argparse
import hashlib
import json
from pathlib import Path
import shlex
import tarfile
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('archive', type=Path)
parser.add_argument('compiler', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
output = args.output.resolve()
if output.exists():
    raise ValueError('Output must be fresh')
command = (args.compiler / 'bin/closure-compiler').read_text().splitlines()
if len(command) != 2:
    raise ValueError('Unexpected source compiler wrapper')
tokens = shlex.split(command[1])
main = 'com.google.javascript.jscomp.CommandLineRunner'
if len(tokens) != 6 or tokens[0] != 'exec' or tokens[2] != '-cp' or tokens[4] != main or tokens[5] != '$@':
    raise ValueError('Unexpected Java launch command')
java = Path(tokens[1])
jars = [Path(p) for p in tokens[3].split(':')]
if not java.is_file() or not jars or any(not p.is_file() or not p.is_absolute() for p in jars):
    raise ValueError('Complete fixed source-built Java runtime required')
output.mkdir(parents=True)
with tarfile.open(args.archive) as archive:
    metadata = json.loads(archive.extractfile('package/package.json').read())
    if metadata['name'] != 'google-closure-compiler-java' or metadata['version'] != '20230206.0.0':
        raise ValueError('Unexpected npm Java provider identity')
    for member in archive.getmembers():
        if member.name == 'package/compiler.jar' or not member.isfile():
            continue
        relative = Path(member.name).relative_to('package')
        if '..' in relative.parts:
            raise ValueError('Unsafe archive member')
        destination = output / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(archive.extractfile(member).read())
manifest = ('Manifest-Version: 1.0\r\nMain-Class: ' + main + '\r\nClass-Path: '
            + ' '.join(p.as_uri() for p in jars) + '\r\n\r\n')
# Java manifests limit physical line lengths; preserve continuation semantics.
lines = []
for line in manifest.split('\r\n'):
    while len(line.encode()) > 70:
        lines.append(line[:70]); line = ' ' + line[70:]
    lines.append(line)
with zipfile.ZipFile(output / 'compiler.jar', 'w', zipfile.ZIP_DEFLATED) as jar:
    info = zipfile.ZipInfo('META-INF/MANIFEST.MF', (1980, 1, 1, 0, 0, 0))
    info.compress_type = zipfile.ZIP_DEFLATED
    jar.writestr(info, '\r\n'.join(lines).encode())
(output / 'guix-source-java-provider.json').write_text(json.dumps({
    'compiler': str(args.compiler), 'java': str(java), 'classpath': list(map(str, jars)),
    'archive_sha256': hashlib.sha256(args.archive.read_bytes()).hexdigest(),
    'launcher_sha256': hashlib.sha256((output / 'compiler.jar').read_bytes()).hexdigest(),
    'functional_validation': 'deferred'}, indent=2) + '\n')
