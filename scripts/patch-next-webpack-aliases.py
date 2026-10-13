#!/usr/bin/env python3
"""Adapt Next's devtools webpack aliases to the hermetic module layout.

Next's `next-devtools.webpack-config.js` aliases `react` and friends to the bare
module request `next/dist/compiled/...`.  The authored repository relies on the
package manager linking the `next` workspace package so that bare request
resolves from any importer.  In the hermetic layout the importing modules live
under `.sources/.../package` and cannot resolve `next`, so Rspack fails with
`Cannot find module 'react' for matched aliased key 'react'`.

This patch only rewrites those alias *targets* to absolute paths under
`__dirname` (`packages/next/dist/compiled/...`), preserving the exact same
compiled artifacts and alias semantics; it does not remove aliases, change
React versions, or substitute prebuilt payloads.
"""
import argparse
import hashlib
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
args = parser.parse_args()

target = args.source / 'packages/next/next-devtools.webpack-config.js'
raw = target.read_bytes()
expected = 'c6a3d2c1e0f3f6f0f7e0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f'
text = raw.decode()
pairs = [
    ("`next/dist/compiled/react${bundledReactChannel}`",
     "path.join(__dirname, `dist/compiled/react${bundledReactChannel}`)"),
    ("`next/dist/compiled/react-dom${bundledReactChannel}/client`",
     "path.join(__dirname, `dist/compiled/react-dom${bundledReactChannel}/client`)"),
    ("`next/dist/compiled/react-dom${bundledReactChannel}`",
     "path.join(__dirname, `dist/compiled/react-dom${bundledReactChannel}`)"),
    ("`next/dist/compiled/react-is${bundledReactChannel}`",
     "path.join(__dirname, `dist/compiled/react-is${bundledReactChannel}`)"),
    ("`next/dist/compiled/scheduler${bundledReactChannel}`",
     "path.join(__dirname, `dist/compiled/scheduler${bundledReactChannel}`)"),
]
changed = 0
for old, new in pairs:
    if old in text:
        text = text.replace(old, new)
        changed += 1
if changed == 0:
    raise SystemExit('No devtools alias targets matched; source layout changed')
target.write_text(text)
print('Rewrote', changed, 'devtools webpack alias targets')
