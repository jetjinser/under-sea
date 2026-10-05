"""Statically inventory skill/plugin dependency evidence without running code."""
import argparse
import ast
import hashlib
import json
from pathlib import Path
import re
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
patterns = re.compile(r'\b(?:pip(?:3)?\s+install|uv\s+(?:pip\s+install|tool\s+install)|'
                      r'npm\s+(?:install|i)\b|npx\s|uvx\s|brew\s+install|'
                      r'apt(?:-get)?\s+install|command\s+-v|prerequisites|'
                      r'API[_ -]?KEY|dependencies|requirements)', re.I)
files = []
evidence = []
unresolved = []
for category in ('skills', 'plugins'):
    directory = args.source / category
    if not directory.is_dir():
        raise ValueError('Missing source category: ' + category)
    for path in sorted(directory.rglob('*')):
        if not path.is_file() or path.suffix not in ('.py', '.md', '.yaml', '.yml', '.json', '.sh', '.txt'):
            continue
        relative = str(path.relative_to(args.source))
        data = path.read_bytes()
        text = data.decode('utf-8')
        files.append({'path': relative, 'sha256': hashlib.sha256(data).hexdigest()})
        for number, line in enumerate(text.splitlines(), 1):
            if patterns.search(line):
                evidence.append({'kind': 'documented-dependency-or-condition',
                                 'file': relative, 'line': number, 'text': line.strip()[:350]})
        if path.suffix != '.py':
            continue
        tree = ast.parse(text, filename=relative)
        for node in ast.walk(tree):
            imported = []
            if isinstance(node, ast.Import):
                imported = [name.name for name in node.names]
            elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
                imported = [node.module]
            for module in imported:
                root = module.split('.')[0]
                if root not in sys.stdlib_module_names:
                    evidence.append({'kind': 'non-stdlib-import-candidate',
                                     'file': relative, 'line': node.lineno, 'module': module,
                                     'note': 'May be local or optional; requires manual classification'})
            if not isinstance(node, ast.Call) or not node.args:
                continue
            function = ast.unparse(node.func)
            if function not in ('subprocess.run', 'subprocess.Popen', 'subprocess.call',
                                'subprocess.check_call', 'subprocess.check_output',
                                'shutil.which', 'importlib.import_module', '__import__'):
                continue
            argument = node.args[0]
            if isinstance(argument, (ast.List, ast.Tuple)) and argument.elts:
                argument = argument.elts[0]
            if isinstance(argument, ast.Constant) and isinstance(argument.value, str):
                evidence.append({'kind': 'literal-external-call', 'function': function,
                                 'file': relative, 'line': node.lineno,
                                 'value': argument.value})
            else:
                unresolved.append({'file': relative, 'line': node.lineno,
                                   'function': function,
                                   'expression': ast.unparse(node.args[0])[:350]})
args.output.write_text(json.dumps({
    'source_version': 'Hermes v2026.9.24', 'source_root': str(args.source.resolve()),
    'scanned_files': files, 'evidence': evidence, 'unresolved_dynamic_calls': unresolved,
    'scope': 'All text/Python files under shipped skills and plugins; no imports or shell commands executed',
    'status': 'Evidence inventory; each candidate still needs manual dependency/service/platform classification',
    'functional_validation': 'deferred'}, ensure_ascii=False, indent=2) + '\n')
print('Inventoried', len(files), 'files;', len(evidence), 'dependency evidence records;',
      len(unresolved), 'dynamic calls require review')
