#!/usr/bin/env python3
"""Prepare local CMake source overrides from a reviewed name/archive TSV."""
from pathlib import Path
import sys
import tarfile

manifest = Path(sys.argv[1])
destination = Path(sys.argv[2]).resolve()
destination.mkdir(parents=True, exist_ok=True)
sources = {}
for line in manifest.read_text().splitlines():
    name, archive = line.split('\t')
    if not name or '/' in name or name in sources:
        raise ValueError('Invalid or repeated source name: ' + name)
    target = destination / name
    target.mkdir()
    with tarfile.open(archive) as source:
        # Python's data filter rejects traversal and links escaping the tree.
        source.extractall(target, filter='data')
    roots = list(target.iterdir())
    if len(roots) != 1 or not roots[0].is_dir():
        raise ValueError('Expected one source root: ' + name)
    sources[name] = roots[0]

lines = ['# Offline TFLite source inputs; generated from fixed Guix origins.']
for name, source in sorted(sources.items()):
    lines.append(f'set(FETCHCONTENT_SOURCE_DIR_{name.upper()} "{source}" CACHE PATH "" FORCE)')
for variable, name in [('CPUINFO', 'cpuinfo'), ('FP16', 'fp16_headers'),
                       ('FXDIV', 'fxdiv'), ('PTHREADPOOL', 'pthreadpool'),
                       ('PSIMD', 'psimd')]:
    lines.append(f'set({variable}_SOURCE_DIR "{sources[name]}" CACHE PATH "" FORCE)')
lines.append('set(FETCHCONTENT_FULLY_DISCONNECTED ON CACHE BOOL "" FORCE)')
for component in ('XNNPACK', 'PTHREADPOOL', 'FP16', 'FXDIV'):
    for category in ('TESTS', 'BENCHMARKS'):
        lines.append(f'set({component}_BUILD_{category} OFF CACHE BOOL "" FORCE)')
(destination / 'offline-cache.cmake').write_text('\n'.join(lines) + '\n')
print(destination / 'offline-cache.cmake')
