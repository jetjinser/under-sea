"""Supply fixed archive metadata to React's authored release-channel build."""
import argparse
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
args = parser.parse_args()
source = args.source.resolve()
script = source / 'scripts/rollup/build-all-release-channels.js'
raw = script.read_bytes()
if hashlib.sha256(raw).hexdigest() != '9983232812e87360eec58f84fc8b2dd348b53ad11ebe02eb677fa621cc2a6f63':
    raise ValueError('React release script differs from the audited source commit')
text = raw.decode()
start = text.index("const sha = String(spawnSync('git', ['rev-parse', 'HEAD']).stdout).slice(0, 8);")
end = text.index('// On CI environment, this string is wrapped', start)
commit = '52684925368a41a0c9fbfca9016cdcbb72fc9d1e'
date = '20251110'
replacement = ("// Guix source archive: fixed upstream commit and canary release date.\n"
               f"const sha = '{commit[:8]}';\n\nlet dateString = '{date}';\n\n")
patched = text[:start] + replacement + text[end:]
script.write_text(patched)
(source / 'guix-react-source-metadata.json').write_text(json.dumps({
    'commit': commit, 'release_date': date,
    'source_script_sha256': hashlib.sha256(raw).hexdigest(),
    'patched_script_sha256': hashlib.sha256(patched.encode()).hexdigest(),
    'scope': 'Archive metadata only; all authored release channels and build options retained',
    'functional_validation': 'deferred'}, indent=2) + '\n')
