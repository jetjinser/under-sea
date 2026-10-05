#!/usr/bin/env python3
"""Copy exact source-built Python distributions into Hermes's private site.

The TSV contains distribution name, locked version and a Guix package output.
Dependencies are supplied separately by Hermes's version lock, never copied
implicitly from propagated inputs.  No package code is imported or executed.
"""
import csv
import base64
import hashlib
from importlib.metadata import distributions
from pathlib import Path
import re
import shutil
import sys

def canonical(name):
    return re.sub(r'[-_.]+', '-', name).lower()

manifest, output = Path(sys.argv[1]), Path(sys.argv[2]).resolve()
site = output / 'lib/python3.12/site-packages'
site.mkdir(parents=True, exist_ok=True)
for line in manifest.read_text().splitlines():
    name, version, package = line.split('\t')
    source_site = Path(package) / 'lib/python3.12/site-packages'
    matches = [d for d in distributions(path=[str(source_site)])
               if canonical(d.metadata['Name']) == canonical(name)]
    if len(matches) != 1 or matches[0].version != version:
        raise ValueError('Source-built component identity mismatch: ' + name)
    distribution = matches[0]
    if any(canonical(d.metadata['Name']) == canonical(name)
           for d in distributions(path=[str(site)])):
        raise ValueError('Duplicate private Python distribution: ' + name)
    record = distribution.read_text('RECORD')
    if record is None:
        raise ValueError('Source-built wheel RECORD missing: ' + name)
    installed_files = []
    record_path = None
    for row in csv.reader(record.splitlines()):
        relative = Path(row[0])
        # CLI launchers are regenerated below to use the private interpreter.
        if '..' in relative.parts:
            if tuple(relative.parts[:3]) == ('..', '..', '..') and relative.parts[3:4] == ('bin',):
                continue
            raise ValueError('Unexpected wheel path outside site-packages: ' + row[0])
        if relative.is_absolute():
            raise ValueError('Absolute wheel path: ' + row[0])
        if str(relative).endswith('.dist-info/RECORD'):
            record_path = relative
            continue
        source, target = source_site / relative, site / relative
        if target.exists():
            raise ValueError('Component file collision: ' + str(target))
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        installed_files.append(relative)
    for entry in distribution.entry_points:
        if entry.group != 'console_scripts':
            continue
        if '/' in entry.name or entry.name in ('.', '..'):
            raise ValueError('Invalid console entry point: ' + entry.name)
        module, attribute = entry.value.split(':', 1)
        attribute = attribute.split('[', 1)[0].strip()
        if not all(p.isidentifier() for p in module.split('.') + attribute.split('.')):
            raise ValueError('Unsupported console entry point: ' + entry.value)
        launcher = output / 'bin' / entry.name
        if launcher.exists():
            raise ValueError('Console entry point collision: ' + entry.name)
        launcher.parent.mkdir(parents=True, exist_ok=True)
        launcher.write_text('#!' + str(output / 'bin/hermes-python') + '\n'
                            'import importlib, sys\n'
                            f'function = importlib.import_module({module!r})\n'
                            f'for part in {attribute.split(".")!r}: function = getattr(function, part)\n'
                            'sys.exit(function())\n')
        launcher.chmod(0o755)
        installed_files.append(Path('../../../bin') / entry.name)
    if record_path is None:
        raise ValueError('Distribution RECORD path missing: ' + name)
    # Guix stripping and regenerated launchers can change wheel file hashes.
    # Record the installed private distribution, rather than stale input hashes.
    with (site / record_path).open('w', newline='') as target:
        writer = csv.writer(target)
        for relative in installed_files:
            data = (site / relative).read_bytes()
            digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b'=').decode()
            writer.writerow((str(relative), 'sha256=' + digest, len(data)))
        writer.writerow((str(record_path), '', ''))
    print('Imported exact source-built component: ' + name + '==' + version)
