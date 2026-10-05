// Validate dependency metadata with an authenticated source semver implementation.
// This does not load or execute any of the target framework packages.
const fs = require('fs');
const [inventoryPath, semverSource, outputPath] = process.argv.slice(2);
const semver = require(semverSource);
const inventory = JSON.parse(fs.readFileSync(inventoryPath, 'utf8'));
const evidence = [];
for (const [identity, item] of Object.entries(inventory.snapshots)) {
  for (const [name, range] of Object.entries(item.authored_peer_constraints || {})) {
    const selected = item.dependencies[name];
    if (!selected) {
      if ((item.optional_dependency_names || []).includes(name)) continue;
      throw new Error(`Missing required peer ${identity}: ${name}`);
    }
    const target = inventory.snapshots[selected];
    if (target.name !== name || !semver.satisfies(target.version, range)) {
      throw new Error(`Peer identity or version mismatch ${identity}: ${name} ${range} -> ${selected}`);
    }
    evidence.push({identity, name, range, selected, version: target.version});
  }
}
fs.writeFileSync(outputPath, JSON.stringify({
  npm_lock_sha256: inventory.npm_lock_sha256, semver_source: semverSource,
  peer_bindings: evidence, functional_validation: 'deferred'
}, null, 2) + '\n');
process.stdout.write(`Validated ${evidence.length} authored npm peer metadata bindings\n`);
