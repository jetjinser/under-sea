"""Make the owned dependency object's lifetime explicit for Rust 1.95."""
from pathlib import Path
import sys

source = Path(sys.argv[1]) / 'crates/rspack_binding_api/src/dependency.rs'
text = source.read_text()
anchor = '    dependency: &dyn rspack_core::Dependency,\n'
if text.count(anchor) != 1:
    raise ValueError('Unexpected Rspack DependencyWrapper constructor')
# Callers borrow dependencies owned by Box<dyn Dependency> in the module graph
# or factory. Those objects carry the default 'static object bound. Make that
# bound explicit without lengthening the borrow or changing pointer ownership.
# A caller with a non-static object must fail compilation rather than erase its
# lifetime through an unchecked transmute. Existing hook access rules remain.
source.write_text(text.replace(anchor,
    "    dependency: &(dyn rspack_core::Dependency + 'static),\n"))
print('Declared owned Rspack dependency object lifetime without extending borrow', flush=True)
