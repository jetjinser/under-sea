"""Build Hermes and its locked runtime from source inside the Guix sandbox."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import re
import subprocess
import sys
import tarfile
import tomllib

out = Path(sys.argv[1])
work = Path.cwd()
site = out / 'lib/python3.12/site-packages'
site.mkdir(parents=True, exist_ok=True)
os.environ['PYTHONPATH'] = str(site) + os.pathsep + os.environ.get('GUIX_PYTHONPATH', os.environ.get('PYTHONPATH', ''))
os.environ.update(CARGO_NET_OFFLINE='true', CARGO_BUILD_JOBS=os.environ.get('NIX_BUILD_CORES', '4'), HERMES_NIX_BUILD='1', PYTHONNOUSERSITE='1')
# Guix's GNU build system uses epoch 1; ZIP-based Python build backends require
# the DOS epoch or later. Keep the timestamp deterministic for every wheel.
os.environ['SOURCE_DATE_EPOCH'] = '315532800'
os.environ['CC'] = shutil.which('gcc')
os.environ['CXX'] = shutil.which('g++')
os.environ['AR'] = shutil.which('ar')


def unpack(archive, destination):
    destination.mkdir(parents=True, exist_ok=True)
    with tarfile.open(archive) as tar:
        tar.extractall(destination, filter='data')
    roots = list(destination.iterdir())
    if len(roots) != 1 or not roots[0].is_dir():
        raise ValueError(f'Unexpected source layout: {archive}')
    return roots[0]

vendor = work / 'rust-vendor'
vendor.mkdir()
for line in (work / 'crate-sources.tsv').read_text().splitlines():
    name, checksum, archive = line.split('\t')
    root = unpack(archive, work / 'crate-unpack' / name)
    dest = vendor / name
    shutil.move(root, dest)
    files = {str(file.relative_to(dest)): hashlib.sha256(file.read_bytes()).hexdigest()
             for file in dest.rglob('*') if file.is_file() and file.name != '.cargo-checksum.json'}
    (dest / '.cargo-checksum.json').write_text(json.dumps({'package': checksum, 'files': files}, sort_keys=True))
cargo = work / 'cargo-home'
cargo.mkdir()
(cargo / 'config.toml').write_text('[source.crates-io]\nreplace-with = "vendored-sources"\n[source.vendored-sources]\ndirectory = ' + json.dumps(str(vendor)) + '\n[net]\noffline = true\n')
os.environ['CARGO_HOME'] = str(cargo)
os.environ['CARGO_TARGET_DIR'] = str(work / 'cargo-target')
os.environ['RUSTFLAGS'] = (os.environ.get('RUSTFLAGS', '') +
                          f' --remap-path-prefix={work}=/usr/src/hermes-agent' +
                          f' -C linker={os.environ["CC"]}').strip()
# Guix records the actual store libraries as runtime references. Do not bundle
# copies of system libraries to produce a manylinux wheel.
os.environ['MATURIN_PEP517_ARGS'] = '--offline --locked --auditwheel skip'
# gfortran is needed by SciPy, but its additional C++ header tree conflicts
# with the native GCC driver's own standard headers via include_next (fenv.h).
# Retain its compiler and libraries; C/C++ use their selected driver's headers.
for variable in ('CPATH', 'CPLUS_INCLUDE_PATH', 'OBJCPLUS_INCLUDE_PATH'):
    if variable in os.environ:
        os.environ[variable] = os.pathsep.join(
            path for path in os.environ[variable].split(os.pathsep)
            if not re.search(r'/[^/]*-gfortran-[^/]+/include/c\+\+(?:/|$)', path))

git_roots = {}
git_table = work / 'git-sources.tsv'
if git_table.exists():
    for line in git_table.read_text().splitlines():
        identity, name, archive = line.split('\t')
        git_roots[identity] = (name, unpack(archive, work / 'git-unpack' / name))


def build(source, name):
    lock = source / 'Cargo.lock'
    if lock.exists():
        def registry_identities():
            return {(pkg['name'], pkg['version'], pkg['source'], pkg['checksum'])
                    for pkg in tomllib.loads(lock.read_text())['package']
                    if pkg.get('source', '').startswith('registry+')}
        original = registry_identities()
        # Replace only exact reviewed Git revisions, retaining the locked
        # registry identities. The source origin authenticates Git contents.
        for manifest_file in source.rglob('Cargo.toml'):
            contents = manifest_file.read_text()
            for identity, (git_name, git_root) in git_roots.items():
                repo, revision = identity.removeprefix('git+').split('#', 1)
                repo = repo.split('?', 1)[0]
                pattern = (r'(?m)^(' + re.escape(git_name) +
                           r'\s*=\s*)\{([^\n]*)\}')
                def replace_git(match):
                    spec = tomllib.loads('dependency = {' + match.group(2) + '}')['dependency']
                    if spec.get('git') != repo or spec.get('rev') != revision:
                        return match.group(0)
                    spec.pop('git'); spec.pop('rev')
                    spec['path'] = str(git_root)
                    def value(item):
                        return json.dumps(item)  # TOML accepts these string/bool/array literals.
                    return match.group(1) + '{' + ', '.join(k + ' = ' + value(v) for k, v in spec.items()) + '}'
                contents = re.sub(pattern, replace_git, contents)
            manifest_file.write_text(contents)
        project = tomllib.loads((source / 'pyproject.toml').read_text())
        manifest = source / project.get('tool', {}).get('maturin', {}).get('manifest-path', 'Cargo.toml')
        # Published sdists can omit Node/Wasm/CLI workspace members that are
        # still present in Cargo.lock. Prune those offline; never introduce or
        # repin a registry dependency. The actual compilation remains --locked.
        subprocess.run(['cargo', 'metadata', '--offline', '--manifest-path', str(manifest), '--format-version', '1'],
                       stdout=subprocess.DEVNULL, check=True)
        if not registry_identities() <= original:
            raise ValueError(f'Offline lock normalization changed registry pins: {name}')
    wheels = work / 'built-wheels' / name
    wheels.mkdir(parents=True, exist_ok=True)
    print(f'Building {name} from {source}', flush=True)
    build_env = os.environ.copy()
    pyproject = source / 'pyproject.toml'
    project_metadata = tomllib.loads(pyproject.read_text()) if pyproject.exists() else {}
    hatch = project_metadata.get('tool', {}).get('hatch', {})
    needs_uv_plugin = (
        hatch.get('version', {}).get('source') == 'uv-dynamic-versioning'
        or 'uv-dynamic-versioning' in hatch.get('metadata', {}).get('hooks', {}))
    if not needs_uv_plugin:
        # Hatch eagerly loads every installed plugin. Loading the version
        # plugin while building Pydantic itself would mix Guix's Pydantic
        # with the just-built, differently pinned private pydantic-core.
        for variable in ('PYTHONPATH', 'GUIX_PYTHONPATH'):
            if variable in build_env:
                build_env[variable] = os.pathsep.join(
                    path for path in build_env[variable].split(os.pathsep)
                    if 'python-hermes-uv-dynamic-versioning-' not in path)
    if name.startswith('microsoft-teams-'):
        build_env['GUIX_PROJECT_VERSION'] = versions[name]
    if name == 'pynacl':
        # The sdist's bundled libsodium lacks generated configure. Use the
        # explicit Guix source-built library through upstream's system mode.
        subprocess.run(['pkg-config', '--exists', 'libsodium'], check=True,
                       env=build_env)
        build_env['SODIUM_INSTALL'] = 'system'
    if name == 'python-olm':
        # Olm 3.2.16's bundled build requests CMake 3.4 policies, which
        # CMake 4 no longer accepts. Keep the exact bundled library source
        # and static binding; select the minimum supported policy version.
        builder = source / 'olm_build.py'
        text = builder.read_text()
        anchor = '["cmake", ".", "-Bbuild", "-DBUILD_SHARED_LIBS=NO"]'
        if text.count(anchor) != 1:
            raise ValueError('Unexpected python-olm bundled CMake invocation')
        builder.write_text(text.replace(
            anchor,
            '["cmake", ".", "-Bbuild", "-DBUILD_SHARED_LIBS=NO", '
            '"-DCMAKE_POLICY_VERSION_MINIMUM=3.5"]'))
    if name == 'uvloop':
        # Autoconf also invokes helpers through SHELL; patching configure's
        # shebang alone does not override its /bin/sh fallback.
        shell = shutil.which('sh')
        if not shell:
            raise ValueError('Missing build shell for bundled libuv')
        build_env.update(CONFIG_SHELL=shell, SHELL=shell)
    if name == 'sounddevice':
        library = build_env.get('HERMES_PORTAUDIO_LIBRARY')
        if not library or not Path(library).is_absolute() or not Path(library).is_file():
            raise ValueError('sounddevice requires an explicit source-built PortAudio library')
        module = source / 'src/sounddevice.py'
        text = module.read_text()
        anchor = '_libname = _find_library(_libname)'
        if text.count(anchor) != 1:
            raise ValueError('Unexpected sounddevice PortAudio discovery source')
        module.write_text(text.replace(anchor, '_libname = ' + repr(library)))
    if name == 'scikit-learn':
        # Meson invokes this version extractor directly during configuration;
        # /usr/bin/env is unavailable inside the Guix build container.
        extractor = source / 'sklearn/_build_utils/version.py'
        text = extractor.read_text()
        anchor = '#!/usr/bin/env python3\n'
        if not text.startswith(anchor):
            raise ValueError('Unexpected scikit-learn version extractor shebang')
        extractor.write_text('#!' + sys.executable + '\n' + text[len(anchor):])
        extractor.chmod(extractor.stat().st_mode | 0o100)
    if name == 'sentencepiece':
        # ENOENT also occurs when an existing script's /bin/sh interpreter is
        # unavailable in the Guix container. Keep the exact bundled core.
        script = source / 'build_bundled.sh'
        text = script.read_text()
        if not text.startswith('#!/bin/sh\n'):
            raise ValueError('Unexpected sentencepiece bundled build interpreter')
        if not (source / 'sentencepiece/src/CMakeLists.txt').is_file():
            raise ValueError('Complete offline sentencepiece core source required')
        shell = shutil.which('sh')
        if not shell:
            raise ValueError('Missing fixed shell for sentencepiece build')
        script.write_text('#!' + shell + '\n' + text[len('#!/bin/sh\n'):])
        script.chmod(script.stat().st_mode | 0o100)
        # The locked sdist already carries its complete, licensed Abseil source
        # tree.  Its CMake module nevertheless clones the same tag over the
        # network; use the vendored source in place, preserving the upstream
        # add_subdirectory and package layout.
        cmake = source / 'sentencepiece/CMakeLists.txt'
        text = cmake.read_text()
        anchor = '''if (SPM_ABSL_PROVIDER STREQUAL "module")
  include(FetchContent)
  FetchContent_Populate(abseil-cpp
        GIT_REPOSITORY  https://github.com/abseil/abseil-cpp.git
        SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/third_party/abseil-cpp
        GIT_PROGRESS TRUE
        GIT_TAG 20260526.0)
  add_subdirectory(third_party/abseil-cpp)'''
        replacement = '''if (SPM_ABSL_PROVIDER STREQUAL "module")
  add_subdirectory(third_party/abseil-cpp)'''
        if text.count(anchor) != 1:
            raise ValueError('Unexpected sentencepiece vendored Abseil CMake block')
        cmake.write_text(text.replace(anchor, replacement))
    subprocess.run([sys.executable, '-m', 'build', '--wheel', '--no-isolation', '--skip-dependency-check', '--outdir', str(wheels), str(source)], check=True, env=build_env)
    built = list(wheels.glob('*.whl'))
    if len(built) != 1: raise ValueError(f'Expected one locally built wheel for {name}')
    subprocess.run([sys.executable, '-m', 'installer', '--prefix', str(out), str(built[0])], check=True)

versions = {}
for line in (work / 'python-sources.tsv').read_text().splitlines():
    name, version, archive = line.split('\t')
    versions[name] = version
    root = unpack(archive, work / 'python-unpack' / name)
    if name == 'uvloop':
        # The locked sdist includes libuv's Autotools sources but no generated
        # configure script. Generate it offline before setup.py copies libuv.
        subprocess.run(['autoreconf', '-fiv'], cwd=root / 'vendor/libuv', check=True)
        # These scripts are generated after Guix's patch-shebang phase.
        # Executing configure with /bin/sh would report ENOENT in the sandbox.
        for script in (root / 'vendor/libuv').rglob('*'):
            if script.is_file():
                data = script.read_bytes()
                shebang = re.match(rb'^#![ \t]*/bin/sh\r?\n', data)
                if shebang:
                    mode = script.stat().st_mode & 0o777
                    # autoreconf may link helpers to read-only Guix inputs.
                    # Replace that link with a local generated-source copy.
                    if script.is_symlink():
                        script.unlink()
                    else:
                        # libtoolize --copy also preserves read-only modes.
                        script.chmod(mode | 0o200)
                    script.write_bytes(('#!' + shutil.which('sh') + '\n').encode()
                                       + data[shebang.end():])
                    script.chmod(mode | 0o200)
        # Upstream derives libuv's make parallelism from host CPU affinity,
        # ignoring Guix --cores. Keep it within the declared build budget.
        setup = root / 'setup.py'
        text = setup.read_text()
        anchor = "        j_flag = '-j{}'.format(njobs or 1)"
        if text.count(anchor) != 1:
            raise ValueError('Unexpected uvloop libuv parallelism configuration')
        setup.write_text(text.replace(anchor,
            "        njobs = min(njobs or 1, int(os.environ['NIX_BUILD_CORES']))\n"
            + anchor))
    if name == 'nemo-relay':
        for manifest in (root / 'Cargo.toml', root / 'crates/worker-proto/Cargo.toml'):
            text = manifest.read_text()
            text = re.sub(r'^protoc-bin-vendored[^\n]*\n', '', text, flags=re.M)
            manifest.write_text(text)
        script = root / 'crates/worker-proto/build.rs'
        script.write_text(script.read_text().replace('protoc_bin_vendored::protoc_bin_path()?', 'std::env::var("PROTOC")?'))
        lock = root / 'Cargo.lock'
        sections = lock.read_text().split('[[package]]')
        sections = [section for section in sections if not re.search(r'^name = "protoc-bin-vendored', section, re.M)]
        lock.write_text(re.sub(r'^ "protoc-bin-vendored[^\n]*\n', '', '[[package]]'.join(sections), flags=re.M))
        os.environ['PROTOC'] = shutil.which('protoc')
    build(root, name)

# Keep user configuration mutable while refusing in-place changes to store code.
config = work / 'hermes_cli/config.py'
text = config.read_text()
text = text.replace('frozenset({"apt", "docker",', 'frozenset({"guix", "apt", "docker",')
text = text.replace('    "docker": "docker pull', '    "guix": "Update the Guix package definition, then rebuild with guix time-machine -C channels.scm.",\n    "docker": "docker pull')
config.write_text(text)
contract = work / 'hermes_cli/update_contract.py'
text = contract.read_text().replace('if is_nix_install_method(method) or method == "apt":', 'if method == "guix":\n            return _refusal("guix", method)\n        if is_nix_install_method(method) or method == "apt":')
contract.write_text(text)
build(work, 'hermes-agent')
(site / '.install_method').write_text('guix\n')
(site / 'hermes-source-versions.json').write_text(json.dumps(versions, sort_keys=True))
# Dependency entry points belong to the private runtime. Expose ACP only when
# the selected source closure includes its SDK.
entrypoints = {'hermes', 'hermes-agent'}
if os.environ.get('HERMES_PACKAGE_ACP') == '1':
    entrypoints.add('hermes-acp')
for executable in (out / 'bin').iterdir():
    if executable.name not in entrypoints:
        executable.unlink()
