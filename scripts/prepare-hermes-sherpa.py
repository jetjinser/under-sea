#!/usr/bin/env python3
"""Prepare Sherpa source overrides and reject ONNX binary fallback."""
from pathlib import Path
import sys
import tarfile
import zipfile

root, manifest, destination = map(lambda p: Path(p).resolve(), sys.argv[1:4])
destination.mkdir(parents=True, exist_ok=True)
lines = ['# Reviewed local source archives.']
for line in manifest.read_text().splitlines():
    name, archive = line.split('\t')
    if not name or name in ('.', '..') or '/' in name:
        raise ValueError('Invalid source name: ' + name)
    target = destination / name
    target.mkdir()
    if zipfile.is_zipfile(archive):
        with zipfile.ZipFile(archive) as source:
            for member in source.infolist():
                path = Path(member.filename)
                if path.is_absolute() or '..' in path.parts:
                    raise ValueError('Unsafe ZIP path: ' + member.filename)
                if (member.external_attr >> 16) & 0o170000 == 0o120000:
                    raise ValueError('Unreviewed ZIP symlink: ' + member.filename)
            source.extractall(target)
    else:
        with tarfile.open(archive) as source:
            source.extractall(target, filter='data')
    roots = list(target.iterdir())
    if len(roots) != 1 or not roots[0].is_dir():
        raise ValueError('Expected one source root: ' + name)
    content = {'espeak-ng-for-piper': 'espeak_ng', 'hclust-cpp': 'hclust_cpp',
               'sonic': 'sonic-git'}.get(name, name.replace('-', '_')
                                      if name.startswith(('kaldi-', 'piper-')) else name)
    lines.append(f'set(FETCHCONTENT_SOURCE_DIR_{content.upper()} "{roots[0]}" CACHE PATH "" FORCE)')
lines.append('set(FETCHCONTENT_FULLY_DISCONNECTED ON CACHE BOOL "" FORCE)')
(destination / 'offline-cache.cmake').write_text('\n'.join(lines) + '\n')
runtime = root / 'cmake/onnxruntime.cmake'
text = runtime.read_text()
anchor = '  download_onnxruntime()'
if text.count(anchor) != 1:
    raise ValueError('Unexpected ONNX fallback layout')
runtime.write_text(text.replace(anchor,
    '  message(FATAL_ERROR "Guix source-built ONNX Runtime input is required")'))
print(destination / 'offline-cache.cmake')
