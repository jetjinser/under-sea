# Update level expansion goal

This is the long-run plan for every package that can move up an autonomy
level but has not done so yet.  It is intentionally separate from
`update-coverage-next-plan.md`: that plan widened independent coverage to 22;
this plan deepens automation and closes the remaining level gaps.

## Baseline

Live snapshot from `guile --no-auto-compile -L scripts/update -s
scripts/update/report.scm`, refreshed 2026-10-30 after the Pi standalone promotion:

```text
inventory: 45
L0: 6
L1: 2
L2: 22
L3: 15
independent L2+: 22
dependent L2+: 15
L4: disabled
```

The two hard blocks are the proprietary, user-supplied archives:
`adsk-licensing` and `moldflow-insight-thinclient`.  Other L0 entries are
explicit exemptions for precompiled or manually managed artifacts.  The L1/L2
backlog and ordered execution plan below are the current source of truth.

## Definitions

- **L1**: detect upstream and report; never edits pins.
- **L2**: update source pin/hash and run the declared build gate.
- **L3**: update pin and dependency lock, diff native payloads, build offline,
  and run host/integration/VM smoke.
- **L4**: automatic merge.  Permanently disabled.

A package may only move up when its next level has a deterministic exit test.
"Do not promote because the build is large" is recorded as a build-gate
blocker, not hidden in a higher level.

## Workstream A: L0 to L1

### A1. agent-cat (L0 -> L1, done; L2 blocked)

- [x] Add a detect-only git-commit entry for `jwiegley/agent-cat`.
- L1 is independent of the broken Haskell build: detection must not build.
- L2 is blocked until the pinned Guix Haskell set can build current main; if
  that is impossible, pin a known-good commit and document the constraint.
- Exit: `run.py detect --package agent-cat` reports the current commit and
  upstream head; no pin edit.  The detector now reports the upstream commit
  `e6d0cad...` as outdated while keeping the package at L1.

### A2. precompiled packages (L0 -> L1 detection only, policy gate)

Candidates: `ghidra`, `bun-for-hermes`, `bun-for-opencode`,
`hermes-electron-desktop`.

- L1 may report upstream versions/releases without changing pins.
- L2 remains forbidden for precompiled/native-payload packages unless a
  source-build path exists and is explicitly approved.
- Do not promote these by silently treating a precompiled artifact as source.
- Exit: detection report names the upstream artifact; package remains L0 for
  update automation and manual for installation.

## Workstream B: helium L1 to L2

Current: detector at `scripts/update/helium.py` reports helium commit,
helium-linux commit, Chromium version, Debian branch, assets and release tags.

Required before L2:

- Add a component inventory with one symbol and one hash per origin:
  - `helium` commit;
  - `helium-linux` commit;
  - Chromium base tarball;
  - Chromium linux-x64 tarball;
  - search-engines asset;
  - onboarding asset;
  - uBlock asset;
  - esbuild asset;
  - Debian patch commit.
- Add an atomic adapter that either updates every component or refuses.
- Compare the old and new component matrix in the update report.
- Keep Chromium/Clang/prepared-tarball changes human-merged even after L2.
- Exit: `make update-detect-helium` plus a dry-run component transaction;
  no partial pin edits.

## Workstream C: L2 to L3

L3 candidates are ordered by expected payoff and verification cost.  Each one
needs a lock adapter, an offline build, a smoke test, and a documented native
payload diff where applicable.

### C1. codex-session-patcher (done)

- [x] Pure Python source; smallest L3 candidate.
- [x] Add an explicit "no runtime dependencies" lock policy, a host smoke,
  and a test command.
- Exit: `make codex-session-patcher` plus `codex-patcher --help` smoke, no
  network at build time.  The CLI entry point is created before the smoke
  phase and the package is now L3.

### C2. qwenimage-ncnn-vulkan (done)

- [x] Keep the ncnn submodule pin explicit in `qwenimage-ncnn-pin.scm`.
- [x] Add `scripts/update/qwenimage.py`; a changed `src/ncnn` revision blocks
  `tag.scm` and `prepare.py` before any pin is applied.
- [x] Add a host smoke that runs `qwenimage-ncnn-vulkan -h` after wrapping.
- Exit: `make qwenimage` builds, smoke passes, and `run.py prepare` reproduces
  the checked-in main pin.  The package is now L3.

### C3. camofox-browser (done, L3)

- [x] `camofox-node-lock.scm` is wired into the manifest as the intended L3
  lock artifact; `scripts/lock-camofox.py` wraps the Node source lock.
- [x] Add a dedicated `camofox` update adapter that writes both the source pin
  and the Node lock.
- [x] Wire the manifest to the `camofox` adapter and declare
  `lock.kind: generated-node`.
- [x] Add a post-install smoke for `node --check` and the REST `/health`
  endpoint on a temporary home and dynamically selected loopback port; the
  package build must still run to confirm it passes.
- [x] Reproduce the production lock and inventory from the pinned source.
  SHA-512 checks passed for all source archives; review found 16 added runtime
  origins, with no removed paths or changed versions. Re-running the adapter
  reproduced the applied pin, lock and inventory byte-for-byte.
- [x] Build with the pinned channel and pass the post-install REST health
  smoke. The no-substitutes attempt stalled on SourceForge's PCRE archive, so
  the final build used the pinned channel's configured substitutes for system
  dependencies; camofox itself built locally and its smoke passed.
- Exit: package promoted to L3 after lock reproduction, build and health smoke.

### C4. marimo

- Status: L2; not started.
- Generate a reproducible lock for the complete Python runtime closure (the
  upstream has no `uv.lock`); verify it participates in the package build.
- Keep Loro/RTC propagation visible. Add CLI and service smokes and run the
  existing VM test where applicable.
- Exit: lock reproduces, offline build and smoke pass, then promote to L3.

### C5. seafile and seafile-server

- Status: both L2; not started.
- Create separate reproducible Python and native dependency closures; keep
  `libsearpc` versions distinct (client 3.2.0, server 3.3).
- Build offline and run CLI/service smokes for each package.
- Exit: each package builds from its own lock and can update independently;
  promote both to L3 only after both pass.

### C6. pi (done)

- [x] Add `scripts/lock-pi.py` and `scripts/update/pi.py`; the adapter renders
  both release assets (source and install lock) and regenerates the Node lock.
- [x] Add `pi --version` as the package smoke.
- [x] Lock regeneration reproduces the checked-in `pi-node-lock.scm` exactly.
- [x] Full package build and `pi --version` smoke pass.
- Exit: release pin + payload diff + host CLI smoke pass.  The package is L3.

### C7. strata

- Status: L2; not started.
- Add a Python/native dependency lock and compare native payloads.
- Build and smoke the CPU package first. Then audit the CUDA variant's
  distinct payload and driver assumptions; promote it as L3-dependent only
  after the parent is L3 and its own gate passes.
- Exit: source pin, lock, offline build and smoke pass for each eligible
  variant.

### C8. hermes-agent

- Status: L2; not started. The existing lock is not yet regenerated by the
  update adapter, and the full closure is large.
- Reuse the source adapter; wire lock regeneration through
  `scripts/lock-hermes.py`. Review origin deltas and native/Cargo payloads
  before applying.
- Build and smoke the core offline first. Promote each interfaces,
  integrations, audio and browser dependent package only after its specific
  closure and smoke are verified against the L3 parent.
- Exit: deterministic lock, offline core build and smoke pass; then assess the
  dependent packages individually.

### C9. vimium-c

- Add an npm lock for the TypeScript build and a deterministic build gate.
- Do not regress to the codeload tarball path; the git-fetch checkout is
  intentional.
- Exit: lock reproduces, build is deterministic, extension manifest check
  passes.
- Status: L2. An L2 candidate lock now covers 160 production archives from
  `npm-shrinkwrap.json`; SHA-1-only entries are verified against upstream
  integrity and then pinned by Guix SHA-256.  One obsolete `registry.nlark.com`
  URL is canonicalized to npm's package archive and verified against that same
  integrity.  The source pin remains `git-fetch`.  Deterministic build gating
  and lock consumption by the package build remain before L3 promotion.  The
  package builds successfully with `--check` (Guix reproducibility rebuild),
  including TypeScript emission and manifest file-reference check; the built
  extension manifest reports version 2.12.3. The next step is a decision gate:
  prove these locked archives are actually required by the build, wire them in,
  or replace the candidate with an explicit no-runtime-dependencies lock
  policy. Promote only after that policy is exercised by the updater.

### C10. not recommended for L3

- `overleaf-toolkit`: currently L2. Its copy-build packages configuration and
  external Docker images; no meaningful package dependency lock exists.
  Keep L2 unless the L3 policy is amended with a useful, testable lock model.
- `python-ms-ivy`: currently L2. Audit whether its runtime closure has a
  reproducibility gap. If yes, add a lock and promote; if not, record a
  no-runtime-dependencies or Guix-inputs policy and retain L2 only if that
  policy cannot meet L3's offline-build gate.

### C11. dependent packages whose parent is already L3

- `codex-base`, `codex-with-audio-and-zsh`, `codex-sdk`, `codex-voice-host`,
  `codex-code-mode-host`, `codex-zsh`: parent `codex` is L3, but these six
  remain L2 under the conservative policy because they have separate
  native/audio/SDK build paths. Audit each closure and smoke independently;
  promote only the variants that can consume the parent lock and meet the L3
  gate. Do not bulk-inherit the parent's level.
- `pi-standalone`: promoted to L3-dependent. Its lock metadata inherits
  `pi-node-lock.scm`, names the pinned prebuilt Bun 1.4.2 toolchain, and the
  package build runs its own `pi --version` smoke. Guix `--check` and CLI
  smoke pass.
- `hermes-agent-browser-backend-camoufox` has a Camofox L3 dependency but also
  depends on L2 Hermes; wait for Hermes core and then verify this integration.
- `overleaf-ctl` follows the L2 toolkit and remains L2 until the toolkit has a
  useful L3 model. `strata-cuda` remains L2 until Strata CPU is L3 and the CUDA
  payload gate passes.
- The other Hermes dependent packages (`hermes-agent-audio`,
  `hermes-agent-browser-backend-browser-use`,
  `hermes-agent-browser-backend-playwright`, `hermes-agent-integrations`, and
  `hermes-agent-interfaces`) follow the Hermes core stage above.

## Workstream D: dependent level accounting (per-package promotion)

The six Codex components are currently L2 while their parent `codex` is L3:

- `codex-base`
- `codex-with-audio-and-zsh`
- `codex-sdk`
- `codex-voice-host`
- `codex-code-mode-host`
- `codex-zsh`

Do not inherit a level automatically. Keep each component at L2 until its own
build inputs, native/audio payloads and smoke are covered. Once verified,
promote that component to L3-dependent; leave unverified siblings at L2. The
existing test that pins all six Codex components to L2 must be changed to
assert per-package results as each component passes. `pi-standalone` and
`strata-cuda` are audited separately below; their previous “parent is L2”
rationale is stale for Pi and remains accurate only for Strata.

## Full L1/L2 backlog (live report, 2026-10-30)

This inventory lists every non-exempt L1/L2 manifest entry.  Level changes
require passing the gate below; rows marked “policy review” are not silently
counted as promotable.

| Current level | Package(s) | Next action / exit |
|---|---|---|
| L1 | `agent-cat` | L2 is blocked by the current Guix Haskell build; test a known-good upstream pin or wait for compatible Haskell dependencies. |
| L1 | `helium` | Add the atomic nine-component transaction and dry-run described in Workstream B; keep Chromium/Clang human-reviewed. |
| L2 independent | `vimium-c` | Decide lock relevance; wire lock or explicit no-dependency policy; rerun reproducibility and manifest checks. |
| L2 independent | `marimo` | Lock Python closure, offline build, CLI/service smoke, applicable VM test. |
| L2 independent | `strata` | Lock and native payload audit; build/smoke CPU first, then assess CUDA dependent. |
| L2 independent | `seafile` | Create its Python/C locks, preserve client `libsearpc` 3.2.0, offline build and service smoke. |
| L2 independent | `seafile-server` | Create its separate Python/C locks, preserve server `libsearpc` 3.3, offline build and service smoke. |
| L2 independent | `hermes-agent` | Regenerate existing lock through updater, review Python/Cargo/native delta, offline build and core smoke. |
| L2 independent | `python-ms-ivy` | Reproducibility-gap audit; add lock if needed, otherwise document a concrete L2 ceiling. |
| L2 independent | `overleaf-toolkit` | Policy review: no meaningful dependency lock for copy-build/external images; retain L2 unless a verifiable L3 model is defined. |
| L2 dependent, parent L3 | `codex-base` | Audit its native closure and smoke against the parent lock; promote only after its own gate passes. |
| L2 dependent, parent L3 | `codex-with-audio-and-zsh` | Audit audio/native inputs and smoke separately; promote only after its own gate passes. |
| L2 dependent, parent L3 | `codex-sdk` | Audit SDK build inputs and smoke separately; promote only after its own gate passes. |
| L2 dependent, parent L3 | `codex-voice-host` | Audit voice/native inputs and smoke separately; promote only after its own gate passes. |
| L2 dependent, parent L3 | `codex-code-mode-host` | Audit host build inputs and smoke separately; promote only after its own gate passes. |
| L2 dependent, parent L3 | `codex-zsh` | Audit shell integration inputs and smoke separately; promote only after its own gate passes. |
| L2 dependent, parent L2 | `hermes-agent-audio` | Wait for Hermes core L3; review audio/native closure, reproduce, offline build and smoke. |
| L2 dependent, parent L2 | `hermes-agent-browser-backend-browser-use` | Wait for Hermes core L3; review browser-use closure, offline build and integration smoke. |
| L2 dependent, parent L2 | `hermes-agent-browser-backend-camoufox` | Wait for Hermes core L3; check both Hermes and Camofox locks, then offline integration smoke. |
| L2 dependent, parent L2 | `hermes-agent-browser-backend-playwright` | Wait for Hermes core L3; audit browser payload and run integration smoke. |
| L2 dependent, parent L2 | `hermes-agent-integrations` | Wait for Hermes core L3; audit integration closure, offline build and CLI smoke. |
| L2 dependent, parent L2 | `hermes-agent-interfaces` | Wait for Hermes core L3; audit interface closure, offline build and CLI smoke. |
| L2 dependent, parent L2 | `overleaf-ctl` | Wait for a useful L3 model for `overleaf-toolkit`; verify wrapper output and smoke separately. |
| L2 dependent, parent L2 | `strata-cuda` | Wait for Strata CPU L3; audit CUDA payload/driver assumptions and run its own build/smoke. |

The live report counts 8 independent L2 and 14 dependent L2 entries (with one
dependent L3, `pi-standalone`). The dependent rows above enumerate all 14 L2
dependents. L0 exemptions are `bun-for-hermes`,
`bun-for-opencode`, `ghidra`, and `hermes-electron-desktop`; the two proprietary
archives remain hard-blocked.  Do not raise these L0 entries without a source
build path and an explicit policy decision.

## Workstream E: verification and commit protocol

Every slice follows the same loop:

1. Update the plan checkbox and the manifest/report if levels change.
2. Run `make update-test`, `make update-audit`, and `make verify-packaging`.
3. Build the package with `--no-substitutes` where the build budget allows.
4. Run the declared host/integration/VM smoke, or record a concrete skip.
5. Commit one package family at a time with a signed, title-only message.
6. Leave the worktree clean; never commit `/var/tmp` update workdirs.
7. If a build gate fails, stop at the lower level and record the blocker.

Commit examples:

```text
update: promote codex-session-patcher to L3
update: add camofox npm lock
update: align codex dependent levels
```

## Ordered remediation waves

1. **Keep truth sources synchronized.** This plan and
   `update-coverage-next-plan.md` carry the live 2026-10-30 counts as of the
   latest promotion;
   `independent-coverage-plan.md` and `l3-lock-design.md` are labeled as
   historical/design references and point here for current status. `STATUS.md`
   lists the current package levels, and `README.md` has no static autonomy
   counts. Refresh the snapshot after every promotion.
2. **Resolve ready dependents.** Pi standalone is promoted and reproducible.
   Audit each Codex component against its parent lock. Promote only the
   components that pass their own offline build and smoke. Keep outcomes
   explicit per package.
3. **Finish Vimium C.** Decide whether npm-shrinkwrap production archives are
   build inputs; integrate and consume the lock or replace it with a tested
   no-dependency policy, then promote if all L3 gates pass.
4. **Marimo.** Create closure lock, prove it is consumed, build offline, run
   CLI/service smoke and applicable VM test; then promote.
5. **Strata family.** Lock/audit CPU variant, build and smoke, promote parent;
   then handle `strata-cuda` as a dependent with its own payload gate.
6. **Seafile family.** Lock and verify client/server separately, preserving
   their distinct `libsearpc` pins; promote only after both gates pass.
7. **Hermes family.** Wire deterministic lock refresh, complete the large core
   offline build and smoke, promote core; then verify/promote each dependent
   backend, interface, integration and audio package individually.
8. **Policy-capped packages.** Decide and document final L2 ceilings for
   `overleaf-toolkit` and `python-ms-ivy`; do not leave ambiguous “maybe later”
   notes. Keep L0 precompiled exemptions and the two proprietary archives
   outside this promotion sequence.
9. **Helium L1 to L2.** Implement its atomic component manifest and dry-run
   transaction; keep binary Chromium/Clang changes human-merged.
10. **Agent Cat L1 to L2.** Revisit only when the Haskell dependency set builds
    a known-good upstream commit; retain L1 if the build remains blocked.
11. After each wave, run update tests/audit/validation, relevant package
    builds and smokes, refresh `STATUS.md`, and commit the package family.

## Success metrics

```text
Hard-blocked L0:            2  (adsk-licensing, moldflow)
L1 -> L2 candidates:       helium; agent-cat when Haskell build unblocks
Helium:                    L2 with atomic component transaction
Independent L3:            >= 16 (from 14); stretch up to 22 if all qualify
Dependent L3:              promote each of the 15 only after its own gate
Dependent accounting:       explicit policy, no accidental inflation
L4:                        disabled
```

The goal is not to maximize a single number.  A level is complete only when
the next update can be prepared, verified offline, and reviewed without
hand-editing generated pins or locks.
