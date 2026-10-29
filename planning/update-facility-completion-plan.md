# Update facility completion plan

This plan turns the current update framework into a facility that can maintain
the whole user-facing package set, not just the six packages already in the
manifest.  The target is not "merge every upstream change without a human";
it is to automate every deterministic step and leave only the genuinely
judgement-heavy parts for review.

## Definition of done

The facility is complete when:

- every user-facing package has an explicit entry in
  `planning/update-manifest.json`, or an explicit L0/L1 exemption with a reason;
- detection covers each package's upstream and product line;
- deterministic preparation is automated: source pin, source hash, lock
  closure, native-payload inventory, exception diff and docs;
- every L2/L3 package has a declared build/test command;
- CI runs detect, prepare, verify and VM jobs with network/signing isolation;
- publish creates a signed PR and never auto-merges major or precompiled
  updates;
- `make update-audit` fails when a package is missing from the manifest or an
  exemption;
- the regular CI gates remain green after an update PR.

## Current state

Implemented:

- manifest and detect for kilocode, opencode-v1/v2, marimo, seaweedfs and loro;
- generated `*-pin.scm` modules;
- generic GitHub/PyPI prepare;
- Bun, Go and Cargo adapters;
- dependency-aware verify and VM dispatch;
- detect/prepare/verify/vm/publish workflow skeletons;
- resilient npm downloads with retries and mirror fallback.

Proven end to end:

- kilocode 7.8.12 -> 7.8.20;
- Loro Cargo lock and SeaweedFS Go lock reproduce the checked-in locks.

Gaps:

- only six packages are in the manifest;
- most build-system-specific packages have no adapter;
- publish has not run against a real protected environment;
- no audit prevents new packages from bypassing the facility;
- no per-package update policy beyond the autonomy field.

## Workstream 1: inventory and classification

Create `planning/update-exemptions.json` and `scripts/update/audit.py`.

For every package exposed in README/STATUS, record:

- package/module name;
- upstream type and tag/product line;
- build family: GitHub tarball, PyPI, npm/Bun, Cargo, Go, precompiled;
- autonomy level (L0-L4);
- reason for any L0/L1 exemption;
- owner/review requirement.

Start with the user-facing set, not the internal Hermes dependency family.
Internal `%...` and `python-hermes-*` packages are excluded by rule.

`make update-audit` should:

- enumerate the declared user-facing package list;
- verify each has a manifest entry or exemption;
- validate manifest fields and pin paths;
- fail on duplicates and unknown modules.

## Workstream 2: generic L2 coverage

For simple GitHub/PyPI packages, automate:

- tag/release detection;
- source archive + hash;
- generated pin module;
- docs/version-table update;
- PR creation after CI.

This should cover packages such as pydantic-ai, marimo, seafile core and other
plain tarball/PyPI recipes.  No lock adapter is needed for L2; a human still
handles dependency/build changes.

## Workstream 3: L3 lock families

Implement or harden adapters per family, reusing existing lockers:

- **Bun**: kilocode, opencode-v1/v2, and any Bun-based Pi/Hermes package that
  is not precompiled.
- **Go**: SeaweedFS first, then other Go packages after inventory.
- **Cargo**: Loro and Rust-based CLIs such as codex/agent-browser if their
  Cargo locks are reproducible.
- **Python sdist + native crates**: Loro-style packages.
- **Precompiled**: Ghidra, Electron/Hermes payloads, Bun bootstrap, proprietary
  clients stay L0/L1 and are never auto-merged.

Each L3 package needs:

- a lock script and generated lock file;
- a native-payload inventory;
- an offline build;
- a host smoke and, where applicable, a VM test;
- an exception diff in the PR body.

## Workstream 4: verification matrix

Define three tiers:

1. **host**: `guix build --no-substitutes`, version/help/completion;
2. **integration**: MCP/stdin, service start, CLI against a local fixture;
3. **VM**: system services, FUSE, browser, opencode.

The manifest's `tests` field should name the exact commands.  A package cannot
reach L3 without at least a host build and a smoke test; service/desktop
packages need a VM test or an explicit skip reason.

## Workstream 5: CI and release

Configure a self-hosted Guix runner and a KVM-capable runner.

Jobs:

- `update-detect`: scheduled, read-only, uploads a JSON report;
- `update-prepare`: network-enabled, no signing key, uploads pin/lock/test plan;
- `update-verify`: offline, applies the artifact, runs gates;
- `update-vm`: KVM-only, runs declared VM tests;
- `update-publish`: protected environment, imports the GPG key, creates a
  signed commit and PR.

Required repository settings:

- protected `update-publish` environment with required reviewers;
- `UPDATE_GPG_PRIVATE_KEY` secret;
- branch protection and required checks;
- GitHub App/token with minimal contents/PR permissions;
- no untrusted fork code on self-hosted runners.

Release policy:

- one package/line per PR;
- human merge for major, precompiled and native-payload changes;
- L4 auto-merge only for patch/minor after a stable track record;
- no automatic channel-wide pin updates.

## Workstream 6: observability

Add a generated report:

```sh
make update-report
make update-detect > update-report.json
```

Track:

- packages current/outdated/error;
- last successful update per package;
- lock origin delta;
- exception changes;
- test skips and failures;
- PR age.

Open a tracking issue for packages with no adapter or repeated failures.

## Rollout phases

### Phase A: inventory and audit (done)

- [x] Enumerate user-facing packages (44 in the initial inventory).
- [x] Add `planning/update-exemptions.json`.
- [x] Add `scripts/update/audit.py` and `make update-audit`.
- [x] Classify the initial inventory; 8 are now in the manifest and 36 are
  explicit L0-L3 exemptions.
- [x] Audit runs in the detect and verify workflows.

Exit: audit passes; every package is classified.

### Phase B: detection and L2 (started)

- [x] Add upstream metadata and generated pin modules for seafile and
  seafile-server.
- [x] Support `allow_prerelease` and tag-version regexes for server tags.
- [x] Run the local detect/audit suite; the detect-only workflow now runs the
  audit first.
- [ ] Run detect-only CI for two weeks and fix false positives.
- [x] Add Seafile client/server, Strata and Pi as available L2 packages.
- [x] Add a generic `github-release` upstream type and Pi asset pin adapter.
- [x] Add dependent L2 entries for pi-standalone, strata-cuda, codex-base and
  codex-with-audio-and-zsh; they follow their parent pin.
- [x] Add the generic git-commit adapter and codex-session-patcher L2 coverage.
- [ ] Add vimium-c and ivy git-commit coverage.
- [ ] Enable prepare/verify PRs for all L2 packages.

Exit: every L2 package can produce a verified pin PR.

### Phase C: L3 lock adapters (core done)

- [x] Bun: kilocode, opencode v1/v2.
- [x] Go: SeaweedFS.
- [x] Cargo: Loro.
- [x] Python/native: Loro-style crates.
- [x] Add native-payload inventory diff; applying a change requires
  `--accept-native-change`.
- [x] Add the npm adapter and promote REA to L3 (6.7.0 -> 6.8.0 detected).
- [x] Add the npm adapter and promote REA to L3.
- [x] Generalize the Go adapter and add sing-box L3 coverage.
- [x] Add the Codex Cargo adapter and L3 coverage.
- [x] Add the generic Cargo lock adapter and agent-browser L3 coverage.
- [x] Add the dae Go adapter (source + BPF headers) and L3 coverage.
- [ ] Extend adapters to pi and other special Bun/native packages; these stay
  L1 until their lock scripts are generalized.
- [ ] Add host/VM tests for every promoted package.

Exit: every L3 package can regenerate its lock and pass host/VM tests.

### Phase D: publish dry run (started)

- [x] Add `scripts/update/publish.py` and
  `make update-publish-dry-run PACKAGE=... VERSION=...`.
- [x] Add a `dry_run` input to `update-publish`; it prints the branch, commit,
  push and PR commands without signing or pushing.
- [ ] Configure the runner, environment, GPG key and branch protection
  (repository-external).
- [ ] Run `update-publish` on a non-production package.
- [ ] Verify the PR body, signature and checks.
- [ ] Enable L3 PRs for maintainers.

Exit: a signed PR is created and merged through the normal review path.

### Phase E: autonomy

- [ ] Measure update success/failure and false-positive rate.
- [x] Add a coverage/autonomy report and upload it from the detect workflow.
- [ ] Collect real CI history; L4 remains disabled until then.
- [ ] Keep major/precompiled updates human-gated.
- [ ] Document per-package policy in the manifest.

Exit: L4 is opt-in, reversible and limited.

## P0 hardening

- [x] Transactional apply: prepare and verify in a temporary git worktree,
  then copy pin/lock into the real tree; failed verification leaves no changes.
- [x] Lock determinism: `--determinism` runs the adapter twice and compares
  pin/lock output.
- [x] Guile tests: `scripts/update/test-scheme.scm` covers manifest, audit,
  tag selection, coverage, version ordering and pin rendering.

## Scheme orchestration migration

The public audit and coverage commands now use Guile Scheme:

```sh
guile -L scripts/update -s scripts/update/audit.scm
guile -L scripts/update -s scripts/update/report.scm
```

The manifest reader, audit, coverage report, detector, L2 pin preparation and
update orchestrator are Scheme.  The npm/Bun/Go/Cargo lockers remain behind the
adapter boundary; Python is no longer the public entry point.

## Unified entry point

`scripts/update/update.py` (and `make update`) is the single entry point:

```sh
make update PACKAGE=kilocode                 # dry-run
make update PACKAGE=kilocode APPLY=1 VERIFY=1
make update PACKAGE=kilocode APPLY=1 VERIFY=1 COMMIT=1
make update ALL=1                            # dry-run every package
```

It detects the latest version, skips L0/L1 packages, dispatches to the right
adapter, applies only complete results, optionally builds, optionally runs the
VM test, and optionally creates a signed title-only commit.

## Immediate next steps

1. Generate the user-facing inventory and add `make update-audit`.
2. Add every package to the manifest at L0/L1 so nothing is invisible.
3. Promote simple GitHub/PyPI packages to L2.
4. Promote the already-proven Bun/Go/Cargo packages to L3.
5. Only then configure publish and consider L4.

## Success metrics

- 100% of user-facing packages classified.
- 0 packages missing from manifest/exemptions.
- >=80% of non-precompiled packages at L2 or higher.
- L3 packages pass offline build + declared smoke/VM tests.
- Median update PR is created without manual pin/lock work.
- No partial lock or unsigned commit can be published.
- Major/precompiled updates always require human review.
