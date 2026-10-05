"""Adapt Next 16.1.1 turbo-tasks to Guix Rust 1.95 without removing features."""
from pathlib import Path
import sys

root = Path(sys.argv[1]) / 'turbopack/crates/turbo-tasks/src'
effect = root / 'effect.rs'
text = effect.read_text()
anchor = 'unsafe { value.downcast_mut_unchecked() }'
if text.count(anchor) != 2:
    raise ValueError('Unexpected turbo-tasks Any downcast source')
# Use the stable checked API for the existing TypeId-keyed invariant. A wrong
# type would have been undefined behavior before; preserve valid operations
# and make an invariant violation explicit rather than using removed APIs.
effect.write_text(text.replace(anchor,
    'value.as_mut().downcast_mut().expect("TypeId-keyed effect value mismatch")'))

scope = root / 'scope.rs'
text = scope.read_text()
anchor = "let f = f as *mut (dyn FnOnce() + Send + 'static);"
if text.count(anchor) != 1:
    raise ValueError('Unexpected turbo-tasks scoped closure lifetime cast')
# Rust migration guidance: https://github.com/rust-lang/rust/issues/141402
# FnOnce has no lifetime-gated methods. The original Scope invariant requires
# dropping the scope, and Drop waits for all jobs before borrowed data expires.
# This expresses the same existing unsafe lifetime erasure explicitly; it does
# not permit new callers to forget Scope or change its task completion logic.
replacement = """let f = unsafe {
            // SAFETY: FnOnce's vtable does not change with the object lifetime.
            // Scope's existing drop invariant awaits every job before 'env ends.
            std::mem::transmute::<
                *mut (dyn FnOnce() + Send + 'scope),
                *mut (dyn FnOnce() + Send + 'static),
            >(f)
        };"""
scope.write_text(text.replace(anchor, replacement))
print('Applied exact Next turbo-tasks Rust 1.95 compatibility edits', flush=True)
