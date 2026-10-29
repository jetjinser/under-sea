# Update level expansion goal

This is the long-run plan for every package that can move up an autonomy
level but has not done so yet.  It is intentionally separate from
`update-coverage-next-plan.md`: that plan widened independent coverage to 22;
this plan deepens automation and closes the remaining level gaps.

## Baseline

```text
inventory: 45
L0: 7
L1: 1
L2: 27
L3: 10
independent L2+: 22
dependent L2+: 15
L4: disabled
```

The only hard blocks are the two proprietary, user-supplied archives:
`adsk-licensing` and `moldflow-insight-thinclient`.  Everything else is either
policy-gated, build-gated, or simply not implemented yet.

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

### C3. camofox-browser (partial, L2)

- [x] `camofox-node-lock.scm` is wired into the manifest as the intended L3
  lock artifact; `scripts/lock-camofox.py` wraps the Node source lock.
- [x] Add a dedicated `camofox` update adapter that writes both the source pin
  and the Node lock.
- [ ] Reproduce the lock: npm registry and npmmirror are currently unreachable
  from this host (`curl` status 7); the lock remains checked in but not
  regenerated.
- [ ] The full build previously exceeded the 15-minute local budget while
  rebuilding Node dependencies.
- Exit: lock regeneration reproduces the checked-in lock, then a full build
  and REST-server smoke pass.  Stay at L2 until both gates pass.

### C4. marimo

- Generate and verify a Python dependency lock; keep Loro/RTC propagation
  visible.
- Add a host smoke and, where applicable, the existing VM service test.
- Exit: lock origin delta is reviewed; `make marimo` plus service smoke pass.

### C5. seafile and seafile-server

- Add reproducible Python/C dependency locks and keep `libsearpc` versions
  distinct (client 3.2.0, server 3.3).
- Build offline; run CLI/service smoke.
- Exit: both packages build from locks; client and server pins can move
  independently.

### C6. pi (partial, L2)

- [x] Add `scripts/lock-pi.py` and `scripts/update/pi.py`; the adapter renders
  both release assets (source and install lock) and regenerates the Node lock.
- [x] Add `pi --version` as the package smoke.
- [ ] Lock regeneration is waiting for npm registry connectivity; the checked-in
  `pi-node-lock.scm` is not yet re-verified.
- [ ] Full package build and smoke still need to pass.
- Exit: release pin + payload diff + host CLI smoke pass.

### C7. strata

- Add a Python/native dependency lock and payload audit.
- Keep AMD/HIP and CUDA variants dependent.
- Exit: source pin + lock + offline build + smoke; CUDA variant remains
  dependent.

### C8. hermes-agent

- Reuse the source adapter; add lock regeneration through `lock-hermes.py`.
- Require an origin delta and native/Cargo audit before applying.
- Keep interfaces/integrations/audio/browser variants dependent.
- Exit: source update + deterministic lock + offline core build + smoke.

### C9. vimium-c

- Add an npm lock for the TypeScript build and a deterministic build gate.
- Do not regress to the codeload tarball path; the git-fetch checkout is
  intentional.
- Exit: lock reproduces, build is deterministic, extension manifest check
  passes.

### C10. not recommended for L3

- `overleaf-toolkit`: copy-build plus external Docker images; there is no
  meaningful dependency lock.  Keep L2.
- `python-ms-ivy`: no package-manager lock worth adding; keep L2 unless a
  concrete reproducibility gap appears.

## Workstream D: dependent level accounting (conservative policy chosen)

The six Codex components are currently L2 while their parent `codex` is L3:

- `codex-base`
- `codex-with-audio-and-zsh`
- `codex-sdk`
- `codex-voice-host`
- `codex-code-mode-host`
- `codex-zsh`

Decide and enforce one policy:

1. **Inherited**: mark them L3-dependent and never count them as independent.
2. **Conservative**: keep L2 and document that their builds carry separate
   native/audio payloads.

Decision: **conservative**.  Keep the six components at L2 because they have
separate native/audio/SDK build paths even though they consume the parent
lock.  The manifest, report, and a new test enforce that no dependent exceeds
its parent and that all six stay L2.  `pi-standalone` and `strata-cuda` stay L2
because their parents are L2.

## Feasibility audit (2026-10-29)

Not every L2 package can reach L3 by wiring an existing lock.  The current
status of the remaining candidates is:

| Package | Lock status | Blocker |
|---|---|---|
| `camofox-browser` | `camofox-node-lock.scm` exists; `lock-camofox.py` wired | npm registries are intermittently unreachable; full build is long |
| `pi` | `pi-node-lock.scm` exists | no generator wired yet; npm network |
| `hermes-agent` | `hermes-lock.scm` exists | source-only adapter; lock regeneration and full build are very large |
| `vimium-c` | no npm lock | npm/TypeScript lock must be designed |
| `marimo` | no upstream `uv.lock`; uses Guix package inputs | an L3 lock must either map the PyPI closure or record channel inputs; both are design work |
| `seafile` / `seafile-server` | no upstream lock | same design work, plus C/Python build |
| `strata` | no upstream lock | same design work, plus CUDA-dependent audits |
| `overleaf-toolkit` | not applicable | copy-build + external Docker images; stay L2 |
| `python-ms-ivy` | no package-manager lock | stay L2 |

The audit is deliberately conservative: an L3 label is not assigned when the
only available artifact is an unverified checked-in lock or a channel pin that
does not participate in the package build.

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

## Order of work

1. A1 agent-cat L1.
2. C1 codex-session-patcher L3.
3. C2 qwenimage L3.
4. C3 camofox L3.
5. B helium atomic L2.
6. C4 marimo L3.
7. C5 seafile family L3.
8. D dependent-level policy.
9. C6 pi L3.
10. C7 strata L3.
11. C8 Hermes L3.
12. C9 vimium-c L3.
13. A2 precompiled L1 detection, only if policy approves.

## Success metrics

```text
Hard-blocked L0:            2  (adsk-licensing, moldflow)
L1 additions:              >= 2  (agent-cat; optional precompiled detection)
Helium:                    L2 with atomic component transaction
Independent L3:            >= 16 (from 10)
Dependent accounting:       explicit policy, no accidental inflation
L4:                        disabled
```

The goal is not to maximize a single number.  A level is complete only when
the next update can be prepared, verified offline, and reviewed without
hand-editing generated pins or locks.
