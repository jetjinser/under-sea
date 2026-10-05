"""Preserve include_dir tracking using Rust 1.95's renamed proc-macro APIs."""
import hashlib
import json
from pathlib import Path
import sys

root = Path(sys.argv[1]) / 'include_dir_macros-0.7.3'
module = root / 'src/lib.rs'
text = module.read_text()
for original, replacement in (
    ('feature(track_path, proc_macro_tracked_env)',
     'feature(proc_macro_tracked_path, proc_macro_tracked_env)'),
    ('proc_macro::tracked_env::var(variable)',
     'proc_macro::tracked::env_var(variable)'),
    ('proc_macro::tracked_path::path(_path.to_string_lossy())',
     'proc_macro::tracked::path(_path)'),
):
    if text.count(original) != 1:
        raise ValueError('Unexpected include_dir source: ' + original)
    text = text.replace(original, replacement)
module.write_text(text)
# Source archive checksum was authenticated before vendoring. Cargo's file
# checksum describes this explicitly patched file; retain original origin hash.
checksum = root / '.cargo-checksum.json'
data = json.loads(checksum.read_text())
data['files']['src/lib.rs'] = hashlib.sha256(module.read_bytes()).hexdigest()
checksum.write_text(json.dumps(data, sort_keys=True))
print('Preserved include_dir environment/path dependency tracking', flush=True)
