# Update level expansion goal

This is the long-run plan for every package that can move up an autonomy
level but has not done so yet.  It is intentionally separate from
`update-coverage-next-plan.md`: that plan widened independent coverage to 22;
this plan deepens automation and closes the remaining level gaps.

## Baseline

Live snapshot from `guile --no-auto-compile -L scripts/update -s
scripts/update/report.scm`, refreshed 2026-10-30 after Hermes interfaces joined L3:

```text
inventory: 45
L0: 6
L1: 1
L2: 5
L3: 33
independent L2+: 23
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

## Workstream B: helium L1 to L2 (complete)

Current: detector at `scripts/update/helium.py` reports helium commit,
helium-linux commit, Chromium version, Debian branch, assets and release tags.

Completed requirements for L2:

- [x] Add a component inventory with one symbol/value and one hash per origin:
  - `helium` commit;
  - `helium-linux` commit;
  - Chromium base tarball;
  - Chromium linux-x64 tarball;
  - search-engines asset;
  - onboarding asset;
  - uBlock asset;
  - esbuild asset;
  - Debian patch commit.
- [x] Add an atomic adapter that either updates every component or refuses.
- [x] Compare the old and new component matrix in the update report.
- Keep Chromium/Clang/prepared-tarball changes human-merged even after L2.
- [x] Exit: `make update-detect-helium` plus a dry-run component transaction;
  no partial pin edits. The no-network current-candidate dry-run covers all
  nine origins; tests prove incomplete transactions and Chromium prepared
  tarball changes fail without modifying `helium.scm`. Upstream tag lookup
  was intentionally disabled in this sandbox, so the report marks those
  remote versions unavailable; the transaction consumes a complete candidate
  supplied by the caller.

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

- Status: L3; complete. Its Python runtime/build inputs resolve through the
  pinned Guix channel; the two compatibility overrides are source-hash pinned
  in `marimo-deps.scm`. This explicit Guix-input policy is recorded in the
  manifest and tested.
- `make marimo` with `--no-substitutes --check` passed, including CLI smokes.
  Both Marimo service VM derivations passed: the main test checks
  HTTP/notebook output and state ownership; the auth test checks redirects,
  rejection and bearer-token access. `make verify-standalone` passed all 13
  checks after fixing the minimal-Bash module-presence helper.

### C5. seafile and seafile-server (complete)

- [x] Both are L3 with channel-pinned Guix native/Python inputs and a shared
  source lock that keeps client `libsearpc` 3.2.0 separate from server 3.3.0.
- [x] Client no-substitutes build/check, CLI smokes and service VM test pass.
- [x] Server no-substitutes build/check and `seaf-fsck --help` package smoke
  pass. The package is server core; Seahub/seafdav remain separate deferred
  work (see `standalone-packages-plan.md`).

### C5a. python-ms-ivy (complete)

- [x] L3 covers the shipped Z3-backed `ivy` and `ivy_check` workflows, with
  Python/Z3 dependencies resolved by the pinned Guix channel.
- [x] A no-substitutes `--check` build and the repository's IVy array fixture
  pass.
- The C++ `ivyc` backend is explicitly outside package scope because its
  upstream submodules and system toolchain are not pinned or shipped.

### C5b. Overleaf toolkit and wrapper (complete)

- [x] The toolkit's locked source tree is a copy-only package with no build or
  runtime dependency closure; `lock.strategy: none` records that boundary.
- [x] `overleaf-ctl` pins its Guix runtime inputs through the channel and
  depends on the toolkit source pin.
- [x] Both packages build without substitutes. `make verify-overleaf` checks
  help and initializes config in a temporary root without touching container
  data or invoking external images.
- Container image versions and deployment are external runtime policy and
  remain outside automatic package updates.

### C6. pi (done)

- [x] Add `scripts/lock-pi.py` and `scripts/update/pi.py`; the adapter renders
  both release assets (source and install lock) and regenerates the Node lock.
- [x] Add `pi --version` as the package smoke.
- [x] Lock regeneration reproduces the checked-in `pi-node-lock.scm` exactly.
- [x] Full package build and `pi --version` smoke pass.
- Exit: release pin + payload diff + host CLI smoke pass.  The package is L3.

### C7. strata

- Strata HIP is promoted to L3. `strata-lock.scm` pins the bundled llama.cpp
  commit/hash and both GPU architecture targets; ROCm/toolchain inputs resolve
  through the pinned channel. The no-substitutes `--check` rebuilt the complete
  HIP package, and package install runs CLI help, device help and enumeration
  smokes. This host has no AMD GPU, so enumeration correctly reports `(no GPU
  device)`; hardware inference remains an environment-level check.
- `strata-cuda` is promoted to L3-dependent. It inherits `strata-lock.scm` and
  declares CUDA 13.0.2 and GCC 14 as channel-pinned additional inputs. A full
  no-substitutes `--check` build and package CLI smokes pass. The temporary
  driver stub exists only during build-time smoke; output and runtime wrapper
  continue to require the host's `libcuda.so.1`. The repository records prior
  RTX 5060 inference validation; this machine currently has no active driver.

### C8. hermes-agent (L3, complete)

- Status: L3. The source-derived inventory for the pinned 2026.9.24 archive
  contains 62 Python sources, exactly matching the 62 entries in
  `hermes-lock.scm`; all 62 have source archives. The updater now extracts the
  fetched archive, invokes `scripts/lock-hermes.py` with the reviewed source
  override files, validates that generated version/release pins match the
  archive, and atomically replaces the single lock file only after generation
  succeeds. `--source-only` remains available for diagnostics and is not an L3
  path.
- The updater unit tests cover safe extraction, bounded lock generation,
  staging, atomic replacement, and failure isolation. The first full rehearsal
  exposed excessive nested download concurrency; limiting Hermes lock
  downloads to two workers let the generator fetch and hash all 62 Python
  sources and 746 Cargo crates. The current 2026.9.24 lock regenerated
  byte-for-byte, applied atomically, and compared equal to the generated
  staging output. This closes the refresh integration gate for the pinned
  release.
- The no-grafts, no-substitutes `--check` passed after rebuilding the 814-test
  Eigen suite, pybind11, source-built Python wheels and Rust extensions. The
  package's offline functional smoke passed during the build; installed CLI
  `--help`/`--version` and legacy `hermes-agent --help` smokes also pass.
  Generated lock diff review found only empty generated metadata sections; all
  locked Python/Cargo inputs reproduced exactly, with no native payload delta.
- Hermes core is promoted to L3. Interfaces and Playwright are now
  L3-dependent after their source/Guix-input review, package builds and
  package-specific smokes. The four remaining
  Hermes dependents stay at L2 until their individual gates pass.

### C9. vimium-c (L3, completed)

- The package build does not invoke npm or consume `npm-shrinkwrap.json`; it
  runs `tsc` from channel-pinned Guix `node-typescript` and `node`. The prior
  160-archive candidate lock was unused and has been removed.
- Manifest lock policy is `guix-inputs`, names `channels.scm` and both direct
  Guix build inputs. The package's build phase compiles TypeScript and verifies
  every concrete path referenced by `manifest.json`.
- Source remains the pinned `git-fetch` checkout. A Guix `--check` build
  verifies deterministic output; the installed extension manifest reports
  version 2.12.3. This is an explicit no-npm-dependency policy, not an unlocked
  dependency set.

### C10. scoped L3 policies (complete)

- `overleaf-toolkit` and `overleaf-ctl` are L3 within their package boundary;
  container images remain external runtime policy. The wrapper smoke exposed
  and fixed the duplicated config-seed path.
- `python-ms-ivy` is L3 for its shipped Z3-backed workflow; the unshipped C++
  `ivyc` backend remains an explicit package limitation.

### C11. dependent packages whose parent is already L3

- `codex-base` is promoted to L3-dependent after its offline locked release
  build, CLI/version/help smoke, and execpolicy tests passed. Its metadata
  inherits `codex-lock.scm` and records the channel-pinned Rust/native inputs.
- `codex-sdk` is L3-dependent with its own fixed npm/MCP source lock and an
  ESM import smoke in the package check. `codex-zsh` is now L3-dependent with
  its exact zsh commit and EXEC_WRAPPER patch hash locked; no-substitutes
  `--check`, version smoke, and a build-time external-command wrapper smoke
  pass. `codex-voice-host` is L3-dependent with a no-substitutes `--check` and
  an installed binary framed lifecycle smoke (`hello/ready`, `close/closed`)
  that does not require audio devices. `codex-with-audio-and-zsh` is now
  L3-dependent; its no-substitutes `--check` passed after rebuilding the full
  release, and its install smoke checked both resource symlinks plus zsh and
  voice-host entrypoints. `codex-code-mode-host` is now L3-dependent as well:
  its rusty_v8 crate origins have explicit hashes, its Rust/Clang/GN/Ninja
  inputs follow the pinned channel, the no-substitutes output is available,
  and the Codex integration smoke invokes the packaged helper's `--help`.
- `pi-standalone`: promoted to L3-dependent. Its lock metadata inherits
  `pi-node-lock.scm`, names the pinned prebuilt Bun 1.4.2 toolchain, and the
  package build runs its own `pi --version` smoke. Guix `--check` and CLI
  smoke pass.
- `hermes-agent-browser-backend-camoufox` has a Camofox L3 dependency and an
  L3 Hermes parent; its package-specific integration gate remains pending.
- `hermes-agent-browser-backend-playwright` is now L3-dependent: Playwright
  Core and Chromium follow `channels.scm`; the VM test launches Chromium,
  navigates and checks the page title.
- `overleaf-ctl` is L3-dependent on the source-locked toolkit with channel-pinned
  runtime inputs. `strata-cuda` is L3-dependent on the Strata source lock.
- The other Hermes dependent packages (`hermes-agent-audio`,
  `hermes-agent-browser-backend-browser-use`, `hermes-agent-integrations`)
  follow the Hermes core stage above. Interfaces is L3-dependent.

## Workstream D: dependent level accounting (per-package promotion)

All Codex components whose parent is L3 have now reached L3.

`codex-base` passed its offline locked build and package smoke. `codex-sdk` is
now L3-dependent: its npm/MCP sources have a dedicated lock, and the package
check imports the compiled `Codex` and `Thread` ESM exports. `codex-zsh` is
also L3-dependent: the source commit and patch digest are fixed, and its
no-substitutes `--check`, version smoke and external-command `EXEC_WRAPPER`
smoke pass. `codex-voice-host` now has its own no-substitutes `--check` and
framed control lifecycle smoke, without requiring audio devices.
`codex-with-audio-and-zsh` is also L3-dependent after a no-substitutes
`--check`, CLI checks, and a package-level check of both component resource
links and entrypoints. `codex-code-mode-host` is L3-dependent with the exact
Codex/V8 source locks and channel-pinned native toolchain; its installed
`--help` smoke runs as part of the full Codex integration check.
`pi-standalone` and `strata-cuda` are promoted; see their individual audit
records above.

## Full L1/L2 backlog (live report, 2026-10-30)

This inventory lists every non-exempt L1/L2 manifest entry.  Level changes
require passing the gate below; rows marked “policy review” are not silently
counted as promotable.

| Current level | Package(s) | Next action / exit |
|---|---|---|
| L1 | `agent-cat` | **Blocked, retain L1.** Retry L2 only after a known-good Guix Haskell dependency set builds the pinned source; record build evidence and package smoke. |
| L2 independent | `helium` | **L3 build in progress.** Nine-origin atomic source transaction, candidate validation, tests, and human-merged Chromium prepared-tarball boundary are implemented. Promote only after the no-substitutes build and browser smoke pass. |
| L2 dependent, parent L3 | `hermes-agent-browser-backend-browser-use` | **Audited; hold at L2.** The runtime is independently pinned to PyPI `browser-use==0.13.11` via a generated source lock, but its manifest tracks only the Hermes parent and does not track the browser-use version; there is no checked-in `uv.lock` or reproducible lock-update adapter, and no package build/smoke evidence exists. Correct source tracking, remove stale component metadata, wire lock regeneration, then build and run CDP integration smoke. |
| L2 dependent, parent L3 | `hermes-agent-browser-backend-camoufox` | **After browser-use.** Review Hermes and Camoufox locks together, build and run backend smoke. |
| L2 dependent, parent L3 | `hermes-agent-integrations` | **After browser backends.** Audit broad optional closure, build and run declared CLI/import smokes. |
| L2 dependent, parent L3 | `hermes-agent-audio` | **Last Hermes package.** Audit native/audio/model closure and Porcupine exception, build offline and run device-free smokes. |

### Execution checkpoints

- [x] Helium L1→L2 atomic updater and source transaction; keep its Chromium
  prepared-tarball gate explicit.
- [x] Hermes updater transaction: fetch/extract pinned source, regenerate the
  complete Python/Cargo/Git core lock and every L3-dependent source profile
  declared by the parent manifest in staging directories, validate
  source/lock consistency, then apply the lock set with rollback on replacement
  failure. A failed fetch, lock generation, or validation must leave the
  repository untouched. Unit tests and a repeated core-lock byte-identical
  regeneration pass. Lock downloads use bounded concurrency.
- [x] Hermes core L2→L3: regenerate and review the Python/Cargo lock, complete
  no-substitutes build/check and CLI/runtime smoke, then update manifest,
  status, report and commit together.
- [x] Hermes interfaces L2→L3-dependent: regenerate and compare all 102 Python
  source identities/hashes and 764 Cargo checksums; verify the offline package
  build smoke and installed ACP check; declare its source profile in the parent
  updater transaction and add it to dependent build verification.
- [x] Hermes Playwright backend L2→L3-dependent: lock policy follows the
  pinned channel; the package wrapper smoke and Chromium navigation/title VM
  test pass. `make verify-browser` now exposes the focused test.
- [ ] Hermes dependent wave: browser-use audit is complete and has identified
  source-tracking and lock-regeneration gaps; continue by fixing those first,
  then process Camoufox, integrations and audio one package at a time. Each
  needs its own closure review, build and relevant smoke before promotion.
- [ ] Agent Cat L1→L2: retry only when the Haskell build blocker changes; retain
  L1 and its cited technical blocker otherwise.
- [ ] Final cleanup: reconcile all live counts and exemptions, remove stale
  temporary/repository artifacts, run the prescribed updater audit and
  packaging checks, and leave a clean worktree.

The live report counts 1 independent L2 and 4 dependent L2 entries. Eleven
dependent L3 entries are `pi-standalone`, `codex-base`, `strata-cuda`,
`overleaf-ctl`, `codex-sdk`, `codex-zsh`, `codex-voice-host`,
`codex-with-audio-and-zsh`, `codex-code-mode-host`, and
`hermes-agent-interfaces` and `hermes-agent-browser-backend-playwright`.
The dependent rows above enumerate all 4 L2
dependents. L0
exemptions are `bun-for-hermes`,
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

The live inventory has six non-exempt entries below their current ceiling:
Helium plus four Hermes packages at L2, and Agent Cat at L1. Every L2 package
that meets its gates targets L3; L4 remains disabled by policy. Work in this
order so each dependent is checked against a promoted Hermes core. Refresh the
live report and `STATUS.md` with every promotion.

1. **Hermes core (complete, L3).** Its Python/Cargo lock is source-derived,
   reviewed and reproducible; no-grafts/no-substitutes build/check and CLI
   smokes passed.
2. **Helium L2→L3 (in progress).** The nine-origin updater is complete. Finish
   the pinned no-substitutes build/check and installed CLI smoke. If a changed
   Chromium/Clang prepared tarball is needed, stop at the existing human
   review boundary; otherwise promote only after build evidence passes.
3. **Hermes interfaces (complete, L3-dependent).** Its 102 Python source
   identities, URLs and SHA-256 hashes reproduce from the pinned release;
   the package build compiled 764 Cargo crates, its build smoke passed, and
   installed `hermes-acp --check` plus version smoke passed. Its seven selected
   source extras are declared in the parent manifest and regenerate with the
   core lock in the same staged transaction.
4. **Hermes Playwright backend (complete, L3-dependent).** Channel-pinned
   Playwright Core and source-built Chromium pass the VM navigation/title
   smoke and installed wrapper help check.
5. **Hermes browser-use backend L2→L3.** Confirm the runtime source pin and
   parent relationship, review closure, build and run integration smoke.
6. **Hermes Camoufox backend L2→L3.** Review Hermes and Camoufox locks
   together, build and run backend smoke against both promoted parents.
7. **Hermes integrations L2→L3.** Audit the broad optional integration
   closure, build and run declared CLI/import smokes; keep external service
   credentials and endpoints out of the build gate.
8. **Hermes audio L2→L3.** Audit native/audio/model payloads and the
   source-unavailable Porcupine exception, build offline and run device-free
   package smokes. Record hardware/device checks separately.
9. **Agent Cat L1→L2 (blocked, revisit last).** Retry only when the pinned
   Haskell dependency set or a known-good source revision changes. Require a
   full source build and package smoke; retain L1 and its blocker otherwise.
10. **Final cleanup.** Reconcile manifest/report/`STATUS.md` and this plan;
    remove stale temporary or repository artifacts; run updater audit and
    packaging gates; inspect the final diff and commit each completed family.

Already-complete policies remain in force: Vimium C uses channel-pinned Guix
inputs rather than an unused npm lock; Marimo, Strata, Seafile, Overleaf and
IVy have package-scoped L3 gates; precompiled L0 exemptions and proprietary
archives stay outside the promotion queue without a source-build path and
policy change. Their detail remains in the sections above and historical
coverage notes.

## Success metrics

```text
Hard-blocked L0:            2  (adsk-licensing, moldflow)
L1 -> L2 candidates:       agent-cat (blocked on Haskell source build)
L2 -> L3 candidates:       helium + 4 Hermes dependents (ordered above)
Independent L3:            22 promoted; no other eligible independent L2
Dependent L3:              11 promoted; 4 Hermes dependents remain at L2
Dependent accounting:       explicit policy, no accidental inflation
L4:                        disabled
```

The goal is not to maximize a single number.  A level is complete only when
the next update can be prepared, verified offline, and reviewed without
hand-editing generated pins or locks.
