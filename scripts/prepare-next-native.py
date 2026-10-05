#!/usr/bin/env python3
"""Prepare Next's locked registry and Git sources for an offline SWC build."""
import argparse, hashlib, json, os, re, shutil, subprocess, tarfile, tomllib
from pathlib import Path
from urllib.parse import urlsplit
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('source',type=Path)
parser.add_argument('inputs',type=Path)
parser.add_argument('work',type=Path)
parser.add_argument('--source-commit',required=True)
parser.add_argument('--features',required=True)
parser.add_argument('--rust-patch',type=Path,
                    default=Path(__file__).with_name('patch-next-rust.py'))
parser.add_argument('--vendor-patch',type=Path,
                    default=Path(__file__).with_name('patch-next-vendor.py'))
args=parser.parse_args()
if not re.fullmatch(r'[0-9a-f]{40}',args.source_commit):
    raise ValueError('Expected exact upstream source commit')
features=sorted(args.features.split(','))
if not features or any(not re.fullmatch(r'[A-Za-z0-9_/-]+',feature) for feature in features):
    raise ValueError('Invalid native feature identity')
root=args.inputs.resolve()
work=args.work.resolve()
work.mkdir()
workspace=args.source.resolve()
rust_patch=args.rust_patch.resolve()
subprocess.run([os.sys.executable,str(rust_patch),str(workspace)],check=True)
def unpack(archive,destination):
    destination.mkdir(parents=True)
    with tarfile.open(archive) as tar:tar.extractall(destination,filter='data')
    entries=list(destination.iterdir())
    if len(entries)!=1 or not entries[0].is_dir():raise ValueError('Unexpected source root: '+archive)
    return entries[0]
vendor=work/'vendor'
vendor.mkdir()
for line in (root/'crate-sources.tsv').read_text().splitlines():
    name,checksum,archive=line.split('\t')
    if hashlib.sha256(Path(archive).read_bytes()).hexdigest()!=checksum:
        raise ValueError('Registry checksum mismatch: '+name)
    destination=vendor/name
    shutil.move(unpack(archive,work/'unpack'/name),destination)
    files={str(p.relative_to(destination)):hashlib.sha256(p.read_bytes()).hexdigest()
           for p in destination.rglob('*') if p.is_file() and p.name!='.cargo-checksum.json'}
    (destination/'.cargo-checksum.json').write_text(json.dumps({'package':checksum,'files':files},sort_keys=True))
vendor_patch=args.vendor_patch.resolve()
subprocess.run([os.sys.executable,str(vendor_patch),str(vendor)],check=True)
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
        if 'package' in data and 'name' in data['package']: git_packages[(key,data['package']['name'])]=manifest.parent

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

manifests=[manifest for manifest in workspace.rglob('Cargo.toml')
           if not manifest.is_relative_to(work)]
for manifest in manifests+list((work/'git').rglob('Cargo.toml')):
    text=manifest.read_text()
    text=re.sub(r'(?m)^[ \t]*([\w-]+)[ \t]*=[ \t]*\{([^}\n]*\bgit\s*=[^}\n]*)\}',replace_git,text)
    text=re.sub(r'(?ms)^(\[([^\]\n]+)\]\n)(.*?)(?=^\[|\Z)',replace_git_section,text)
    manifest.write_text(text)

config=workspace/'.cargo/config.toml'
config.parent.mkdir(exist_ok=True)
previous=config.read_text() if config.exists() else ''
for original,replacement in (
    ('-Clinker-flavor=gnu-lld-cc','-Clinker-flavor=gnu-cc'),
    ('-Clink-self-contained=+linker','-Clink-self-contained=-linker'),
):
    if previous.count(original)!=1:
        raise ValueError('Unexpected Next Linux linker configuration: '+original)
    previous=previous.replace(original,replacement)
if '-Zthreads=8' not in previous:
    raise ValueError('Unexpected Next compiler thread configuration')
previous=previous.replace('-Zthreads=8','-Zthreads=2')
config.write_text(previous+'\n[source.crates-io]\nreplace-with="guix-vendor"\n[source.guix-vendor]\ndirectory='+json.dumps(str(vendor))+'\n[net]\noffline=true\n')
# Archives lack a Git worktree. Use a deterministic identity for the patched
# source instead of fabricating a repository or reporting it as clean.
fingerprint=hashlib.sha256()
fingerprint.update(args.source_commit.encode())
fingerprint.update(Path(__file__).read_bytes())
fingerprint.update(rust_patch.read_bytes())
fingerprint.update(vendor_patch.read_bytes())
fingerprint.update(previous.encode())
build_configuration={
    'features':features,'profile':'release',
    'rustc':subprocess.check_output(['rustc','--version','--verbose'],text=True).strip(),
    'target':os.environ.get('CARGO_BUILD_TARGET','host'),
    'profile_overrides':{key:value for key,value in os.environ.items()
                         if key.startswith('CARGO_PROFILE_RELEASE_')},
}
fingerprint.update(json.dumps(build_configuration,sort_keys=True).encode())
for line in (root/'crate-sources.tsv').read_text().splitlines():
    name,checksum,_=line.split('\t')
    fingerprint.update((name+'\t'+checksum+'\n').encode())
for line in (root/'git-sources.tsv').read_text().splitlines():
    identity,archive=line.split('\t')
    fingerprint.update(identity.encode())
    fingerprint.update(hashlib.sha256(Path(archive).read_bytes()).digest())
describe=args.source_commit+'-guix-'+fingerprint.hexdigest()
build_script=workspace/'crates/napi/build.rs'
text=build_script.read_text()
start='    let git = vergen_gitcl::GitclBuilder::default()'
end='    match Command::new("git").args(["rev-parse", "HEAD"]).output() {'
if text.count(start)!=1 or text.count(end)!=1:
    raise ValueError('Unexpected Next Git metadata build source')
before,rest=text.split(start)
_,after=rest.split(end)
replacement=('    vergen_gitcl::Emitter::default().add_instructions(&cargo)?.fail_on_error().emit()?;\n'
             '    println!("cargo:rustc-env=VERGEN_GIT_DIRTY=true");\n'
             '    println!("cargo:rustc-env=VERGEN_GIT_DESCRIBE='+describe+'");\n\n')
build_script.write_text(before+replacement+end+after)
(work/'source-identity.json').write_text(json.dumps({
    'upstream_commit':args.source_commit,'patched_source_identity':describe,
    'dirty':True,'build_configuration':build_configuration},indent=2)+'\n')
lock=workspace/'Cargo.lock'
def registry():
    return {(p['name'],p['version'],p['source'],p['checksum']) for p in tomllib.loads(lock.read_text())['package'] if p.get('source','').startswith('registry+')}
before=registry()
subprocess.run(['cargo','metadata','--offline','--format-version','1'],cwd=workspace,stdout=subprocess.DEVNULL,check=True)
if not registry()<=before:raise ValueError('Cargo changed a locked registry identity')
print('Prepared Next offline sources with preserved registry versions/checksums',flush=True)
