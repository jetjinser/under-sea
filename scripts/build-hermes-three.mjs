// Compile Three's JavaScript entry points from the official Git source.
// Run from its source root with the reviewed Hermes node_modules available.
// Addon WASM resources need their own source builds before full packaging.
import { readFile, writeFile, rm, stat } from 'node:fs/promises';
import { rolldown } from 'rolldown';

const metadata = JSON.parse(await readFile('package.json', 'utf8'));
if (metadata.name !== 'three' || metadata.version !== '0.180.0') {
  throw new Error('Three source differs from the Hermes lock');
}
const original = await readFile('utils/build/rollup.config.js', 'utf8');
const terserImport = "import terser from '@rollup/plugin-terser';";
if (original.split(terserImport).length !== 2) {
  throw new Error('Unexpected upstream Three build configuration');
}
// Keep the upstream GLSL transform, license plugin and shared-core entry
// groups. Minified duplicates are unnecessary for Vite's own minification.
// The stub must never execute: only non-minified configurations are selected.
const adapted = original.replace(terserImport,
  "const terser = () => ({ name: 'unused-minification-config' });");
await writeFile('utils/build/guix-rollup.config.js', adapted);
await rm('build', { recursive: true, force: true });
const { default: configurations } = await import(
  new URL('../utils/build/guix-rollup.config.js', `file://${process.cwd()}/scripts/`));
const builds = configurations({});
if (builds.length !== 7) throw new Error('Unexpected Three entry-point groups');
for (const index of [0, 1, 2, 6]) {
  const { output, ...input } = builds[index];
  const bundle = await rolldown(input);
  try {
    for (const options of Array.isArray(output) ? output : [output]) {
      // Rollup's indentation option only controls formatting; Rolldown
      // formats its output itself and rejects this unsupported key.
      const { indent, ...supported } = options;
      await bundle.write(supported);
    }
  } finally {
    await bundle.close();
  }
}
for (const file of ['three.core.js', 'three.module.js', 'three.webgpu.js',
                    'three.webgpu.nodes.js', 'three.tsl.js', 'three.cjs']) {
  if (!(await stat(`build/${file}`)).size) throw new Error(`Empty Three entry: ${file}`);
}
await rm('utils/build/guix-rollup.config.js');
