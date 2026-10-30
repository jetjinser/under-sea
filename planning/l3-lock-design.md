# L3 lock design

This document turns the L3 feasibility audit into an implementable design.  It
covers the packages that still lack a usable dependency lock and the
remaining network-gated Node locks.  It does not change any package level by
itself.

The execution order and complete L1/L2 inventory now live in
[`update-level-expansion-plan.md`](update-level-expansion-plan.md). This file
records lock design details; do not use its older workstream order as the live
backlog.

## Baseline

```text
inventory: 45
L0: 6
L1: 2
L2: 23
L3: 14
independent L2+: 22
dependent L2+: 15
```

The current count is 14 L3. The design below must not treat a channel pin or a
stale checked-in lock as an L3 lock.

## Lock taxonomy

Every L3 manifest entry must declare one of these lock kinds:

```json
"lock": {
  "kind": "upstream",
  "script": "scripts/lock-hermes.py",
  "output": "modules/under-sea/packages/hermes-lock.scm"
}
```

### 1. `upstream`

The upstream project ships a real dependency lock (`uv.lock`,
`package-lock.json`, `Cargo.lock`, `go.sum`, `bun.lock`, ...).  The adapter
regenerates it from the exact source archive and verifies the checked-in
origin file byte-for-byte.

Examples: `pi` and `hermes-agent`. Vimium C uses the explicit `guix-inputs`
policy: the build does not use npm packages and instead consumes channel-pinned
`node` and `node-typescript` inputs. Its prior npm archive candidate was
removed after confirming that the package build never used it.

### 2. `generated-node`

An npm project has a `package-lock.json`, but the Guix lock is a generated list
of source origins.  The adapter must:

1. fetch each archive named by the lock;
2. verify npm `integrity` before accepting it;
3. reject native archives (`*.node`, ELF, WASM) unless the package has an
   explicit source-built replacement;
4. write the generated origin module atomically.

Examples: `pi` (done), `camofox-browser` (done), `vimium-c` (candidate).

### 3. `channel`

The package is intentionally built from Guix package inputs, not a PyPI or npm
closure.  Its real dependency lock is the pinned channel plus the exact input
versions.  The lock module records:

- the resolved `channels.scm` commit/fingerprint;
- every propagated input name and version;
- the source package's own version and pin commit.

The adapter updates the source pin, regenerates the input list, and fails if an
input disappears or changes unexpectedly.  This is not a substitute for an
upstream lock; it is an honest lock for a Guix-native build.

Candidates: `marimo`, `seafile`, `seafile-server`, `strata`.

### 4. `components`

A package assembled from multiple independent upstreams.  The lock is a
component matrix; every component has its own version and hash.  The adapter
must update all components in one transaction or refuse the update.

Candidate: `helium`.

### 5. `none`

Only for packages with no runtime dependencies.  Must include a reason.
Example: `codex-session-patcher`.

### 6. `dependent`

A derived package consumes a parent's L3 output and lock rather than carrying a
second copy of the dependency closure. The manifest records `parent` and the
inherited lock path. Every additional toolchain input must be named and pinned;
prebuilt inputs remain human-reviewed. The dependent package still needs its
own offline reproducibility check and output smoke.

Example: `pi-standalone` inherits `pi-node-lock.scm` and declares the pinned
Bun 1.4.2 compiler as an additional, prebuilt input.

## Manifest changes

Add `lock.kind` to every L3 entry.  Extend the validator:

- `upstream` / `generated-node` require `script` and `output`;
- `channel` requires `script`, `output`, and `channel`;
- `components` requires `script` and `output`;
- `none` requires `reason` and no output.

Add a test that every `autonomy: L3` entry has a valid lock kind, and every
`L2` entry with a lock is marked `candidate` only.

## Implementation workstreams

### A. Node locks: camofox, vimium-c

**camofox-browser (complete, L3)**

- 169 runtime origins reproduce from the pinned source.
- The pinned-channel build and post-install `/health` smoke pass.
- See `STATUS.md` for the substitute use during the final build.

**vimium-c (L3, channel-pinned Guix inputs)**

- The package invokes TypeScript directly from the pinned Guix channel; it does
  not invoke npm or consume `npm-shrinkwrap.json`.
- Keep the git-fetch checkout; do not regress to codeload.
- Guix `--check`, manifest reference checks, and the 2.12.3 output version
  pass. The unused 160-archive candidate lock, generator and inventory were
  removed.

### B. Hermes lock regeneration

Hermes already ships `uv.lock` and Cargo locks.  Add to `hermes.py`:

- `--lock` mode: fetch the release archive, extract it, run
  `scripts/lock-hermes.py` with the reviewed overrides;
- compare the generated lock with `hermes-lock.scm`;
- refuse if the source tag and `pyproject.toml` version disagree;
- keep all Hermes components dependent.

L3 gate: source pin + lock byte-equality + core `make hermes-agent` build +
smoke.  This is the most expensive candidate and should run on a warm cache.

### C. Channel locks: marimo, seafile, seafile-server, strata

Implement one generic generator:

```text
scripts/lock-channel-inputs.py --module marimo --package marimo
  --output modules/under-sea/packages/marimo-lock.scm
```

The generator evaluates the package through the pinned Guix channel, walks
`propagated-inputs`, and emits a module such as:

```scheme
(define-public %marimo-lock-channel "...")
(define-public %marimo-lock-inputs
  '(("python-click" . "8.x") ...))
```

The update adapter runs after the source pin update and writes both the pin
and the lock atomically.  The lock is reviewed like any other generated file.

Per package:

- **marimo**: source pin + channel lock + `make marimo` + service smoke.
- **seafile**: client source + channel lock + CLI/service smoke; keep
  `libsearpc` 3.2.0.
- **seafile-server**: server source + channel lock + server smoke; keep
  `libsearpc` 3.3.
- **strata**: source + channel lock + native payload audit; CUDA variant stays
  dependent.

Do not create a PyPI lock for these packages: their build intentionally uses
Guix recipes, and a second closure would diverge from what is built.

### D. Helium component transaction

Helium stays L1 until all of the following exist:

- a component inventory with one symbol/hash per origin;
- an atomic adapter that resolves and updates every component together;
- a report showing old/new component versions side by side;
- a build gate on a warm Chromium cache.

Component set:

```text
helium commit
helium-linux commit
chromium base tarball
chromium linux-x64 tarball
search-engines asset
onboarding asset
uBlock asset
esbuild asset
Debian patch branch
```

Chromium, Clang and prepared-tarball changes remain human-merged even after
L2.  A changed submodule blocks an automatic apply.

## Verification protocol

For every promotion:

1. lock reproduction (byte equality or explicit review delta);
2. `make update-test`, `make update-audit`, `make verify-packaging`;
3. package build with the pinned channel;
4. host/integration/VM smoke;
5. update `STATUS.md` and the plan checkbox;
6. one signed title-only commit per package family;
7. clean worktree before the next slice.

## Order

Follow the current ordered remediation waves in
`update-level-expansion-plan.md`; it accounts for dependent packages and the
actual current autonomy levels. This file's original package order is
historical.

## Expected level movement

```text
camofox L3 (done)
pi L3 (done)
vimium L2 candidate -> L3 after lock policy/build integration
marimo/seafile/seafile-server/strata/hermes L2 -> L3 after individual gates
helium L1 -> L2 after atomic component transaction
```

There are currently 14 independent L3 packages. If all eight independent L2
entries pass their gates, independent L3 can reach 22; each of the 15
dependent L2 entries is assessed separately after its parent and its own gate
are ready. L4 remains disabled and precompiled/native-payload updates stay
manual.
