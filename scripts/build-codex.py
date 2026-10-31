#!/usr/bin/env python3
"""Prepare exact source inputs for an offline Codex Cargo build."""
import hashlib, json, os, re, shutil, subprocess, tarfile, tomllib
from pathlib import Path
from urllib.parse import urlsplit
root = Path.cwd(); work = root / 'guix-work'; work.mkdir()
workspace = root/'codex-rs'

def check_rusty_v8_submodules():
    supplemental = root/'v8-crate-sources.tsv'
    if supplemental.is_file() and any(
        line.split('\t', 1)[0].startswith('v8-')
        for line in supplemental.read_text().splitlines()):
        return
    for line in (root/'git-sources.tsv').read_text().splitlines():
        source, archive = line.split('\t')
        repo = urlsplit(source.removeprefix('git+')).path.rstrip('/').removesuffix('.git')
        if repo != '/seanh-oai/rusty_v8':
            continue
        with tarfile.open(archive) as tar:
            entries = tar.getmembers()
            root_name = entries[0].name.split('/')[0]
            config = tar.extractfile(root_name + '/.gitmodules')
            if config is None:
                raise SystemExit(
                    'Codex update blocked: the locked rusty_v8 source has no '
                    '.gitmodules file; source-build support needs manual review.')
            paths = re.findall(
                r'(?m)^\s*path\s*=\s*(\S+)\s*$',
                config.read().decode())
            files = {item.name for item in entries if item.isfile()}
        missing = [path for path in paths if not any(
            name.startswith(root_name + '/' + path.rstrip('/') + '/')
            for name in files)]
        if missing:
            raise SystemExit(
                'Codex update blocked during source-build preflight: the '
                'locked rusty_v8 Git archive omits contents for '
                f'{len(missing)} of {len(paths)} declared submodules:\n  '
                + '\n  '.join(missing) + '\n'
                'The current source lock pins only the parent Git commit. '
                'To support this release, recursively record each submodule '
                'gitlink commit and hash its source archive, then materialize '
                'those sources in the offline V8 tree. Retry with '
                '`make update PACKAGE=codex` after that support is added.')

if os.environ.get('V8_FROM_SOURCE') == '1':
    check_rusty_v8_submodules()

def unpack(archive, destination):
    destination.mkdir(parents=True)
    with tarfile.open(archive) as tar: tar.extractall(destination, filter='data')
    entries = list(destination.iterdir())
    assert len(entries)==1 and entries[0].is_dir(), archive
    return entries[0]

def prepare_v8(dest):
    script = dest / 'build.rs'
    text = script.read_text()
    if text.count('  download_rust_toolchain();') != 1:
        raise ValueError('Unexpected rusty_v8 toolchain downloader layout')
    text = text.replace('  download_rust_toolchain();',
                        '  // Guix supplies the exact declared Rust sysroot through GN_ARGS.')
    script.write_text(text)
    icu_data = dest / 'third_party/icu/common/icudtl.dat'
    icu_data.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(os.environ['GUIX_V8_ICU_DATA'], icu_data)
    clang_config = dest / 'build/config/clang/BUILD.gn'
    text = clang_config.read_text()
    anchor = '      libs = [ "$_clang_lib_dir/$_dir/$_lib_file" ]'
    if text.count(anchor) != 1:
        raise ValueError('Unexpected Chromium compiler runtime layout')
    runtime = os.environ['GUIX_V8_COMPILER_RT']
    text = text.replace(anchor, anchor + '\n' +
        '      if (is_linux && current_cpu == "x64" && _libname == "builtins") {\n' +
        '        libs = []\n' +
        '        libs = [ ' + json.dumps(runtime + '/lib/linux/libclang_rt.builtins-x86_64.a') + ' ]\n' +
        '      }')
    clang_config.write_text(text)
    toolchain = dest / 'build/toolchain/gcc_toolchain.gni'
    text = toolchain.read_text()
    anchor = '    ar = "${prefix}/llvm-ar"'
    if text.count(anchor) != 1:
        raise ValueError('Unexpected Chromium archiver layout')
    toolchain.write_text(text.replace(anchor,
        '    ar = ' + json.dumps(os.environ['GUIX_V8_LLVM_AR'])))
    # These dependency lists bypass rust_sysroot even when a custom
    # compiler was selected. Keep Ninja's tracked inputs consistent.
    for relative in ('build/config/rust.gni', 'build/rust/std/BUILD.gn',
                     'build/rust/cargo_crate.gni'):
        configuration = dest / relative
        text = configuration.read_text()
        if '//third_party/rust-toolchain/bin/rustc' not in text:
            raise ValueError('Unexpected Chromium Rust dependency layout')
        configuration.write_text(text.replace(
            '//third_party/rust-toolchain/bin/rustc', '${rust_sysroot}/bin/rustc'))
    std_config = dest / 'build/rust/std/BUILD.gn'
    text = std_config.read_text()
    anchor = '  skip_stdlib_files = [\n    "profiler_builtins",'
    if text.count(anchor) != 1:
        raise ValueError('Unexpected optional Rust profiler copy layout')
    # Guix Rust lacks the optional profiler runtime. The V8 release build
    # is not instrumented for coverage, so it does not consume this crate.
    text = text.replace(anchor, '  skip_stdlib_files = [')
    std_config.write_text(text)
    compiler_config = dest / 'build/config/compiler/BUILD.gn'
    text = compiler_config.read_text()
    anchor = '(is_linux && !is_clang)'
    if text.count(anchor) != 1:
        raise ValueError('Unexpected Chromium thin archive configuration')
    compiler_config.write_text(text.replace(
        anchor, '(is_linux && (!is_clang || !use_lld))'))
    # Chromium puts prebuilt Rust std archives in ldflags, before the
    # objects that need them. GNU ld needs one outer rescan group.
    toolchain = dest / 'build/toolchain/gcc_toolchain.gni'
    text = toolchain.read_text()
    anchor = '      link_command = "$ld {{ldflags}}${extra_ldflags} -o \\"$main_outfile\\" "'
    if text.count(anchor) != 1:
        raise ValueError('Unexpected Chromium executable linker layout')
    text = text.replace(anchor, anchor + '\n'
        '      if (is_linux && !use_lld) {\n'
        '        link_command = "$ld $start_group_flag {{ldflags}}${extra_ldflags} -o \\"$main_outfile\\" "\n'
        '      }')
    anchor = '      # Generate a map file to be used for binary size analysis.'
    if text.count(anchor) != 2:
        raise ValueError('Unexpected Chromium executable linker map layout')
    before, after = text.rsplit(anchor, 1)
    text = before + (
        '      if (is_linux && !use_lld) {\n'
        '        link_command += " $end_group_flag"\n'
        '      }\n\n' + anchor) + after
    toolchain.write_text(text)

def patch_rusty_v8_fork(dest):
    manifest = dest / 'Cargo.toml.orig'
    if not manifest.is_file():
        raise ValueError('rusty_v8 source snapshot has no original Cargo manifest')
    shutil.copyfile(manifest, dest / 'Cargo.toml')

    cppgc = dest / 'src/cppgc.rs'
    text = cppgc.read_text()
    member_anchor = ('      #[repr(transparent)]\n'
                     '      struct [< $name Inner >]([u8; crate::binding:: '
                     '[< cppgc__ $name _SIZE >]]);')
    member_patch = ('      #[repr(transparent)]\n'
                    '      struct [< $name Inner >](\n'
                    '        <[u8; crate::binding:: [< cppgc__ $name _SIZE >]] '
                    'as MemberStorage>::Aligned,\n'
                    '      );')
    if text.count(member_anchor) != 1 or 'trait MemberStorage {' in text:
        raise ValueError('Unexpected rusty_v8 cppgc member layout')
    member_macro = 'macro_rules! member {'
    if text.count(member_macro) != 1:
        raise ValueError('Unexpected rusty_v8 cppgc member macro layout')
    text = text.replace(
        member_macro,
        '// C++ stores a compressed uint32_t or an uncompressed pointer. The binding\n'
        '// size selects the alignment; MaybeUninit keeps the slot opaque to Rust.\n'
        'trait MemberStorage {\n'
        '  type Aligned;\n'
        '}\n\n'
        'impl MemberStorage for [u8; 4] {\n'
        '  type Aligned = std::mem::MaybeUninit<u32>;\n'
        '}\n'
        'impl MemberStorage for [u8; 8] {\n'
        '  type Aligned = std::mem::MaybeUninit<u64>;\n'
        '}\n\n'
        'macro_rules! member {')
    text = text.replace(member_anchor, member_patch)
    layout_tests = (
        '#[cfg(test)]\n'
        'mod member_layout_tests {\n'
        '  use super::*;\n'
        '  use std::mem::{align_of, size_of};\n\n'
        '  struct Node;\n\n'
        '  // SAFETY: Node owns no managed pointers.\n'
        '  unsafe impl GarbageCollected for Node {\n'
        '    fn trace(&self, _: &mut Visitor) {}\n'
        '    fn get_name(&self) -> &\'static CStr {\n'
        '      c"Node"\n'
        '    }\n'
        '  }\n\n'
        '  fn check<T>(cpp_size: usize) {\n'
        '    assert_eq!(size_of::<T>(), cpp_size);\n'
        '    assert_eq!(align_of::<T>(), cpp_size);\n'
        '  }\n\n'
        '  #[test]\n'
        '  fn cppgc_member_storage_matches_cpp_alignment() {\n'
        '    // Do not construct members: this must fail safely on a misaligned layout.\n'
        '    check::<MemberInner>(crate::binding::cppgc__Member_SIZE);\n'
        '    check::<WeakMemberInner>(crate::binding::cppgc__WeakMember_SIZE);\n'
        '    check::<Member<Node>>(crate::binding::cppgc__Member_SIZE);\n'
        '    check::<WeakMember<Node>>(crate::binding::cppgc__WeakMember_SIZE);\n'
        '  }\n'
        '}\n\n')
    enum_anchor = '  WeakMember\n}\n\nmacro_rules! persistent {'
    if text.count(enum_anchor) != 1:
        raise ValueError('Unexpected rusty_v8 cppgc member enum layout')
    cppgc.write_text(text.replace(
        enum_anchor, '  WeakMember\n}\n\n' + layout_tests + 'macro_rules! persistent {'))


vendor=work/'vendor'; vendor.mkdir()
for line in (root/'crate-sources.tsv').read_text().splitlines():
    name, checksum, archive = line.split('\t')
    dest=vendor/name; shutil.move(unpack(archive,work/'unpack'/name), dest)
    if name.startswith('v8-') and os.environ.get('V8_FROM_SOURCE') == '1':
        prepare_v8(dest)
    files={str(p.relative_to(dest)):hashlib.sha256(p.read_bytes()).hexdigest() for p in dest.rglob('*') if p.is_file() and p.name!='.cargo-checksum.json'}
    (dest/'.cargo-checksum.json').write_text(json.dumps({'package':checksum,'files':files},sort_keys=True))

if os.environ.get('V8_FROM_SOURCE') == '1':
    extra_vendor = work / 'v8-extra-vendor'
    for line in (root / 'v8-crate-sources.tsv').read_text().splitlines():
        name, checksum, archive = line.split('\t')
        if hashlib.sha256(Path(archive).read_bytes()).hexdigest() != checksum:
            raise ValueError('V8 extra crate checksum mismatch: ' + name)
        source = unpack(archive, work / 'v8-extra-unpack' / name)
        destination = extra_vendor / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(source, destination)
    v8_roots = list(vendor.glob('v8-*')) + list(extra_vendor.glob('v8-*'))
    if len(v8_roots) != 1:
        raise ValueError('Expected one locked rusty_v8 source')
    v8_root = v8_roots[0]
    if v8_root.parent == extra_vendor:
        prepare_v8(v8_root)
        patch_rusty_v8_fork(v8_root)
    for item in json.loads(Path(os.environ['GUIX_V8_RUST_INVENTORY']).read_text()):
        identity = item['name'] + '-' + item['version']
        source = (vendor if item['in_codex_lock'] else extra_vendor) / identity
        metadata = tomllib.loads((source / 'Cargo.toml').read_text())['package']
        if metadata['name'] != item['name'] or metadata['version'] != item['version']:
            raise ValueError('Chromium Rust source version mismatch: ' + identity)
        relative = Path(item['destination'])
        if relative.is_absolute() or '..' in relative.parts or not str(relative).startswith(
                'third_party/rust/chromium_crates_io/vendor/'):
            raise ValueError('Invalid Chromium vendor path')
        destination = v8_root / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(source, destination)
    checksum_file = v8_root / '.cargo-checksum.json'
    if checksum_file.exists():
        checksums = json.loads(checksum_file.read_text())
        checksums['files'] = {
            str(path.relative_to(v8_root)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in v8_root.rglob('*')
            if path.is_file() and path.name != '.cargo-checksum.json'}
        checksum_file.write_text(json.dumps(checksums, sort_keys=True))

# Keep Git packages as local path dependencies at their exact locked commits.
# Cargo resolves their original workspace manifests, retaining inherited metadata.
git_packages={}
for index,line in enumerate((root/'git-sources.tsv').read_text().splitlines()):
    source, archive=line.split('\t'); parsed=urlsplit(source.removeprefix('git+'))
    checkout=unpack(archive,work/'git'/str(index))
    key=parsed.path.removesuffix('.git').strip('/')
    for manifest in checkout.rglob('Cargo.toml'):
        try: data=tomllib.loads(manifest.read_text())
        except tomllib.TOMLDecodeError: continue
        if 'package' in data and 'name' in data['package']:
            name=data['package']['name']; package_root=manifest.parent
            if (os.environ.get('V8_FROM_SOURCE') == '1'
                and name == 'v8' and key.endswith('rusty_v8')):
                # The fixed Git archive omits submodule contents. The
                # hash-pinned crates.io source snapshot below carries those
                # exact gitlinks; restore the fork manifest and local patch.
                package_root=v8_root
            git_packages[(key,name)]=package_root

def replace_git(match):
    name, body=match.group(1),match.group(2)
    url=re.search(r'git\s*=\s*"([^"]+)"',body).group(1)
    key=urlsplit(url).path.removesuffix('.git').strip('/')
    package=re.search(r'package\s*=\s*"([^"]+)"',body)
    identity=(key,package.group(1) if package else name)
    # Unused examples and development manifests can name Git repositories
    # absent from upstream's lock. Leave them unchanged; offline Cargo will
    # reject any such dependency if it is actually needed by this workspace.
    if identity not in git_packages: return match.group(0)
    path=git_packages[identity]
    body=re.sub(r'(git|rev|branch|tag)\s*=\s*"[^"]+"\s*,?\s*','',body).strip().strip(',')
    return f'{name} = {{ path = {json.dumps(str(path))}' + (', '+body if body else '') + ' }'

def replace_git_section(match):
    header, section, body = match.groups()
    url=re.search(r'(?m)^git\s*=\s*"([^"]+)"',body)
    if not url: return match.group(0)
    key=urlsplit(url.group(1)).path.removesuffix('.git').strip('/')
    package=re.search(r'(?m)^package\s*=\s*"([^"]+)"',body)
    identity=(key, package.group(1) if package else section.rsplit('.',1)[-1])
    if identity not in git_packages: return match.group(0)
    body=re.sub(r'(?m)^(git|rev|branch|tag)\s*=\s*"[^\n]+\n','',body)
    return header+'path = '+json.dumps(str(git_packages[identity]))+'\n'+body

for manifest in list(workspace.rglob('Cargo.toml'))+list((work/'git').rglob('Cargo.toml')):
    text=manifest.read_text()
    text=re.sub(r'(?m)^[ \t]*([\w-]+)[ \t]*=[ \t]*\{([^}\n]*\bgit\s*=[^}\n]*)\}',replace_git,text)
    text=re.sub(r'(?ms)^(\[([^\]\n]+)\]\n)(.*?)(?=^\[|\Z)',replace_git_section,text)
    manifest.write_text(text)
# Remove source trees with non-source artifacts which are not needed by this CLI.
shutil.rmtree(workspace/'vendor/bubblewrap',ignore_errors=True)
manifest=workspace/'code-mode-protocol/Cargo.toml'
manifest.write_text(re.sub(r'^protoc-bin-vendored[^\n]*\n','',manifest.read_text(),flags=re.M))
build=workspace/'code-mode-protocol/build.rs'
build.write_text(build.read_text().replace('protoc_bin_vendored::protoc_bin_path()?',
                                         'std::env::var("PROTOC")?'))
p=workspace/'linux-sandbox/src/bwrap.rs'
p.write_text(p.read_text().replace('"/nix/store",','"/nix/store",\n    "/gnu/store",'))
config=workspace/'.cargo/config.toml'
config.write_text(config.read_text()+'\n[source.crates-io]\nreplace-with="guix-vendor"\n[source.guix-vendor]\ndirectory='+json.dumps(str(vendor))+'\n[net]\noffline=true\n')
# Normalize Git-to-path lock changes offline; assert registry identities unchanged.
lock=workspace/'Cargo.lock'
def registry():
    return {(p['name'],p['version'],p['source'],p['checksum']) for p in tomllib.loads(lock.read_text())['package'] if p.get('source','').startswith('registry+')}
before=registry()
subprocess.run(['cargo','metadata','--offline','--format-version','1'],cwd=workspace,stdout=subprocess.DEVNULL,check=True)
assert registry() <= before, 'Cargo introduced or changed a registry source'
print('Verified offline lock normalization with unchanged registry checksums',flush=True)
# An explicit opt-in catalog for this build, whose local V8 host is absent.
# Never change the user's config or the catalog compiled into the executable.
catalog=json.loads((workspace/'models-manager/models.json').read_text())
for model in catalog['models']:
    if model.get('tool_mode') in ('code_mode', 'code_mode_only'):
        model['tool_mode']='direct'
(workspace/'guix-models-direct.json').write_text(json.dumps(catalog,indent=2)+'\n')
