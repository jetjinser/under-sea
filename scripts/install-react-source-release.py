"""Install complete authored React release resources after compilation."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('stage', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
if args.output.exists():
    raise ValueError('Installation output must be fresh')
build = args.stage / 'build'
completion = json.loads((args.stage / 'guix-react-release-build.json').read_text())
required = ('react', 'react-dom', 'scheduler', 'react-server-dom-webpack',
            'react-server-dom-turbopack')
identities = {}
for channel in ('oss-stable', 'oss-experimental', 'oss-stable-semver'):
    for name in required:
        package = build / channel / name
        manifest = json.loads((package / 'package.json').read_text())
        base = '0.28.0' if name == 'scheduler' else '19.3.0'
        expected = (base + '-canary-52684925-20251110' if channel == 'oss-stable'
                    else '0.0.0-experimental-52684925-20251110'
                    if channel == 'oss-experimental' else base)
        if (manifest['name'], manifest['version']) != (name, expected):
            raise ValueError('Release package identity mismatch: ' + channel + '/' + name)
        if not list((package / 'cjs').glob('*.js')):
            raise ValueError('Compiled CommonJS resources missing: ' + channel + '/' + name)
        if not (package / 'LICENSE').is_file():
            raise ValueError('Authored license missing: ' + channel + '/' + name)
        identities[channel + '/' + name] = expected
destination = args.output / 'share/react-release'
shutil.copytree(build, destination, symlinks=True)
files = {}
for path in sorted(destination.rglob('*')):
    if path.is_symlink():
        raise ValueError('Unexpected release artifact symlink: ' + str(path))
    if path.is_file():
        files[str(path.relative_to(destination))] = hashlib.sha256(path.read_bytes()).hexdigest()
record = {'identities': identities, 'build': completion, 'artifacts': files,
          'functional_validation': 'deferred'}
(args.output / 'react-release-artifacts.json').write_text(json.dumps(record, indent=2) + '\n')
print('Installed', len(files), 'authored release files')
