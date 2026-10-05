"""Follow literal React Compiler source imports without executing TypeScript."""
import argparse
import hashlib
import json
from pathlib import Path
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
workspace = args.source / 'compiler/packages/babel-plugin-react-compiler'
manifests = {name: json.loads((args.source / name).read_text()) for name in
             ['package.json', 'compiler/package.json',
              'compiler/packages/babel-plugin-react-compiler/package.json']}
queue = [workspace / 'src/index.ts']
files, external, unresolved_candidates = {}, {}, []
pattern = re.compile(r'''(?:\bfrom\s*|\brequire\s*\(\s*|\bimport\s*\(\s*|\bimport\s*)['"]([^'"\s]+)['"]''')
while queue:
    file = queue.pop()
    identity = str(file.relative_to(args.source))
    if identity in files:
        continue
    text = file.read_text()
    # Ignore documentation examples while preserving quoted import strings.
    text = re.sub(r'''("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`)|//[^\n]*|/\*[\s\S]*?\*/''',
                  lambda match: match.group(1) or ' ', text)
    files[identity] = hashlib.sha256(file.read_bytes()).hexdigest()
    for request in pattern.findall(text):
        if not re.fullmatch(r'(?:\.{1,2}/|@?[A-Za-z0-9])[A-Za-z0-9_@./:+-]*', request):
            unresolved_candidates.append({'file': identity, 'candidate': request})
            continue
        if request.startswith('.'):
            target = file.parent / request
            candidates = [target, *[Path(str(target) + suffix) for suffix in
                                   ('.ts', '.tsx', '.js', '.json')],
                          target / 'index.ts', target / 'index.tsx', target / 'index.js']
            found = next((p.resolve() for p in candidates if p.is_file()), None)
            if found is None or not found.is_relative_to(args.source.resolve()):
                raise ValueError('Unresolved relative source import: ' + identity + ': ' + request)
            if found.suffix != '.json':
                queue.append(found)
        else:
            name = '/'.join(request.split('/')[:2]) if request.startswith('@') else request.split('/')[0]
            external.setdefault(name, []).append({'file': identity, 'request': request})
declarations = {}
for name in external:
    declarations[name] = {file: {group: data[group][name] for group in
                                 ('dependencies', 'devDependencies', 'peerDependencies', 'resolutions')
                                 if name in data.get(group, {})}
                          for file, data in manifests.items()}
args.output.write_text(json.dumps({'source_files': files, 'external_imports': external,
    'nonliteral_or_example_candidates_requiring_review': unresolved_candidates,
    'authored_declarations': declarations, 'status': 'Literal source closure; dynamic imports and Yarn resolution require separate audit',
    'functional_validation': 'deferred'}, indent=2) + '\n')
print('Traversed', len(files), 'source files and', len(external), 'external import names')
