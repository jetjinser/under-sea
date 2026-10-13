"""Drop an @ts-expect-error made unused by the hermetic module layout.

In this build the `next/dist/compiled/source-map08` RawSourceMap type resolves
permissively, so the authored `@ts-expect-error` before `getIgnoredSources` is
reported as unused (TS2578) and fails `tsc`.  Remove only that directive and
keep the surrounding TODO.
"""
import sys
from pathlib import Path

source = Path(sys.argv[1]) / 'packages/next/src/server/dev/middleware-webpack.ts'
text = source.read_text()
anchor = "        // @ts-expect-error -- TODO: Support IndexSourceMap\n"
if text.count(anchor) != 1:
    raise ValueError('Unexpected middleware-webpack source')
source.write_text(text.replace(anchor, "        // TODO: Support IndexSourceMap\n"))
print('Removed unused @ts-expect-error in middleware-webpack', flush=True)
