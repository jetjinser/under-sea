"""Provide the plain __rust_probestack symbol for source-built N-API cdylibs.

Guix's source-built Rust exports the stack-probe routine only under the mangled
name `__rustc::__rust_probestack`, not as the plain C symbol `__rust_probestack`.
Vendored crates that declare the plain symbol (notably wasmer-vm 5.x, pulled in
by SWC's plugin host) therefore leave it undefined in the produced cdylib, which
then fails to dlopen. Define the standard compiler-builtins probing routine in
such crates and refresh the vendored crate checksum.
"""
import hashlib
import json
import re
import sys
from pathlib import Path

vendor = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('guix-vendor')

PATTERN = re.compile(
    r'(?P<indent>[ \t]*)extern "C"\s*\{\s*\n'
    r'[ \t]*pub fn __rust_probestack\(\);\s*\n'
    r'[ \t]*\}\n')

ASM_BODY = '''\
{indent}// Guix's source-built Rust exposes the stack probe only under the
{indent}// mangled `__rustc::__rust_probestack`; define the standard
{indent}// compiler-builtins routine locally so the cdylib is self-contained.
{indent}core::arch::global_asm!(
{indent}    ".pushsection .text.__rust_probestack",
{indent}    ".weak __rust_probestack",
{indent}    ".hidden __rust_probestack",
{indent}    ".type __rust_probestack, @function",
{indent}    "__rust_probestack:",
{indent}    "pushq %rbp",
{indent}    "movq %rsp, %rbp",
{indent}    "mov %rax,%r11",
{indent}    "cmp $0x1000,%r11",
{indent}    "jna 3f",
{indent}    "2:",
{indent}    "sub $0x1000,%rsp",
{indent}    "test %rsp,8(%rsp)",
{indent}    "sub $0x1000,%r11",
{indent}    "cmp $0x1000,%r11",
{indent}    "ja 2b",
{indent}    "3:",
{indent}    "sub %r11,%rsp",
{indent}    "test %rsp,8(%rsp)",
{indent}    "add %rax,%rsp",
{indent}    "leave",
{indent}    "ret",
{indent}    ".size __rust_probestack, . - __rust_probestack",
{indent}    ".popsection",
{indent}    options(att_syntax)
{indent});
'''


def patch(crate):
    source = crate / 'src/probestack.rs'
    if not source.is_file():
        return False
    text = source.read_text()
    if 'core::arch::global_asm!' in text:
        return False
    matches = list(PATTERN.finditer(text))
    if len(matches) != 1:
        raise ValueError('Unexpected wasmer-vm probestack source: ' + str(crate))
    match = matches[0]
    asm = ASM_BODY.format(indent=match.group('indent'))
    # Insert right after the extern block, keeping the definition inside the
    # same cfg branch as the reference.
    text = text[:match.end()] + asm + text[match.end():]
    source.write_text(text)

    checksum_path = crate / '.cargo-checksum.json'
    checksum = json.loads(checksum_path.read_text())
    checksum['files']['src/probestack.rs'] = hashlib.sha256(
        source.read_bytes()).hexdigest()
    checksum_path.write_text(json.dumps(checksum, sort_keys=True))
    return True


patched = []
for crate in sorted(vendor.glob('wasmer-vm-*')):
    if patch(crate):
        patched.append(crate.name)
if patched:
    print('Defined __rust_probestack in ' + ', '.join(patched), flush=True)
else:
    print('No vendored wasmer-vm probestack needed patching', flush=True)
