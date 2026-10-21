;;; Hermes CLI with an offline, source-built private Python runtime.
(define-module (under-sea packages hermes)
  #:export (make-hermes-package resolve-hermes-python-components)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 match)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages python-science)
  #:use-module (gnu packages rust)
  #:use-module (gnu packages build-tools)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages protobuf)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages libffi)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages xml)
  #:use-module (gnu packages image)
  #:use-module (gnu packages video)
  #:use-module (gnu packages audio)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages ssh)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages crypto)
  #:use-module (gnu packages maths)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages sqlite)
  #:use-module (gnu packages serialization)
  #:use-module (under-sea packages hermes-lock)
  #:use-module (under-sea packages hermes-build-tools)
  #:use-module ((under-sea packages hermes-interfaces-lock) #:prefix interfaces:)
  #:use-module ((under-sea packages hermes-integrations-lock) #:prefix integrations:))

(define-public python-for-hermes
  (package
    (inherit python)
    (name "python-for-hermes")
    (inputs (modify-inputs (package-inputs python)
              (replace "sqlite" sqlite-next)))
    (arguments
     (substitute-keyword-arguments (package-arguments python)
       ((#:tests? tests? #t) #f)))))

(define-public python-for-hermes-wrapper
  (package
    (inherit python-wrapper)
    (name "python-for-hermes-wrapper")
    (inputs (modify-inputs (package-inputs python-wrapper)
              (replace "bash" bash-minimal)))
    (propagated-inputs (list (list "python" python-for-hermes)))))

(define (resolve-hermes-python-components requirements)
  ;; Resolve exact recipe/output identities without introducing circular
  ;; imports from the Hermes factory into the native engine modules.
  (map (match-lambda
         ((name version module recipe output)
          (let ((provider
                 (module-ref
                  (resolve-interface
                   `(under-sea packages ,(string->symbol module)))
                  (string->symbol recipe))))
            (unless (and (package? provider)
                         (string=? version (package-version provider))
                         (member output (package-outputs provider)))
              (error "Hermes component recipe/version/output mismatch"
                     name version module recipe output))
            (list name version (gexp-input provider output)))))
       requirements))

;; Declarative rules mapping a locked Python source (by name) to the extra
;; build-time (native) or runtime inputs it requires.  This replaces a growing
;; set of ad-hoc (if (assoc NAME python-sources) ...) conditionals:
;;   python-uv-build       - sdists that use the uv_build backend
;;   python-meson          - NumPy (meson-python), independent of git sources
;;   python-setuptools-rust- tiktoken's Rust extension
;;   gfortran/python-pythran - SciPy's Fortran/Pythran kernels
;;   libsodium/portaudio/ffmpeg - PyNaCl/sounddevice/av runtime libraries
;;   zstd (out+lib)        - indexed-zstd/zstandard headers and shared library
;;   libxml2/libxslt       - lxml's C extension
(define %hermes-native-input-rules
  `((("narwhals" "portalocker" "runs") (,python-uv-build))
    (("numpy") (,python-meson))
    (("tiktoken") (,python-setuptools-rust))
    (("scipy") (,gfortran ,python-pythran))))

(define %hermes-runtime-input-rules
  `((("pynacl") (,libsodium))
    (("sounddevice") (,portaudio))
    (("av") (,ffmpeg))
    (("indexed-zstd" "zstandard") (,zstd (,zstd "lib")))
    (("lxml") (,libxml2 ,libxslt))))

(define (hermes-rule-inputs rules python-sources)
  "Return the inputs whose trigger names appear in PYTHON-SOURCES."
  (append-map (lambda (rule)
                (if (any (lambda (name) (assoc name python-sources)) (car rule))
                    (cadr rule)
                    '()))
              rules))

(define* (make-hermes-package package-name python-sources crate-sources interfaces? git-sources
                             #:optional (python-components '())
                             #:key (smoke? #f) (smoke-script? #t) (smoke-modules '()))
  (let ((source-names (map car python-sources))
        (component-names (map car python-components)))
    (unless (= (length component-names)
               (length (delete-duplicates component-names)))
      (error "Repeated independent Python component" component-names))
    (when (any (lambda (name) (member name source-names)) component-names)
      (error "Python component is also present in the sdist build list"
             component-names)))
  (package
    (name package-name)
    (version %hermes-version)
    (properties '((upstream-github "NousResearch/hermes-agent")))
    (source %hermes-source)
    (build-system gnu-build-system)
    (native-inputs
     (append
      (list rust (list rust "cargo") maturin pkg-config protobuf cmake-minimal
           python-for-hermes python-pypa-build python-installer
           python-setuptools python-wheel python-hatchling python-hatch-vcs
           python-hatch-fancy-pypi-readme python-flit-core python-setuptools-scm
           python-cython pybind11 python-pdm-backend python-poetry-core)
      (if interfaces? (list autoconf automake libtool python-expandvars python-pkgconfig
                            python-hermes-uv-dynamic-versioning) '())
      (hermes-rule-inputs %hermes-native-input-rules python-sources)
      (if (pair? git-sources) (list python-setuptools-rust python-meson
                                   python-hermes-coherent-licensed
                                   python-hermes-hatch-teams-build) '())))
    (inputs (append (list python-for-hermes openssl libffi zlib libjpeg-turbo libpng libtiff libwebp
                         libheif libyaml git openssh bash-minimal)
                    (if (pair? git-sources) (list olm openblas) '())
                    (hermes-rule-inputs %hermes-runtime-input-rules python-sources)))
    (arguments
     (list
      #:substitutable? #f
      ;; Run the installed smoke check when requested (see the 'smoke-check'
      ;; phase); disabled by default so component assembly stays cheap.
      #:tests? smoke?
      ;; Independent wheel components (for example Playwright's bundled Node
      ;; driver) ship their own runtime references that Guix cannot rewrite.
      #:validate-runpath? (null? python-components)
      #:modules '((guix build gnu-build-system) (guix build utils)
                  (ice-9 match) (srfi srfi-1))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (add-before 'build 'prepare-offline-inputs
            (lambda _
              (for-each
               (match-lambda
                 ((name entries)
                  (call-with-output-file name
                    (lambda (port)
                      (for-each
                       (match-lambda
                         ((a b source) (format port "~a\t~a\t~a~%" a b source)))
                       entries)))))
               (list (list "python-sources.tsv" '#$python-sources)
                     (list "crate-sources.tsv" '#$crate-sources)))
              (setenv "NIX_BUILD_CORES" (number->string (min 4 (parallel-job-count))))
              (when #$(and (assoc "sounddevice" python-sources) #t)
                (setenv "HERMES_PORTAUDIO_LIBRARY"
                        #$(and (assoc "sounddevice" python-sources)
                               (file-append portaudio "/lib/libportaudio.so"))))
              (call-with-output-file "git-sources.tsv"
                (lambda (port)
                  (for-each
                   (match-lambda
                     ((identity name source)
                      (format port "~a\t~a\t~a~%" identity name source)))
                   '#$git-sources)))
              (when #$interfaces? (setenv "HERMES_PACKAGE_ACP" "1"))
              (setenv "HERMES_DISABLE_LAZY_INSTALLS" "1")))
          (replace 'build
            (lambda _
              (unless (null? '#$python-components)
                (call-with-output-file "python-components.tsv"
                  (lambda (port)
                    (for-each
                     (match-lambda
                       ((name version output)
                        (format port "~a\t~a\t~a~%" name version output)))
                     '#$python-components)))
                (invoke #$(file-append python-for-hermes "/bin/python3")
                        #$(plain-file "import-hermes-python-components.py" "#!/usr/bin/env python3\n\"\"\"Copy exact source-built Python distributions into Hermes's private site.\n\nThe TSV contains distribution name, locked version and a Guix package output.\nDependencies are supplied separately by Hermes's version lock, never copied\nimplicitly from propagated inputs.  No package code is imported or executed.\n\"\"\"\nimport csv\nimport base64\nimport hashlib\nfrom importlib.metadata import distributions\nfrom pathlib import Path\nimport re\nimport shutil\nimport sys\n\ndef canonical(name):\n    return re.sub(r'[-_.]+', '-', name).lower()\n\nmanifest, output = Path(sys.argv[1]), Path(sys.argv[2]).resolve()\nsite = output / 'lib/python3.12/site-packages'\nsite.mkdir(parents=True, exist_ok=True)\nfor line in manifest.read_text().splitlines():\n    name, version, package = line.split('\\t')\n    source_site = Path(package) / 'lib/python3.12/site-packages'\n    matches = [d for d in distributions(path=[str(source_site)])\n               if canonical(d.metadata['Name']) == canonical(name)]\n    if len(matches) != 1 or matches[0].version != version:\n        raise ValueError('Source-built component identity mismatch: ' + name)\n    distribution = matches[0]\n    if any(canonical(d.metadata['Name']) == canonical(name)\n           for d in distributions(path=[str(site)])):\n        raise ValueError('Duplicate private Python distribution: ' + name)\n    record = distribution.read_text('RECORD')\n    installed_files = []\n    if record is None:\n        # Source-built Guix packages (for example PySide6) install without a\n        # RECORD; enumerate via top_level.txt, or the whole site-packages when\n        # it holds only this distribution.\n        dist_info = Path(distribution._path).name\n        record_path = Path(dist_info) / 'RECORD'\n        top = distribution.read_text('top_level.txt')\n        if top is None:\n            # Fall back to the distribution's own directory (the convention for\n            # PySide6/shiboken6), ignoring any sibling distributions.\n            top = distribution.metadata['Name']\n        relative_files = []\n        for root in [n.strip() for n in top.splitlines() if n.strip()] + [dist_info]:\n            base = source_site / root\n            if base.is_dir():\n                relative_files += [p.relative_to(source_site)\n                                   for p in base.rglob('*') if p.is_file()]\n            elif base.is_file():\n                relative_files.append(Path(root))\n    else:\n        record_path = None\n        relative_files = []\n        for row in csv.reader(record.splitlines()):\n            relative = Path(row[0])\n            # CLI launchers are regenerated below to use the private interpreter.\n            if '..' in relative.parts:\n                if tuple(relative.parts[:3]) == ('..', '..', '..') and relative.parts[3:4] == ('bin',):\n                    continue\n                raise ValueError('Unexpected wheel path outside site-packages: ' + row[0])\n            if relative.is_absolute():\n                raise ValueError('Absolute wheel path: ' + row[0])\n            if str(relative).endswith('.dist-info/RECORD'):\n                record_path = relative\n                continue\n            relative_files.append(relative)\n    for relative in relative_files:\n        source, target = source_site / relative, site / relative\n        if target.exists():\n            raise ValueError('Component file collision: ' + str(target))\n        target.parent.mkdir(parents=True, exist_ok=True)\n        shutil.copy2(source, target)\n        installed_files.append(relative)\n    for entry in distribution.entry_points:\n        if entry.group != 'console_scripts':\n            continue\n        if '/' in entry.name or entry.name in ('.', '..'):\n            raise ValueError('Invalid console entry point: ' + entry.name)\n        module, attribute = entry.value.split(':', 1)\n        attribute = attribute.split('[', 1)[0].strip()\n        if not all(p.isidentifier() for p in module.split('.') + attribute.split('.')):\n            raise ValueError('Unsupported console entry point: ' + entry.value)\n        launcher = output / 'bin' / entry.name\n        if launcher.exists():\n            raise ValueError('Console entry point collision: ' + entry.name)\n        launcher.parent.mkdir(parents=True, exist_ok=True)\n        launcher.write_text('#!' + str(output / 'bin/hermes-python') + '\\n'\n                            'import importlib, sys\\n'\n                            f'function = importlib.import_module({module!r})\\n'\n                            f'for part in {attribute.split(\".\")!r}: function = getattr(function, part)\\n'\n                            'sys.exit(function())\\n')\n        launcher.chmod(0o755)\n        installed_files.append(Path('../../../bin') / entry.name)\n    if record_path is None:\n        raise ValueError('Distribution RECORD path missing: ' + name)\n    # Guix stripping and regenerated launchers can change wheel file hashes.\n    # Record the installed private distribution, rather than stale input hashes.\n    with (site / record_path).open('w', newline='') as target:\n        writer = csv.writer(target)\n        for relative in installed_files:\n            data = (site / relative).read_bytes()\n            digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b'=').decode()\n            writer.writerow((str(relative), 'sha256=' + digest, len(data)))\n        writer.writerow((str(record_path), '', ''))\n    print('Imported exact source-built component: ' + name + '==' + version)\n")
                        "python-components.tsv" #$output))
              (invoke #$(file-append python-for-hermes "/bin/python3")
                      #$(plain-file "build-hermes.py" "\"\"\"Build Hermes and its locked runtime from source inside the Guix sandbox.\"\"\"\nimport hashlib\nimport json\nimport os\nfrom pathlib import Path\nimport shutil\nimport re\nimport subprocess\nimport sys\nimport tarfile\nimport tomllib\n\nout = Path(sys.argv[1])\nwork = Path.cwd()\nsite = out / 'lib/python3.12/site-packages'\nsite.mkdir(parents=True, exist_ok=True)\nos.environ['PYTHONPATH'] = str(site) + os.pathsep + os.environ.get('GUIX_PYTHONPATH', os.environ.get('PYTHONPATH', ''))\nos.environ.update(CARGO_NET_OFFLINE='true', CARGO_BUILD_JOBS=os.environ.get('NIX_BUILD_CORES', '4'), HERMES_NIX_BUILD='1', PYTHONNOUSERSITE='1')\n# Guix's GNU build system uses epoch 1; ZIP-based Python build backends require\n# the DOS epoch or later. Keep the timestamp deterministic for every wheel.\nos.environ['SOURCE_DATE_EPOCH'] = '315532800'\nos.environ['CC'] = shutil.which('gcc')\nos.environ['CXX'] = shutil.which('g++')\nos.environ['AR'] = shutil.which('ar')\n\n\ndef unpack(archive, destination):\n    destination.mkdir(parents=True, exist_ok=True)\n    with tarfile.open(archive) as tar:\n        tar.extractall(destination, filter='data')\n    roots = list(destination.iterdir())\n    if len(roots) != 1 or not roots[0].is_dir():\n        raise ValueError(f'Unexpected source layout: {archive}')\n    return roots[0]\n\nvendor = work / 'rust-vendor'\nvendor.mkdir()\nfor line in (work / 'crate-sources.tsv').read_text().splitlines():\n    name, checksum, archive = line.split('\\t')\n    root = unpack(archive, work / 'crate-unpack' / name)\n    dest = vendor / name\n    shutil.move(root, dest)\n    files = {str(file.relative_to(dest)): hashlib.sha256(file.read_bytes()).hexdigest()\n             for file in dest.rglob('*') if file.is_file() and file.name != '.cargo-checksum.json'}\n    (dest / '.cargo-checksum.json').write_text(json.dumps({'package': checksum, 'files': files}, sort_keys=True))\ncargo = work / 'cargo-home'\ncargo.mkdir()\n(cargo / 'config.toml').write_text('[source.crates-io]\\nreplace-with = \"vendored-sources\"\\n[source.vendored-sources]\\ndirectory = ' + json.dumps(str(vendor)) + '\\n[net]\\noffline = true\\n')\nos.environ['CARGO_HOME'] = str(cargo)\nos.environ['CARGO_TARGET_DIR'] = str(work / 'cargo-target')\nos.environ['RUSTFLAGS'] = (os.environ.get('RUSTFLAGS', '') +\n                          f' --remap-path-prefix={work}=/usr/src/hermes-agent' +\n                          f' -C linker={os.environ[\"CC\"]}').strip()\n# Guix records the actual store libraries as runtime references. Do not bundle\n# copies of system libraries to produce a manylinux wheel.\nos.environ['MATURIN_PEP517_ARGS'] = '--offline --locked --auditwheel skip'\n# gfortran is needed by SciPy, but its additional C++ header tree conflicts\n# with the native GCC driver's own standard headers via include_next (fenv.h).\n# Retain its compiler and libraries; C/C++ use their selected driver's headers.\nfor variable in ('CPATH', 'CPLUS_INCLUDE_PATH', 'OBJCPLUS_INCLUDE_PATH'):\n    if variable in os.environ:\n        os.environ[variable] = os.pathsep.join(\n            path for path in os.environ[variable].split(os.pathsep)\n            if not re.search(r'/[^/]*-gfortran-[^/]+/include/c\\+\\+(?:/|$)', path))\n\ngit_roots = {}\ngit_table = work / 'git-sources.tsv'\nif git_table.exists():\n    for line in git_table.read_text().splitlines():\n        identity, name, archive = line.split('\\t')\n        git_roots[identity] = (name, unpack(archive, work / 'git-unpack' / name))\n\n\ndef build(source, name):\n    lock = source / 'Cargo.lock'\n    # Some setuptools/Cython sdists (for example zstandard) ship a Cargo.lock\n    # for auxiliary tooling without building any Rust.  Only drive Cargo for\n    # sdists whose build backend actually compiles Rust.\n    project_file = source / 'pyproject.toml'\n    project = tomllib.loads(project_file.read_text()) if project_file.exists() else {}\n    build_system = project.get('build-system', {})\n    uses_rust = ('maturin' in build_system.get('build-backend', '')\n                 or any('setuptools-rust' in req\n                        for req in build_system.get('requires', [])))\n    if lock.exists() and uses_rust:\n        def registry_identities():\n            return {(pkg['name'], pkg['version'], pkg['source'], pkg['checksum'])\n                    for pkg in tomllib.loads(lock.read_text())['package']\n                    if pkg.get('source', '').startswith('registry+')}\n        original = registry_identities()\n        # Replace only exact reviewed Git revisions, retaining the locked\n        # registry identities. The source origin authenticates Git contents.\n        for manifest_file in source.rglob('Cargo.toml'):\n            contents = manifest_file.read_text()\n            for identity, (git_name, git_root) in git_roots.items():\n                repo, revision = identity.removeprefix('git+').split('#', 1)\n                repo = repo.split('?', 1)[0]\n                pattern = (r'(?m)^(' + re.escape(git_name) +\n                           r'\\s*=\\s*)\\{([^\\n]*)\\}')\n                def replace_git(match):\n                    spec = tomllib.loads('dependency = {' + match.group(2) + '}')['dependency']\n                    if spec.get('git') != repo or spec.get('rev') != revision:\n                        return match.group(0)\n                    spec.pop('git'); spec.pop('rev')\n                    spec['path'] = str(git_root)\n                    def value(item):\n                        return json.dumps(item)  # TOML accepts these string/bool/array literals.\n                    return match.group(1) + '{' + ', '.join(k + ' = ' + value(v) for k, v in spec.items()) + '}'\n                contents = re.sub(pattern, replace_git, contents)\n            manifest_file.write_text(contents)\n        project = tomllib.loads((source / 'pyproject.toml').read_text())\n        manifest = source / project.get('tool', {}).get('maturin', {}).get('manifest-path', 'Cargo.toml')\n        # Published sdists can omit Node/Wasm/CLI workspace members that are\n        # still present in Cargo.lock. Prune those offline; never introduce or\n        # repin a registry dependency. The actual compilation remains --locked.\n        subprocess.run(['cargo', 'metadata', '--offline', '--manifest-path', str(manifest), '--format-version', '1'],\n                       stdout=subprocess.DEVNULL, check=True)\n        if not registry_identities() <= original:\n            raise ValueError(f'Offline lock normalization changed registry pins: {name}')\n    wheels = work / 'built-wheels' / name\n    wheels.mkdir(parents=True, exist_ok=True)\n    print(f'Building {name} from {source}', flush=True)\n    build_env = os.environ.copy()\n    pyproject = source / 'pyproject.toml'\n    project_metadata = tomllib.loads(pyproject.read_text()) if pyproject.exists() else {}\n    hatch = project_metadata.get('tool', {}).get('hatch', {})\n    needs_uv_plugin = (\n        hatch.get('version', {}).get('source') == 'uv-dynamic-versioning'\n        or 'uv-dynamic-versioning' in hatch.get('metadata', {}).get('hooks', {}))\n    if not needs_uv_plugin:\n        # Hatch eagerly loads every installed plugin. Loading the version\n        # plugin while building Pydantic itself would mix Guix's Pydantic\n        # with the just-built, differently pinned private pydantic-core.\n        for variable in ('PYTHONPATH', 'GUIX_PYTHONPATH'):\n            if variable in build_env:\n                build_env[variable] = os.pathsep.join(\n                    path for path in build_env[variable].split(os.pathsep)\n                    if 'python-hermes-uv-dynamic-versioning-' not in path)\n    if name.startswith('microsoft-teams-'):\n        build_env['GUIX_PROJECT_VERSION'] = versions[name]\n    if name == 'pynacl':\n        # The sdist's bundled libsodium lacks generated configure. Use the\n        # explicit Guix source-built library through upstream's system mode.\n        subprocess.run(['pkg-config', '--exists', 'libsodium'], check=True,\n                       env=build_env)\n        build_env['SODIUM_INSTALL'] = 'system'\n    if name == 'python-olm':\n        # Olm 3.2.16's bundled build requests CMake 3.4 policies, which\n        # CMake 4 no longer accepts. Keep the exact bundled library source\n        # and static binding; select the minimum supported policy version.\n        builder = source / 'olm_build.py'\n        text = builder.read_text()\n        anchor = '[\"cmake\", \".\", \"-Bbuild\", \"-DBUILD_SHARED_LIBS=NO\"]'\n        if text.count(anchor) != 1:\n            raise ValueError('Unexpected python-olm bundled CMake invocation')\n        builder.write_text(text.replace(\n            anchor,\n            '[\"cmake\", \".\", \"-Bbuild\", \"-DBUILD_SHARED_LIBS=NO\", '\n            '\"-DCMAKE_POLICY_VERSION_MINIMUM=3.5\"]'))\n    if name == 'uvloop':\n        # Autoconf also invokes helpers through SHELL; patching configure's\n        # shebang alone does not override its /bin/sh fallback.\n        shell = shutil.which('sh')\n        if not shell:\n            raise ValueError('Missing build shell for bundled libuv')\n        build_env.update(CONFIG_SHELL=shell, SHELL=shell)\n    if name == 'sounddevice':\n        library = build_env.get('HERMES_PORTAUDIO_LIBRARY')\n        if not library or not Path(library).is_absolute() or not Path(library).is_file():\n            raise ValueError('sounddevice requires an explicit source-built PortAudio library')\n        module = source / 'src/sounddevice.py'\n        text = module.read_text()\n        anchor = '_libname = _find_library(_libname)'\n        if text.count(anchor) != 1:\n            raise ValueError('Unexpected sounddevice PortAudio discovery source')\n        module.write_text(text.replace(anchor, '_libname = ' + repr(library)))\n    if name == 'scikit-learn':\n        # Meson invokes this version extractor directly during configuration;\n        # /usr/bin/env is unavailable inside the Guix build container.\n        extractor = source / 'sklearn/_build_utils/version.py'\n        text = extractor.read_text()\n        anchor = '#!/usr/bin/env python3\\n'\n        if not text.startswith(anchor):\n            raise ValueError('Unexpected scikit-learn version extractor shebang')\n        extractor.write_text('#!' + sys.executable + '\\n' + text[len(anchor):])\n        extractor.chmod(extractor.stat().st_mode | 0o100)\n    if name == 'sentencepiece':\n        # ENOENT also occurs when an existing script's /bin/sh interpreter is\n        # unavailable in the Guix container. Keep the exact bundled core.\n        script = source / 'build_bundled.sh'\n        text = script.read_text()\n        if not text.startswith('#!/bin/sh\\n'):\n            raise ValueError('Unexpected sentencepiece bundled build interpreter')\n        if not (source / 'sentencepiece/src/CMakeLists.txt').is_file():\n            raise ValueError('Complete offline sentencepiece core source required')\n        shell = shutil.which('sh')\n        if not shell:\n            raise ValueError('Missing fixed shell for sentencepiece build')\n        script.write_text('#!' + shell + '\\n' + text[len('#!/bin/sh\\n'):])\n        script.chmod(script.stat().st_mode | 0o100)\n        # The locked sdist already carries its complete, licensed Abseil source\n        # tree.  Its CMake module nevertheless clones the same tag over the\n        # network; use the vendored source in place, preserving the upstream\n        # add_subdirectory and package layout.\n        cmake = source / 'sentencepiece/CMakeLists.txt'\n        text = cmake.read_text()\n        anchor = '''if (SPM_ABSL_PROVIDER STREQUAL \"module\")\n  include(FetchContent)\n  FetchContent_Populate(abseil-cpp\n        GIT_REPOSITORY  https://github.com/abseil/abseil-cpp.git\n        SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/third_party/abseil-cpp\n        GIT_PROGRESS TRUE\n        GIT_TAG 20260526.0)\n  add_subdirectory(third_party/abseil-cpp)'''\n        replacement = '''if (SPM_ABSL_PROVIDER STREQUAL \"module\")\n  add_subdirectory(third_party/abseil-cpp)'''\n        if text.count(anchor) != 1:\n            raise ValueError('Unexpected sentencepiece vendored Abseil CMake block')\n        cmake.write_text(text.replace(anchor, replacement))\n    subprocess.run([sys.executable, '-m', 'build', '--wheel', '--no-isolation', '--skip-dependency-check', '--outdir', str(wheels), str(source)], check=True, env=build_env)\n    built = list(wheels.glob('*.whl'))\n    if len(built) != 1: raise ValueError(f'Expected one locally built wheel for {name}')\n    subprocess.run([sys.executable, '-m', 'installer', '--prefix', str(out), str(built[0])], check=True)\n\nversions = {}\nfor line in (work / 'python-sources.tsv').read_text().splitlines():\n    name, version, archive = line.split('\\t')\n    versions[name] = version\n    root = unpack(archive, work / 'python-unpack' / name)\n    if name == 'uvloop':\n        # The locked sdist includes libuv's Autotools sources but no generated\n        # configure script. Generate it offline before setup.py copies libuv.\n        subprocess.run(['autoreconf', '-fiv'], cwd=root / 'vendor/libuv', check=True)\n        # These scripts are generated after Guix's patch-shebang phase.\n        # Executing configure with /bin/sh would report ENOENT in the sandbox.\n        for script in (root / 'vendor/libuv').rglob('*'):\n            if script.is_file():\n                data = script.read_bytes()\n                shebang = re.match(rb'^#![ \\t]*/bin/sh\\r?\\n', data)\n                if shebang:\n                    mode = script.stat().st_mode & 0o777\n                    # autoreconf may link helpers to read-only Guix inputs.\n                    # Replace that link with a local generated-source copy.\n                    if script.is_symlink():\n                        script.unlink()\n                    else:\n                        # libtoolize --copy also preserves read-only modes.\n                        script.chmod(mode | 0o200)\n                    script.write_bytes(('#!' + shutil.which('sh') + '\\n').encode()\n                                       + data[shebang.end():])\n                    script.chmod(mode | 0o200)\n        # Upstream derives libuv's make parallelism from host CPU affinity,\n        # ignoring Guix --cores. Keep it within the declared build budget.\n        setup = root / 'setup.py'\n        text = setup.read_text()\n        anchor = \"        j_flag = '-j{}'.format(njobs or 1)\"\n        if text.count(anchor) != 1:\n            raise ValueError('Unexpected uvloop libuv parallelism configuration')\n        setup.write_text(text.replace(anchor,\n            \"        njobs = min(njobs or 1, int(os.environ['NIX_BUILD_CORES']))\\n\"\n            + anchor))\n    if name == 'nemo-relay':\n        for manifest in (root / 'Cargo.toml', root / 'crates/worker-proto/Cargo.toml'):\n            text = manifest.read_text()\n            text = re.sub(r'^protoc-bin-vendored[^\\n]*\\n', '', text, flags=re.M)\n            manifest.write_text(text)\n        script = root / 'crates/worker-proto/build.rs'\n        script.write_text(script.read_text().replace('protoc_bin_vendored::protoc_bin_path()?', 'std::env::var(\"PROTOC\")?'))\n        lock = root / 'Cargo.lock'\n        sections = lock.read_text().split('[[package]]')\n        sections = [section for section in sections if not re.search(r'^name = \"protoc-bin-vendored', section, re.M)]\n        lock.write_text(re.sub(r'^ \"protoc-bin-vendored[^\\n]*\\n', '', '[[package]]'.join(sections), flags=re.M))\n        os.environ['PROTOC'] = shutil.which('protoc')\n    build(root, name)\n\n# Keep user configuration mutable while refusing in-place changes to store code.\nconfig = work / 'hermes_cli/config.py'\ntext = config.read_text()\ntext = text.replace('frozenset({\"apt\", \"docker\",', 'frozenset({\"guix\", \"apt\", \"docker\",')\ntext = text.replace('    \"docker\": \"docker pull', '    \"guix\": \"Update the Guix package definition, then rebuild with guix time-machine -C channels.scm.\",\\n    \"docker\": \"docker pull')\nconfig.write_text(text)\ncontract = work / 'hermes_cli/update_contract.py'\ntext = contract.read_text().replace('if is_nix_install_method(method) or method == \"apt\":', 'if method == \"guix\":\\n            return _refusal(\"guix\", method)\\n        if is_nix_install_method(method) or method == \"apt\":')\ncontract.write_text(text)\nbuild(work, 'hermes-agent')\n# The authored wheel omits the bundled wake-word models; install them beside the\n# tools package so the default \"hey hermes\" model resolves offline.\nwakewords_source = work / 'tools' / 'wakewords'\nif wakewords_source.is_dir():\n    wakewords_site = site / 'tools' / 'wakewords'\n    wakewords_site.mkdir(parents=True, exist_ok=True)\n    for model in wakewords_source.iterdir():\n        if model.is_file():\n            shutil.copy2(model, wakewords_site / model.name)\n(site / '.install_method').write_text('guix\\n')\n(site / 'hermes-source-versions.json').write_text(json.dumps(versions, sort_keys=True))\n# Dependency entry points belong to the private runtime. Expose ACP only when\n# the selected source closure includes its SDK.\nentrypoints = {'hermes', 'hermes-agent'}\nif os.environ.get('HERMES_PACKAGE_ACP') == '1':\n    entrypoints.add('hermes-acp')\nfor executable in (out / 'bin').iterdir():\n    if executable.name not in entrypoints:\n        executable.unlink()\n") #$output)
              (invoke "gcc" "-shared" "-fPIC" "-O2" "-Wall" "-Wextra"
                      "-Inative/fts5_cjk/vendor" "native/fts5_cjk/fts5_cjk.c"
                      "-o" "libfts5_cjk.so")))
          (delete 'check)
          (replace 'install
            (lambda _
              (let* ((share (string-append #$output "/share/hermes-agent"))
                     (site (string-append #$output "/lib/python3.12/site-packages")))
                (mkdir-p share)
                (for-each
                 (lambda (directory)
                   (copy-recursively directory (string-append share "/" directory)))
                 '("skills" "optional-skills" "plugins" "locales" "optional-mcps"))
                (install-file "LICENSE" (string-append #$output "/share/doc/hermes-agent"))
                (install-file "libfts5_cjk.so" (string-append share "/lib"))
                (symlink #$(file-append python-for-hermes "/bin/python3")
                         (string-append #$output "/bin/hermes-python"))
                (for-each
                 (lambda (program)
                   (apply wrap-program program
                     `(("PYTHONPATH" ":" prefix (,site))
                       ("GUIX_PYTHONPATH" ":" prefix (,site))
                       ("PYTHONNOUSERSITE" = ("1"))
                       ("HERMES_DISABLE_LAZY_INSTALLS" = ("1"))
                       ("HERMES_BIN" = (,(string-append #$output "/bin/hermes")))
                       ("HERMES_PYTHON" = (,(string-append #$output "/bin/hermes-python")))
                       ("HERMES_FTS5_CJK_SO" = (,(string-append share "/lib/libfts5_cjk.so")))
                       ("HERMES_BUNDLED_SKILLS" = (,(string-append share "/skills")))
                       ("HERMES_OPTIONAL_SKILLS" = (,(string-append share "/optional-skills")))
                       ("HERMES_BUNDLED_PLUGINS" = (,(string-append share "/plugins")))
                       ("HERMES_BUNDLED_LOCALES" = (,(string-append share "/locales")))
                       ("HERMES_OPTIONAL_MCPS" = (,(string-append share "/optional-mcps")))
                       ("PATH" ":" prefix
                        (,#$(file-append git "/bin") ,#$(file-append openssh "/bin")
                         ,#$(file-append bash-minimal "/bin"))))))
                 (find-files (string-append #$output "/bin") "^(hermes|hermes-agent|hermes-python|hermes-acp)$")))))
          (add-after 'install 'smoke-check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (setenv "HERMES_HOME" (string-append (getcwd) "/test-home"))
                (mkdir "installed-check")
                (with-directory-excursion "installed-check"
                  ;; The full Hermes CLI + import check applies to the general
                  ;; runtimes; specialised runtimes import their own modules.
                  (when #$smoke-script?
                    (invoke (string-append #$output "/bin/hermes") "--help")
                    (invoke (string-append #$output "/bin/hermes-python")
                            #$(plain-file "check-hermes.py" "\"\"\"Offline functional checks against the installed Hermes runtime.\"\"\"\nimport importlib.metadata\nimport json\nfrom pathlib import Path\nimport sqlite3\n\nimport anydoc\nimport jiter\nimport nemo_relay\nimport openai\nimport watchfiles\nfrom cryptography.hazmat.primitives.ciphers.aead import AESGCM\nfrom PIL import Image\nimport pillow_heif\nfrom pydantic import BaseModel, ValidationError\n\nsite = Path(importlib.metadata.distribution('hermes-agent').locate_file(''))\nfor name, version in json.loads((site / 'hermes-source-versions.json').read_text()).items():\n    assert importlib.metadata.version(name) == version, (name, version)\n\nclass Record(BaseModel):\n    number: int\nassert Record.model_validate_json('{\"number\":42}').number == 42\ntry:\n    Record.model_validate_json('{\"number\":\"invalid\"}')\nexcept ValidationError:\n    pass\nelse:\n    raise AssertionError('Pydantic accepted invalid input')\nassert jiter.from_json(b'{\"native\":true}') == {'native': True}\nkey = AESGCM.generate_key(bit_length=128)\ncipher = AESGCM(key)\nnonce = bytes(range(12))\nassert cipher.decrypt(nonce, cipher.encrypt(nonce, b'Guix Hermes', None), None) == b'Guix Hermes'\nimage = Image.new('RGB', (8, 8), color='red')\nimage.save('smoke.png')\nassert Image.open('smoke.png').size == (8, 8)\npillow_heif.register_heif_opener()\n\nfrom hermes_state_fts import load_fts5_cjk_extension\nconn = sqlite3.connect(':memory:')\nassert load_fts5_cjk_extension(conn)\nconn.execute(\"CREATE VIRTUAL TABLE texts USING fts5(body, tokenize='cjk_unicode61')\")\nconn.execute('INSERT INTO texts VALUES (?)', ('中文测试 Hermes',))\nassert conn.execute(\"SELECT count(*) FROM texts WHERE texts MATCH 'Hermes'\").fetchone()[0] == 1\nconn.close()\nfrom hermes_state import SessionDB\ndb = SessionDB()\nassert db._fts_cjk_loaded\ndb.close()\nfrom hermes_cli.config import detect_install_method, is_managed\nfrom hermes_cli.update_contract import evaluate_update_admission\nassert detect_install_method(site) == 'guix'\nassert not is_managed(), 'Package management must not lock user configuration'\nassert evaluate_update_admission(site).code == 'guix'\nfrom tools.environments.local import LocalEnvironment\nterminal = LocalEnvironment(cwd=str(Path.cwd()), timeout=10)\ntry:\n    result = terminal.execute(\"printf '%s' hermes-guix\")\n    assert result['returncode'] == 0 and 'hermes-guix' in result['output'], result\nfinally:\n    terminal.cleanup()\nprint('Locked versions, native extensions, FTS, database, terminal and Guix update guard OK')\n")))
                  (for-each
                   (lambda (module)
                     (invoke (string-append #$output "/bin/hermes-python") "-c"
                             (string-append "import " module)))
                   '#$smoke-modules))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/NousResearch/hermes-agent")
    (synopsis "CLI AI agent with persistent memory and extensible tools")
    (description (if interfaces?
                    "Hermes Agent provides a command-line AI assistant with MCP,
ACP, Google Workspace and dashboard backend dependencies built from source.
Node interfaces and other optional integrations are separate components."
                    "Hermes Agent provides a command-line AI assistant with persistent
memory, skills and local tools.  This package builds its locked core Python and
Rust dependencies from source.  Optional messaging, voice, web and Node user
interfaces are not included."))
    (license license:expat)))

(define-public hermes-agent
  (make-hermes-package "hermes-agent" %hermes-python-sources %hermes-crate-sources #f '()
                       #:smoke? #t))

(define-public hermes-agent-interfaces
  (make-hermes-package "hermes-agent-interfaces"
                       interfaces:%hermes-python-sources
                       interfaces:%hermes-crate-sources #t '()
                       #:smoke? #t))

(define-public hermes-agent-integrations
  (make-hermes-package "hermes-agent-integrations"
                       integrations:%hermes-python-sources
                       integrations:%hermes-crate-sources #t
                       integrations:%hermes-git-sources
                       #:smoke? #t))
