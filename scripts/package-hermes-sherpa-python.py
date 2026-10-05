#!/usr/bin/env python3
"""Package a locally compiled Sherpa binding using upstream setup metadata."""
from pathlib import Path
from email.parser import BytesParser
import os
import shutil
import subprocess
import sys
import zipfile

root = Path(sys.argv[1]).resolve()
extension = Path(sys.argv[2]).resolve()
output = Path(sys.argv[3]).resolve()
if not extension.is_file() or not extension.name.startswith('_sherpa_onnx'):
    raise ValueError('Expected the locally compiled Sherpa Python extension')
setup = root / 'setup.py'
text = setup.read_text()
anchor = 'setuptools.setup('
if text.count(anchor) != 1:
    raise ValueError('Unexpected upstream Python package metadata layout')
# CMake has already built the module with reviewed Guix inputs. Preserve
# upstream metadata and wheel tagging, replacing only redundant compilation.
replacement = '''from setuptools.command.build_ext import build_ext
import shutil
class GuixBuildExtension(build_ext):
    def build_extension(self, ext):
        destination = Path(self.build_lib) / "sherpa_onnx" / "lib"
        destination.mkdir(parents=True, exist_ok=True)
        shutil.copy2(os.environ["GUIX_SHERPA_PYTHON_EXTENSION"], destination)
BuildExtension = GuixBuildExtension
setuptools.setup('''
setup.write_text(text.replace(anchor, replacement))
environment = os.environ.copy()
environment['GUIX_SHERPA_PYTHON_EXTENSION'] = str(extension)
# CLI files are installed by the engine's CMake installation. The Python
# wheel supplies sherpa-onnx-cli through upstream entry_points instead.
environment['SHERPA_ONNX_CMAKE_ARGS'] = '-DSHERPA_ONNX_ENABLE_BINARY=OFF'
environment.pop('SHERPA_ONNX_SPLIT_PYTHON_PACKAGE', None)
environment.pop('SHERPA_ONNX_IS_FOR_PYPI', None)
subprocess.run([sys.executable, 'setup.py', 'bdist_wheel'], cwd=root,
               env=environment, check=True)
wheels = list((root / 'dist').glob('*.whl'))
if len(wheels) != 1:
    raise ValueError('Expected one locally built Sherpa wheel')
with zipfile.ZipFile(wheels[0]) as wheel:
    members = wheel.namelist()
    extension_path = 'sherpa_onnx/lib/' + extension.name
    if members.count(extension_path) != 1:
        raise ValueError('Locally compiled extension missing from wheel')
    if wheel.read(extension_path) != extension.read_bytes():
        raise ValueError('Packaged extension differs from the CMake output')
    metadata_paths = [p for p in members if p.endswith('.dist-info/METADATA')]
    if len(metadata_paths) != 1:
        raise ValueError('Expected one upstream package metadata record')
    metadata = BytesParser().parsebytes(wheel.read(metadata_paths[0]))
    if metadata['Name'].replace('_', '-') != 'sherpa-onnx' or metadata['Version'] != '1.13.4':
        raise ValueError('Unexpected Sherpa Python package identity')
    if not any(p.endswith('.dist-info/entry_points.txt') for p in members):
        raise ValueError('Upstream Python CLI entry points missing')
subprocess.run([sys.executable, '-m', 'installer', '--prefix', str(output),
                str(wheels[0])], check=True)
