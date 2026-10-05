// Resolve and verify build-time peer metadata without loading target packages.
const fs = require('fs');
const crypto = require('crypto');
const [inventoryPath, archivesPath, semverSource, bindingsPath, auditPath] = process.argv.slice(2);
const semver = require(semverSource);
const inventory = JSON.parse(fs.readFileSync(inventoryPath));
const archives = JSON.parse(fs.readFileSync(archivesPath));
if (inventory.yarn_lock_sha256 !== archives.yarn_lock_sha256) throw new Error('Lock mismatch');
const records = new Map(archives.archives.map(r => [r.identity, r]));
const bindings = {}, evidence = [];
for (const [identity, item] of Object.entries(inventory.snapshots)) {
  const record = records.get(item.name + '@' + item.version);
  if (!record) throw new Error('Archive audit does not cover snapshot: ' + identity);
  if (!record.peer_dependencies) continue;
  for (const [name, range] of Object.entries(record.peer_dependencies)) {
    const candidates = Object.entries(inventory.snapshots)
      .filter(([_, p]) => p.name === name && semver.satisfies(p.version, range)).map(([id]) => id);
    const parents = Object.entries(inventory.snapshots)
      .filter(([_, parent]) => Object.values(parent.dependencies).includes(identity))
      .map(([parentId, parent]) => parent.name === name ? parentId : parent.dependencies[name])
      .filter(id => candidates.includes(id));
    const uniqueParents = [...new Set(parents)];
    const preferred = [item.dependencies[name], inventory.root_aliases[name],
      uniqueParents.length === 1 ? uniqueParents[0] : undefined]
      .find(id => candidates.includes(id));
    const selected = preferred || (candidates.length === 1 ? candidates[0] : undefined);
    if (!selected) {
      if (!candidates.length && record.peer_dependencies_meta?.[name]?.optional) continue;
      throw new Error(`Unresolved or ambiguous peer ${identity}: ${name} ${range}`);
    }
    (bindings[identity] ||= {})[name] = selected;
    evidence.push({identity, name, range, selected, version: inventory.snapshots[selected].version});
  }
}
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
fs.writeFileSync(bindingsPath, JSON.stringify(bindings, null, 2) + '\n');
fs.writeFileSync(auditPath, JSON.stringify({yarn_lock_sha256: inventory.yarn_lock_sha256,
  inventory_sha256: hash(inventoryPath), archives_sha256: hash(archivesPath),
  bindings_sha256: hash(bindingsPath), semver_source: semverSource,
  peer_bindings: evidence, functional_validation: 'deferred'}, null, 2) + '\n');
process.stdout.write(`Verified ${evidence.length} Yarn peer metadata bindings\n`);
