#!/usr/bin/env python3
"""Generate AutoValue's service resources from its authored annotations."""
import argparse
from collections import defaultdict
from pathlib import Path
import re
import shutil

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('classes', type=Path)
args = parser.parse_args()
services = defaultdict(list)
for file in sorted(args.source.rglob('*.java')):
    text = file.read_text()
    annotation = re.search(r'^@AutoService\((\w+)\.class\)', text, re.M)
    if annotation is None:
        continue
    service_name = annotation.group(1)
    imported = re.search(r'^import ([\w.]+\.' + service_name + r');', text, re.M)
    package = re.search(r'^package ([\w.]+);', text, re.M)
    implementation = re.search(r'^public (?:final |abstract )?class (\w+)', text, re.M)
    if not all((imported, package, implementation)):
        raise ValueError(f'Unexpected AutoService source syntax: {file}')
    services[imported.group(1)].append(package.group(1) + '.' + implementation.group(1))
expected = {
    'javax.annotation.processing.Processor': {
        'com.google.auto.value.processor.AutoAnnotationProcessor',
        'com.google.auto.value.processor.AutoOneOfProcessor',
        'com.google.auto.value.processor.AutoValueBuilderProcessor',
        'com.google.auto.value.processor.AutoValueProcessor',
        'com.google.auto.value.extension.memoized.processor.MemoizedValidator',
    },
    'com.google.auto.value.extension.AutoValueExtension': {
        'com.google.auto.value.extension.memoized.processor.MemoizeExtension',
    },
}
if {name: set(providers) for name, providers in services.items()} != expected:
    raise ValueError('AutoValue 1.6 service identities changed')
for service, providers in services.items():
    output = args.classes / 'META-INF/services' / service
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text('\n'.join(sorted(providers)) + '\n')
templates = list(args.source.rglob('*.vm'))
if len(templates) != 5:
    raise ValueError('Unexpected AutoValue template resources')
for file in templates + list(args.source.rglob('NOTICE')):
    destination = args.classes / file.relative_to(args.source)
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(file, destination)
print('Generated all six service registrations and five source templates')
