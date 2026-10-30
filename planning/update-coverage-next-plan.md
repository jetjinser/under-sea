# Update coverage expansion plan

The long-run plan for raising existing L1/L2 packages to L2/L3 is
[`update-level-expansion-plan.md`](update-level-expansion-plan.md).

This plan continues `planning/independent-coverage-plan.md` after the
independent/dependent split, git-fetch and git-tag adapters, and qwenimage
submodule gating.  The objective is to move more real upstream sources under
the update facility without inflating coverage with wrappers or derived
packages.

## Current state

Live snapshot as of 2026-10-30. For level and coverage counts, the update
report is authoritative; `update-level-expansion-plan.md` owns the current
promotion backlog.

```text
inventory: 45
L0: 6
L1: 1
L2: 7
L3: 31
independent L2+: 23
dependent L2+: 15
```

The facility renders real `(method git-fetch)` pins and computes recursive
checkout hashes. `camofox-browser` is independent L3: its Node lock reproduces
and its pinned-channel build and health smoke pass. `overleaf-toolkit` is
independent L3; `overleaf-ctl` is dependent L3 with channel-pinned runtime
inputs. Remaining L1/L2
promotion work is tracked in `update-level-expansion-plan.md`.

## Policy

- L2 updates source pins only.  Lock files, native payloads and build-system
  changes remain human-reviewed.
- L3 requires a lock adapter, an offline build and a host/VM smoke.
- No L4 auto-merge.  Major, precompiled and native-payload-changing updates
  are always human-merged.
- A dependent package must name its parent in `depends_on` and never counts
  toward independent coverage.
- Large closures (Hermes and Helium/Chromium) advance only when their source
  locks, no-substitutes builds and package smokes pass; current remaining gates
  are tracked in `update-level-expansion-plan.md`.

## Wave 1: git-fetch pin correctness (done)

- Render `git-fetch` origins, not only `url-fetch` archives.
- Add recursive `guix hash -r` for checkout sources.
- Support commit-derived versions for repositories without a version file.
- Migrate `overleaf-toolkit`; keep `overleaf-ctl` dependent.
- Migrate `camofox-browser` to a generated pin module.

Exit: overleaf toolkit and control script build from the generated pin;
overleaf accounting is honest. Camofox was subsequently promoted to L3 after
its lock, build and health smoke passed.

## Wave 2: Hermes source line and lock (complete)

Hermes is one upstream source with several derived runtimes.  `hermes-agent`
is now the independent entry; interfaces, integrations, audio and browser
variants are dependent.

- Add a `hermes` adapter that updates:
  - `%hermes-release` (upstream tag, e.g. `2026.9.24`);
  - `%hermes-source` URI and hash;
  - `%hermes-version` from the upstream `pyproject.toml`.
- Regenerate the complete Python/Cargo source lock from the same release
  archive in a staged transaction, with bounded download concurrency and
  atomic apply. The pinned release reproduces byte-for-byte (62 Python sdists,
  746 Cargo crates).
- Build/check the Hermes core with no substitutes and run the installed CLI
  and runtime smokes before promoting it to independent L3.

Exit: `hermes-agent` is independent L3; all six additional Hermes runtimes
remain dependent L2 until their individual lock/build/smoke gates pass.
Independent L2+ remains 23: Hermes moved from L2 to L3 without changing the
coverage count.

## Wave 3: Helium atomic source transaction (complete)

Helium is assembled from multiple origins, not one source archive:

- `imputnet/helium` commit;
- `imputnet/helium-linux` commit;
- Chromium base and linux-x64 tarballs;
- nonfree search engines, onboarding, uBlock and esbuild assets;
- Debian patch branch.

Do not pretend this is a single git pin.

1. Add a manifest inventory with a value and base32 hash for all nine origins.
2. The `helium` adapter validates the complete candidate and writes the one
   Scheme source file atomically, or refuses it without partial edits.
3. Compare old/new component values and hashes in the dry-run report.
4. Never auto-merge Chromium prepared-tarball changes; Clang remains pinned to
   the human-reviewed channel.

Exit: `scripts/update/helium.py` reports all nine exact values and hashes. A
full current-candidate dry run lists all nine unchanged origins, and tests
prove a partial candidate or Chromium tarball change is rejected before any
pin is written. `make update-helium CANDIDATE=... APPLY=1` applies one complete
candidate transaction.

## Wave 4: browser backends and camofox (camofox complete)

- `camofox-browser` is independent L3 with a generated Node lock and health
  smoke.
- Keep `hermes-browser-backend-*` dependent on their runtime packages.
- `hermes-agent-browser-use` may become an independent L2 only if its PyPI
  source pin is decoupled from the Hermes source line; otherwise keep it
  dependent.
- Browser binaries remain external/precompiled and never auto-merge.

## Wave 5: verification and publication

For every promoted package:

- `make update-audit`;
- Python and Scheme update tests;
- package build with `--no-substitutes`;
- host smoke or explicit skip reason;
- `make verify-ci` where the build budget allows;
- signed title-only commit, one package family per commit.

## Historical target

The following target belongs to the original coverage-expansion wave; it is
not the current live baseline. Use the update-level plan for current goals.

```text
L0: 7
L1: 6–8
independent L2+: 22–24
dependent L2+: 10–12
L4: disabled
```

## Historical next steps

This list is retained as history; current work is ordered in
`update-level-expansion-plan.md`.

1. Re-run the camofox build on a warm cache and record the result. (Done;
   pinned-channel build and health smoke pass.)
2. Add the Helium component detector without changing its L1 autonomy. (Done;
   detector exists, atomic L2 promotion remains planned.)
3. Add a Hermes source update dry-run to the update CI workflow.
4. Update `README.md`, `STATUS.md` and the coverage report after each wave.
