"""Shared helpers for the lock-*.py scripts.

Every locker resolves upstream sources into hash-pinned Guix origins.
The helpers here are the single copy of that plumbing: scheme/digest/origin
render a pinned origin form, fetch downloads with resume and mirror
support, and marker/ENV evaluate PEP 508 environment markers offline.

Import as `from lock_lib import ...`; running `python3 scripts/lock-X.py`
puts this directory first on sys.path.
"""
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import re
import ast
import subprocess

ENV = dict(sys_platform='linux', platform_machine='x86_64', platform_release='6.6.0', platform_system='Linux', platform_python_implementation='CPython', python_version='3.12', python_full_version='3.12.12', implementation_name='cpython', implementation_version='3.12.12', os_name='posix', extra='')


def scheme(value):
    return json.dumps(str(value), ensure_ascii=False)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def origin(url, name, path):
    return (f'(origin (method url-fetch) (uri {scheme(url)})\n'
            f'        (file-name {scheme(name)})\n'
            f'        (sha256 (base16-string->bytevector "{digest(path)}")))')


def marker(expression):
    def walk(node):
        if isinstance(node, ast.Expression): return walk(node.body)
        if isinstance(node, ast.Name): return ENV[node.id]
        if isinstance(node, ast.Constant): return node.value
        if isinstance(node, ast.BoolOp):
            vals = [walk(x) for x in node.values]
            return all(vals) if isinstance(node.op, ast.And) else any(vals)
        if isinstance(node, ast.Compare):
            left = walk(node.left)
            for op, rightnode in zip(node.ops, node.comparators):
                right = walk(rightnode)
                a, b = left, right
                if isinstance(op, (ast.Lt, ast.LtE, ast.Gt, ast.GtE)):
                    a, b = tuple(map(int, a.split('.'))), tuple(map(int, b.split('.')))
                if isinstance(op, ast.Eq): ok = a == b or (str(b).endswith('.*') and str(a).startswith(str(b)[:-1]))
                elif isinstance(op, ast.NotEq): ok = not (a == b or (str(b).endswith('.*') and str(a).startswith(str(b)[:-1])))
                elif isinstance(op, ast.Lt): ok = a < b
                elif isinstance(op, ast.LtE): ok = a <= b
                elif isinstance(op, ast.Gt): ok = a > b
                elif isinstance(op, ast.GtE): ok = a >= b
                elif isinstance(op, ast.In): ok = a in b
                elif isinstance(op, ast.NotIn): ok = a not in b
                else: raise ValueError(expression)
                if not ok: return False
                left = right
            return True
        raise ValueError(f'Unsupported lock marker: {expression}')
    return walk(ast.parse(expression, mode='eval'))


def fetch(item, cache, crate_mirror=None):
    url, name, expected, size = item
    download_url = url
    if crate_mirror and url.startswith('https://static.crates.io/crates/'):
        download_url = crate_mirror.rstrip('/') + '/' + '/'.join(url.split('/')[-2:])
    dest = cache / name
    def valid(): return dest.exists() and hashlib.sha256(dest.read_bytes()).hexdigest() == expected
    if not valid():
        tmp = dest.with_suffix(dest.suffix + '.part')
        if size and size > 2 * 1024 * 1024:
            parts = cache / (name + '.parts'); parts.mkdir(exist_ok=True)
            chunk = 512 * 1024
            prefix = tmp.read_bytes() if tmp.exists() else b''
            def segment(index):
                start, end = index * chunk, min(size, (index + 1) * chunk) - 1
                part = parts / str(index)
                if not part.exists() and start < len(prefix): part.write_bytes(prefix[start:end+1])
                for attempt in range(20):
                    count = part.stat().st_size if part.exists() else 0
                    if count == end - start + 1: return part
                    headers, download = parts / f'{index}.headers', parts / f'{index}.download'
                    result = subprocess.run(['curl', '-fLsS', '--connect-timeout', '30', '--max-time', '120', '--range', f'{start+count}-{end}', '-D', str(headers), '-o', str(download), download_url])
                    if headers.exists() and download.exists() and f'content-range: bytes {start+count}-{end}/{size}' in headers.read_text().lower():
                        with part.open('ab') as target: target.write(download.read_bytes())
                    elif result.returncode == 0:
                        # Some source hosts ignore Range and return the whole
                        # archive. Accept that only after full hash validation.
                        data = download.read_bytes()
                        if len(data) != size or hashlib.sha256(data).hexdigest() != expected:
                            raise ValueError('Server ignored Range without returning the verified complete source')
                        part.write_bytes(data[start:end+1])
                        return part
                raise ValueError('Incomplete source segment')
            with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
                chunks = list(pool.map(segment, range((size+chunk-1)//chunk)))
            with tmp.open('wb') as target:
                for part in chunks: target.write(part.read_bytes())
        else:
            direct = ['--noproxy', '*', '-4'] if url.startswith('https://static.crates.io/') and not crate_mirror else []
            subprocess.run(['curl', *direct, '-fL', '--retry', '8', '--retry-all-errors', '--connect-timeout', '30', '--max-time', '1800', '-C', '-', '-sS', '-o', str(tmp), download_url], check=True)
        if hashlib.sha256(tmp.read_bytes()).hexdigest() != expected: raise ValueError(f'Checksum mismatch: {name}')
        tmp.replace(dest)
    return url, name, dest
