"""Use the source-vendored Geist font instead of the build-time Google Fonts fetch.

The dashboard's layout imports Geist from `next/font/google`, which downloads the
font from fonts.googleapis.com during `next build`.  This build is offline and
must not fetch at build time, so switch to `next/font/local` pointing at the
Geist variable font vendored from the `geist` package.
"""
import sys
from pathlib import Path

source = Path(sys.argv[1]) / 'packages/dashboard/src/app/layout.tsx'
text = source.read_text()
old_import = 'import { Geist } from "next/font/google";\n'
new_import = 'import localFont from "next/font/local";\n'
old_font = 'const geist = Geist({ subsets: ["latin"], variable: "--font-sans" });'
new_font = ('const geist = localFont({\n'
            '  src: "./geist/Geist-Variable.ttf",\n'
            '  variable: "--font-sans",\n'
            '  display: "swap",\n'
            '});')
if old_import not in text or old_font not in text:
    raise ValueError('Unexpected dashboard layout source')
text = text.replace(old_import, new_import).replace(old_font, new_font)

# Set an explicit metadataBase so Next does not resolve the base path via the
# request-scoped `pathname()` API, which is unavailable while statically
# exporting the built-in /_not-found and /_global-error pages offline.
old_meta = 'export const metadata: Metadata = {\n'
new_meta = ('export const metadata: Metadata = {\n'
            '  metadataBase: new URL(\n'
            '    process.env.NEXT_PUBLIC_DAEMON_URL ?? "http://localhost:4848"\n'
            '  ),\n')
if old_meta not in text:
    raise ValueError('Unexpected dashboard metadata source')
text = text.replace(old_meta, new_meta, 1)
source.write_text(text)
print('Vendored Geist font and set metadataBase', flush=True)
