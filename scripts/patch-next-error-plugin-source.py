"""Adapt Next's six string constructors to its independently locked SWC API."""
import hashlib
from pathlib import Path

path = Path('src/lib.rs')
source = path.read_bytes()
if hashlib.sha256(source).hexdigest() != '0a2f6c55e4a2cd0c818e35af2e0c5c707115813b0ab66f2e9dd535d52618acbb':
    raise ValueError('Unexpected authored error plugin source')
text = source.decode()
for literal in ('Object', 'defineProperty', '__NEXT_ERROR_CODE', 'value', 'enumerable', 'configurable'):
    token = 'rcstr!("' + literal + '")'
    if text.count(token) != 1:
        raise ValueError('Unexpected constructor: ' + literal)
    # swc_ecma_ast 9.0.0 bridges &str to IdentName via Atom; Atom itself also
    # implements From<&str>. Inference retains each original expression type.
    text = text.replace(token, '"' + literal + '".into()')
if 'rcstr!' in text:
    raise ValueError('Unaccounted macro invocation')
path.write_text(text)
