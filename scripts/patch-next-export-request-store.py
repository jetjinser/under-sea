"""Guard no-store request APIs so `output: export` can prerender built-in pages.

Next 16.1.1 resolves metadata (and thus `pathname()`/`params`/`searchParams`) for
its synthetic `/_global-error` route outside a work-unit store, so
`createServerPathnameForMetadata` etc. throw the "Expected workUnitAsyncStorage
to have a store" invariant and the static export aborts.  Return the underlying
values instead of throwing when no store is present; this only affects the
export-time, store-less path.
"""
import sys
from pathlib import Path

base = Path(sys.argv[1]) / 'packages/next/src/server/request'
anchor = '  throwInvariantForMissingStore()\n'

pathname = base / 'pathname.ts'
text = pathname.read_text()
if text.count(anchor) != 1:
    raise ValueError('Unexpected pathname.ts source')
pathname.write_text(text.replace(
    anchor, '  return createRenderPathname(underlyingPathname)\n'))

params = base / 'params.ts'
text = params.read_text()
if text.count(anchor) != 3:
    raise ValueError('Unexpected params.ts source')
text = text.replace(
    anchor, '  return Promise.resolve(underlyingParams)\n')
# The synthetic export of a client page has no work store; return the
# underlying params instead of aborting the static export.
missing_work_store = (
    '  const workStore = workAsyncStorage.getStore()\n'
    '  if (!workStore) {\n'
    '    throw new InvariantError(\n'
    "      'Missing workStore in createPrerenderParamsForClientSegment'\n"
    '    )\n'
    '  }\n')
if text.count(missing_work_store) != 1:
    raise ValueError('Unexpected createPrerenderParamsForClientSegment source')
text = text.replace(missing_work_store,
                    '  const workStore = workAsyncStorage.getStore()\n'
                    '  if (!workStore) {\n'
                    '    return Promise.resolve(underlyingParams)\n'
                    '  }\n')
params.write_text(text)

search_params = base / 'search-params.ts'
text = search_params.read_text()
if text.count(anchor) != 3:
    raise ValueError('Unexpected search-params.ts source')
text = text.replace(anchor, '  return Promise.resolve(underlyingSearchParams)\n', 2)
text = text.replace(anchor, '  return Promise.resolve({})\n', 1)
search_params.write_text(text)
print('Guarded store-less request APIs for output: export', flush=True)
