"""Preserve exact package aliases when ncc reads package metadata."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
args = parser.parse_args()
package = args.source / 'packages/next'
version = json.loads((package / 'package.json').read_text())['version']
if version not in ('16.0.8', '16.1.1'):
    raise ValueError('Expected audited Next source')
taskfile = package / 'taskfile.js'
text = taskfile.read_text()
for suffix in ('2', '3'):
    anchor = "      packageName: 'schema-utils',\n      bundleName: 'schema-utils" + suffix + "',"
    if text.count(anchor) != 1:
        raise ValueError('Schema-utils task anchor changed')
    replacement = "      packageName: 'schema-utils',\n      packageJsonName: 'schema-utils" + suffix + "',\n      bundleName: 'schema-utils" + suffix + "',"
    text = text.replace(anchor, replacement)
# Scope metadata resolution to the two versioned schema aliases. Other uses of
# packageJsonName keep their authored output-name behavior.
plugin_path = package / 'taskfile-ncc.js'
plugin = plugin_path.read_text()
if 'options.packageJsonName' not in plugin or 'packageJsonName ?? name' not in plugin:
    raise ValueError('Expected authored package metadata alias support')
anchor = '  let packagePath\n'
if plugin.count(anchor) != 1:
    raise ValueError('Metadata lookup anchor changed')
plugin = plugin.replace(anchor, anchor + "  const schemaAlias = /^schema-utils[23]$/.test(packageJsonName || '')\n  const metadataName = schemaAlias ? packageJsonName : packageName\n")
for old, new in [("bundleRequire.resolve(packageName + '/package.json')", "bundleRequire.resolve(metadataName + '/package.json')"),
                 ('dirname(bundleRequire.resolve(packageName))', 'dirname(bundleRequire.resolve(metadataName))'),
                 ('name: packageJsonName ?? name', 'name: schemaAlias ? name : (packageJsonName ?? name)')]:
    if plugin.count(old) != 1:
        raise ValueError('Metadata lookup source changed: ' + old)
    plugin = plugin.replace(old, new)
plugin_path.write_text(plugin)
taskfile.write_text(text)
