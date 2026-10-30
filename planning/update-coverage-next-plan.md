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
L1: 2
L2: 20
L3: 17
independent L2+: 22
dependent L2+: 15
```

The facility renders real `(method git-fetch)` pins and computes recursive
checkout hashes. `camofox-browser` is now independent L3: its Node lock
reproduces and its pinned-channel build and health smoke pass. `overleaf-toolkit`
remains independent L2 and `overleaf-ctl` remains dependent L2. Remaining L1/L2
promotion work is tracked in `update-level-expansion-plan.md`.

## Policy

- L2 updates source pins only.  Lock files, native payloads and build-system
  changes remain human-reviewed.
- L3 requires a lock adapter, an offline build and a host/VM smoke.
- No L4 auto-merge.  Major, precompiled and native-payload-changing updates
  are always human-merged.
- A dependent package must name its parent in `depends_on` and never counts
  toward independent coverage.
- Large closures (Hermes, Helium, Electron/Chromium) are allowed to stay at
  L1 detection until their source pins and build gates are explicit.

## Wave 1: git-fetch pin correctness (done)

- Render `git-fetch` origins, not only `url-fetch` archives.
- Add recursive `guix hash -r` for checkout sources.
- Support commit-derived versions for repositories without a version file.
- Migrate `overleaf-toolkit`; keep `overleaf-ctl` dependent.
- Migrate `camofox-browser` to a generated pin module.

Exit: overleaf toolkit and control script build from the generated pin;
overleaf accounting is honest. Camofox was subsequently promoted to L3 after
its lock, build and health smoke passed.

## Wave 2: Hermes source line (done)

Hermes is one upstream source with several derived runtimes.  `hermes-agent`
is now the independent entry; interfaces, integrations, audio and browser
variants are dependent.

- Add a `hermes` adapter that updates only:
  - `%hermes-release` (upstream tag, e.g. `2026.9.24`);
  - `%hermes-source` URI and hash;
  - `%hermes-version` from the upstream `pyproject.toml`.
- Do not regenerate the Python/Rust lock in an L2 update.  Show the lock
  origin delta and require review when dependency pins change.
- Keep the existing `make hermes-agent` host smoke as the build gate.
- If the source tag changes but the lock cannot be reproduced offline, fail
  closed and leave the package at its current pin.

Exit: `hermes-agent` is independent L2; all Hermes variants remain dependent.
Independent L2+ is 22.  The adapter rewrites only the source tag, source hash
and Python version; dependency locks stay for review.

## Wave 3: Helium detector before pin automation (detector done)

Helium is assembled from multiple origins, not one source archive:

- `imputnet/helium` commit;
- `imputnet/helium-linux` commit;
- Chromium base and linux-x64 tarballs;
- nonfree search engines, onboarding, uBlock and esbuild assets;
- Debian patch branch.

Do not pretend this is a single git pin.

1. Add an L1 detector for the Helium release line and report the component
   versions side by side.
2. Add a manifest `components` block only after each origin has a symbol and
   a hash check.
3. A future `helium` adapter updates the whole component set atomically, or
   refuses the update.
4. Never auto-merge Chromium, Clang or prepared-tarball changes.

Exit: Helium updates are visible in detect/report even while manual review is
required.  `scripts/update/helium.py` reports the helium commit, helium-linux
commit, Chromium version, Debian branch, assets and upstream release tags;
`make update-detect-helium` and the detect workflow run it.  Promotion to L2
only when all component hashes are generated from one manifest transaction.

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
