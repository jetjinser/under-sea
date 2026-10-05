#!/usr/bin/env python3
"""Verify locked dashboard archives and inventory native payloads for Linux."""
import argparse
import base64
import concurrent.futures
import hashlib
import json
import re
from pathlib import Path
import subprocess
import tarfile

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('inventory',type=Path)
parser.add_argument('--cache',type=Path,default=Path('/tmp/under-sea-agent-browser-sources/node-inputs'))
parser.add_argument('--output',type=Path,default=Path('planning/hermes-agent-browser-node-archives.json'))
args=parser.parse_args()
args.cache.mkdir(parents=True,exist_ok=True)
data=json.loads(args.inventory.read_text())
def supported(values,target):
    positive=[value for value in values if not value.startswith('!')]
    return '!'+target not in values and (not positive or target in positive)
def archive(item):
    name,version=item['name'],item['version']
    identity=name+'@'+version
    if not item.get('integrity'):
        return {'identity':identity,'resolution':item.get('resolution',{}),
                'status':'non-registry source; separate source authentication required'}
    if any(not supported(item.get(key,[]),value) for key,value in
           [('os','linux'),('cpu','x64'),('libc','glibc')]):
        return {'identity':identity,'status':'foreign platform; not a Linux input'}
    url='https://registry.npmjs.org/'+name+'/-/'+name.rsplit('/',1)[-1]+'-'+version+'.tgz'
    algorithm = next((name for name in ('sha512', 'sha256', 'sha1')
                      if any(value.startswith(name + '-') for value in item['integrity'].split())), None)
    tokens = [value for value in item['integrity'].split() if algorithm and value.startswith(algorithm + '-')]
    if len(tokens) != 1:
        raise ValueError('Expected one supported locked integrity: ' + identity)
    expected=base64.b64decode(tokens[0].split('-',1)[1],validate=True)
    target=args.cache/(hashlib.sha256(url.encode()).hexdigest()[:16]+'.tgz')
    def valid(path):return path.is_file() and hashlib.new(algorithm,path.read_bytes()).digest()==expected
    if not valid(target):
        temporary=target.with_suffix('.part')
        subprocess.run(['curl','-fLsS','--retry','4','--retry-all-errors','--connect-timeout','30',
                        '--max-time','300',url,'-o',str(temporary)],check=True)
        if not valid(temporary):raise ValueError('Locked archive integrity mismatch: '+identity)
        temporary.replace(target)
    payloads=[]
    with tarfile.open(target) as tar:
        roots={member.name.split('/',1)[0] for member in tar.getmembers()}
        if len(roots)!=1:raise ValueError('Unexpected archive root: '+identity)
        metadata=json.loads(tar.extractfile(next(iter(roots))+'/package.json').read())
        if metadata['name']!=name or metadata['version']!=version:
            raise ValueError('Archive metadata mismatch: '+identity)
        for member in tar.getmembers():
            if not member.isfile():continue
            magic=tar.extractfile(member).read(4)
            if member.name.endswith(('.node','.so','.dll','.dylib','.exe','.wasm','.jar','.class')) or magic in (
                    b'\x7fELF',b'\x00asm',b'\xfe\xed\xfa\xce',b'\xce\xfa\xed\xfe',
                    b'\xfe\xed\xfa\xcf',b'\xcf\xfa\xed\xfe',b'\xca\xfe\xba\xbe'):
                payloads.append(member.name)
            elif member.name.endswith(('.js', '.mjs', '.cjs')):
                text=tar.extractfile(member).read()
                for encoded in re.findall(rb'''['"](AGFzb[A-Za-z0-9+/=]+)['"]''', text):
                    try:
                        decoded=base64.b64decode(encoded,validate=True)
                    except ValueError:
                        continue
                    if decoded[:8]==b'\x00asm\x01\x00\x00\x00':
                        payloads.append(member.name)
                        break
    return {'identity':identity,'url':url,'archive':str(target),
            'upstream_integrity_algorithm':algorithm,
            'peer_dependencies':metadata.get('peerDependencies',{}),
            'peer_dependencies_meta':metadata.get('peerDependenciesMeta',{}),
            'os':metadata.get('os',[]),'cpu':metadata.get('cpu',[]),
            'libc':metadata.get('libc',[]),
            'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
            'native_payloads':payloads,'has_install_script':bool(metadata.get('scripts',{}).get('install') or metadata.get('scripts',{}).get('postinstall')),
            'status':'integrity verified; source replacement required' if payloads else 'integrity verified; no detected native payload'}
unique={}
for item in data['snapshots'].values():
    key=(item['name'],item['version'])
    if key in unique and unique[key]['integrity']!=item['integrity']:
        raise ValueError('Conflicting archive integrity for '+str(key))
    unique[key]=item
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    results=list(pool.map(archive,unique.values()))
args.output.write_text(json.dumps({'pnpm_lock_sha256':data.get('pnpm_lock_sha256'),
    'yarn_lock_sha256':data.get('yarn_lock_sha256'),
    'npm_lock_sha256':data.get('npm_lock_sha256'),'archives':results,
    'status':'Archive audit only; no install script or package code executed'},indent=2)+'\n')
print('Verified',sum('sha256' in item for item in results),'Linux archives;',
      sum(bool(item.get('native_payloads')) for item in results),'contain native/WASM payloads')
