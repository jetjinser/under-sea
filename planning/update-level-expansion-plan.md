# Update level expansion goal

This is the long-run plan for every package that can move up an autonomy
level but has not done so yet.  It is intentionally separate from
`update-coverage-next-plan.md`: that plan widened independent coverage to 22;
this plan deepens automation and closes the remaining level gaps.

## Baseline

Initial live snapshot from `guile --no-auto-compile -L scripts/update -s
scripts/update/report.scm`, captured 2026-10-30 before the final Hermes dependent
gates:

```text
inventory: 45
L0: 6
L1: 1
L2: 3
L3: 35
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

### A1. agent-cat (L0 -> L1 -> L2, complete)

- [x] Add a detect-only git-commit entry for `jwiegley/agent-cat`.
- L1 is independent of the broken Haskell build: detection must not build.
- L2 was gated on dependency review, Guix build and package smoke. On
  2026-10-31, fetched and reviewed upstream main
  `e6d0cad4b9ff27d0e46aeaef522adafb7a7ee1a8`. Experimental Guix build passed
  the `ram`/`memory` compatibility point after substituting `ghc-memory`, but
  failed because Guix `ghc-crypton-x509` 1.7.7 lacks
  `ExtNameConstraints` and `GeneralSubtree`, required by the manager client.
  The Hackage manifest for `crypton-x509` 1.9.1 confirms this is a dependency
  family port, not a safe single-package replacement: it requires crypton
  >=1.1,<1.2; crypton-asn1-encoding and crypton-asn1-parse >=0.10,<0.11;
  crypton-asn1-types >=0.4.1,<0.5; and crypton-pem >=0.2.4. Guix currently
  provides crypton 1.0.4, ASN.1 encoding 0.9.6, parse 0.9.5, types 0.3.4,
  plus the old X.509 consumers. Upstream Nix carries a newer crypton/TLS/X.509
  family: crypton 1.1.2, crypton-x509 1.9.1, crypton-x509-store 1.9.0,
  crypton-x509-system 1.9.0, crypton-x509-validation 1.9.1,
  crypton-connection 0.4.6 and tls 2.3.0. Port and source-hash that compatible
  family and its ASN.1 dependencies, then rebuild reverse dependencies. The
  exact 24 Hackage archives in that compatibility slice are recorded in
  `planning/agent-cat-tls-sources.json`; each SHA-256 was checked against the
  Guix base32 source hash. Guix builds now pass for crypton 1.1.2, ASN.1
  encoding/parse 0.10.0 and types 0.4.1, crypton-pem 0.3.0, X.509 1.9.1,
  X.509 store 1.9.0 and X.509 validation 1.9.1. The validation recipe carries
  upstream's SAN-presence fix. The TLS/connection/HTTP TLS and WAI/Warp reverse
  dependencies were wired to the matching network ABI and built. The complete
  candidate package build, its build-time installed smoke, and isolated
  installed `agentic-run run hello --scripted` passed. Production is now pinned
  to `e6d0cad`; the checked-in Guix source checkout reproduces its NAR hash and
  the new git-commit prepare renderer reproduces the production pin byte for
  byte. The updater helper is covered by unit tests; the declared production
  build and installed smoke passed on 2026-10-31, producing
  `/gnu/store/w7dc5cmly9mamih1420nndwgf1m56nyl-agent-cat-0.0.0-0.e6d0cad`.

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

### Helium L2→L3 (complete)

- [x] `scripts/verify-helium.sh` completed its pinned no-substitutes build,
  including the GCC 15.2 dependency closure. The installed CLI smoke reported
  `Helium 0.19.4.1 (Chromium 155.0.8059.84)`. Manifest and `STATUS.md` record
  L3; the human-review boundary for prepared Chromium/Clang tarball changes
  remains in force.

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
- Hermes core is promoted to L3. Interfaces, Playwright, browser-use,
  Camoufox and integrations are now L3-dependent after their source/Guix-input
  review, package builds and package-specific smokes. Audio is now L3-dependent
  after a protobuf-lite rebuild fixed its joint ONNX Runtime/Sherpa import.

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
- Hermes audio and browser-use follow the Hermes core stage above. Hermes
  integrations is now L3-dependent after its full source build and installed
  runtime checks. Interfaces is L3-dependent.

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

## Level expansion status (live report, 2026-10-31)

This table lists the non-exempt entries still below their current
ceiling and the latest completed promotions. Level changes require
passing the gate below; rows marked “policy review” are not silently counted
as promotable.

| Current level | Package(s) | Next action / exit |
|---|---|---|
| L2 | `agent-cat` | **Promoted.** Production pin is reviewed upstream `e6d0cad4b9ff27d0e46aeaef522adafb7a7ee1a8`; the source-hashed crypton/TLS/X.509 and network compatibility family passed the full candidate build and installed scripted smoke. Run the declared production build gate during final cleanup. |
| L3 independent | `helium` | **Promoted.** The nine-origin atomic source transaction and human-merged Chromium prepared-tarball boundary remain in force. `scripts/verify-helium.sh` passed its pinned no-substitutes build and the installed CLI reported `Helium 0.19.4.1 (Chromium 155.0.8059.84)`. |
| L3 dependent, parent L3 | `hermes-agent-browser-backend-browser-use` | **Promoted.** Updated to PyPI `browser-use 0.13.14`. Channel-pinned uv 0.10.12 generated the checked-in `uv.lock` and source lock for 131 Python sdists plus 850 Rust crates; the root sdist and every Python/crate archive were SHA-256 checked. The Guix package build passed; the guest-VM gate verified backend/config installation, CLI help, and a local Chromium CDP title smoke (3 system tests passed). |
| L3 dependent, parent L3 | `hermes-agent-browser-backend-camoufox` | **Promoted.** PyPI `camoufox 0.5.8` resolves 51 packages; the checked-in `uv.lock` and source lock cover 37 Python sdists, 8 explicit Guix components and 0 Rust crates, with all source hashes verified. Guix provides PySide6's separate `pyside6`, `pyside6-essentials`, and `pyside6-addons` distributions from its unified source-built package. The controller/backend/browser package set builds. All three `make verify-camoufox` guest tests pass, including launching the locally pinned `156.0.1-beta.36` with controller 0.5.8 and opening an offline page with title/screenshot assertions. The runtime gate found and fixed the backend wrapper's missing GCC `libstdc++` path. |
| L3 dependent, parent L3 | `hermes-agent-integrations` | **Promoted.** Lock refreshed and applied from the parent's atomic source transaction: 213 Python sdists and 1,093 Rust crates; every fetched artifact hash passed verification, six stale out-of-profile entries were removed and retained source identities/hashes did not change. The complete Guix build and its installed offline functional check passed; installed CLI help and targeted imports for integrations/native extensions passed. |
| L3 dependent, parent L3 | `hermes-agent-audio` | **Promoted.** The selected inventory has 241 entries: 235 source-built Python packages, five Guix component providers, and Porcupine's one audited source-unavailable payload. The generated lock covers 235 Python sdists and 1,308 Rust crates; retained Python identities and hashes match the prior lock. Full Guix build, CLI, generic Hermes functional check, joint ONNX Runtime/Sherpa import, CPU provider availability, all declared native/audio imports and Porcupine import pass. ONNX Runtime uses protobuf-lite to prevent duplicate global ONNX descriptor registration between its Python binding and Sherpa's runtime. Hardware/device checks are separate from this device-free L3 gate. |

### Execution checkpoints

- [x] Helium L1→L2 atomic updater and source transaction; keep its Chromium
  prepared-tarball gate explicit.
- [x] Add `verify-helium` for the pinned no-substitutes build and installed
  `helium --version` smoke; include it in `verify-all` and declare it in the
  manifest. The complete gate passed and Helium is now L3.
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
- [x] Extend Hermes dependent-lock generation to pass selected extras,
  source-built component manifests and audited source-unavailable payloads.
  Add integrations/audio profiles to the staged transaction; keep their build
  gates disabled until those packages pass their L3 checks. Inventory-only
  regeneration against the pinned source confirms the audio closure and
  exposes six out-of-profile packages in the existing integrations lock.
  The pinned profile refresh later produced 213 integrations sdists and 1,093
  crates, and 235 audio sdists and 1,308 crates; the full Hermes transaction
  applied all four generated profiles atomically after hash validation.
- [x] Hermes browser-use source tracking: follow the independent PyPI project,
  resolve with channel-pinned uv 0.10.12, generate and stage both `uv.lock` and
  the source lock atomically, and bind the backend version to the generated
  lock. Updated to 0.13.14; the generated lock contains 131 Python sources and
  850 Rust crates, including the exact `tiktoken` Cargo lock override. The
  updater tests pass; the Guix package build and guest-VM CDP gate pass.
- [x] Add an offline browser-use CDP smoke to the package verification target:
  boot a guest VM, import the locked runtime, launch its packaged Chromium on a
  local data page, read the title over CDP, and check the backend wrapper/config.
  The gate is wired into `verify-all`; the package build and all three guest-VM
  system tests pass.
- [x] Route Hermes integrations and audio L2 updates through their selected
  parent profile lock transactions; each package now stages its own lock with
  the shared Hermes source pin. Tests cover profile selection and reject
  missing/ambiguous parent profiles. Their manifest now lists build, runtime
  import and package-specific CLI/Porcupine gates; the update audit rejects
  any L2/L3 manifest entry without declared verification gates. Lock refresh
  has now completed for the pinned Hermes release: integrations contains 213
  Python sdists and 1,093 Rust crates; audio contains 235 Python sdists and
  1,308 Rust crates. The full Hermes transaction applied all four profiles
  atomically after verifying every fetched artifact hash. Integrations removed
  six stale out-of-profile entries and retained source hashes are unchanged;
  audio's retained source identities and hashes are unchanged. Integrations
  then passed its complete Guix build, installed offline functional check,
  CLI help and targeted native/integration imports, and was promoted to L3.
  Audio's build and device-free smoke gates remain pending.
- [x] Track Camoufox's independent PyPI controller version and geoip/gui source
  closure with the channel-pinned uv profile adapter. The 0.5.8 refresh now
  atomically applies `uv.lock` plus a source lock covering 37 Python sdists,
  eight explicit Guix components and no Rust crates; the 51-package resolution
  and artifact hashes were checked. The prebuilt browser version/hash remains
  a reviewed exception and must be checked for compatibility by the package/VM
  smoke before promotion.
- [x] Add a focused Camoufox build/import/config/wrapper verification target
  and manifest the wheel-only providers, fpgen model and prebuilt browser
  exception. All three guest VM tests pass. The smoke launches the configured
  beta.36 browser through `camoufox.sync_api`, opens an offline data page and
  checks its title and screenshot. The gate exposed a missing GCC runtime path
  in the Hermes wrapper, which is now included and covered by the package build.
- [x] Fail closed when a dependent package is sent to the generic pin-only
  updater. `make update-prepare` now dispatches through the manifest adapter;
  direct generic preparation also refuses dependent entries, preventing a
  partial rewrite of shared parent lock modules.
- [x] Hermes dependent wave: browser-use, Camoufox and integrations are
  promoted to L3 after package and runtime gates.
- [x] Hermes audio L2→L3: refreshed lock and full package build pass. Using
  protobuf-lite fixes the ONNX Runtime/Sherpa descriptor collision; the joint
  import smoke is now part of `verify-runtime-imports.sh`. CLI, package,
  native/audio and Porcupine checks pass. Keep hardware/device checks separate.
- [x] Agent Cat L1→L2: source-hash and build the compatible crypton/TLS/X.509
  and network family; full candidate build and installed scripted smoke pass.
- [x] Agent Cat ceiling review: keep at L2. Its 24-package Hackage source
  inventory is pinned and buildable, but dependency-family refresh is currently
  curated in Guix recipes rather than regenerated by an L3 lock adapter. L3 is
  not eligible until that adapter can stage, diff and verify the complete family
  offline. The git-commit L2 prepare path generates a source-hashed pin; its
  pin renderer and NAR-hash command path are unit-tested. The committed pin is
  reproduced from the already fetched source tree.
- [x] Final verification: production Agent Cat build and isolated installed
  smoke pass; `make verify-packaging` passes lint, hygiene, locks and exceptions;
  updater tests, audit, 24-source hash checks, channel accounting, L4 policy and
  final report counts are reconciled.
- [ ] Commit the completed package families and leave a clean worktree. The
  repository `.git` directory is mounted read-only in the default sandbox.

The latest report after promotion counts one L2 entry (`agent-cat`) and no L1
entries. Agent Cat is at its current ceiling: L3 awaits the family-lock adapter
described in the ceiling review. Fifteen
dependent L3 entries are `pi-standalone`, `codex-base`, `strata-cuda`,
`overleaf-ctl`, `codex-sdk`, `codex-zsh`, `codex-voice-host`,
`codex-with-audio-and-zsh`, `codex-code-mode-host`, and
`hermes-agent-interfaces`, `hermes-agent-browser-backend-playwright`,
`hermes-agent-browser-backend-browser-use`, and
`hermes-agent-integrations`.
These rows enumerate all dependent L3 packages; there are no remaining L2
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

The live inventory has no non-exempt entry currently eligible to move higher.
Agent Cat is at L2 pending an L3 family-lock adapter; prior L2 candidates were
promoted to L3. L4 remains disabled by policy. Work in dependency order and
refresh the live report and `STATUS.md` with every promotion.

1. **Hermes core (complete, L3).** Its Python/Cargo lock is source-derived,
   reviewed and reproducible; no-grafts/no-substitutes build/check and CLI
   smokes passed.
2. **Helium L2→L3 (complete).** The nine-origin updater is complete. The
   pinned no-substitutes build and installed CLI smoke passed, reporting
   `Helium 0.19.4.1 (Chromium 155.0.8059.84)`. The existing human-review
   boundary remains for prepared Chromium/Clang tarball changes.
3. **Hermes interfaces (complete, L3-dependent).** Its 102 Python source
   identities, URLs and SHA-256 hashes reproduce from the pinned release;
   the package build compiled 764 Cargo crates, its build smoke passed, and
   installed `hermes-acp --check` plus version smoke passed. Its seven selected
   source extras are declared in the parent manifest and regenerate with the
   core lock in the same staged transaction.
4. **Hermes Playwright backend (complete, L3-dependent).** Channel-pinned
   Playwright Core and source-built Chromium pass the VM navigation/title
   smoke and installed wrapper help check.
5. **Hermes browser-use backend (complete, L3-dependent).** Its independently
   versioned PyPI source has a reproducible lock refresh (there is no upstream
   `uv.lock` at the selected tag), review its source lock, and build/smoke the
   CDP path. Its package build passed and all three guest-VM system tests,
   including the local CDP title smoke, passed.
6. **Hermes Camoufox backend (complete, L3-dependent).** The controller and
   source lock refresh preserves wheel-only components and fpgen data; the
   prebuilt browser exception is retained. Package builds and all three guest
   VM tests pass, including a beta.36 browser launch and local-page smoke.
7. **Hermes integrations (complete, L3-dependent).** The refreshed broad
   integration closure builds from source; its installed offline functional
   check, CLI help and native/integration imports pass. External service
   credentials and endpoints remain outside the build gate.
8. **Hermes audio L2→L3 (complete).** Protobuf-lite removed the ONNX
   Runtime/Sherpa descriptor collision. The full package build, joint
   device-free import, CLI, Hermes functional check, native/audio imports and
   Porcupine import pass. The source-unavailable Porcupine exception and
   separate hardware/device checks remain explicit.
9. **Agent Cat L1→L2 (complete).** Promoted reviewed main `e6d0cad` after
   source-hashing and building the crypton/TLS/X.509 and network family, then
   passing the full package build and installed scripted smoke.
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
L1 -> L2 candidates:       none remaining (agent-cat promoted)
L2 -> L3 candidates:       none currently eligible; Agent Cat needs a family-lock adapter
Independent L3:            23 promoted; Agent Cat remains L2 pending a future family-lock adapter
Dependent L3:              15 promoted; no eligible dependent remains at L2
Dependent accounting:       explicit policy, no accidental inflation
L4:                        disabled
```

The goal is not to maximize a single number.  A level is complete only when
the next update can be prepared, verified offline, and reviewed without
hand-editing generated pins or locks.
