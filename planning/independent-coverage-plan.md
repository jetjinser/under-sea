# Independent coverage plan

Historical plan: its initial 44-package counts and target are preserved below
to explain the coverage work already completed. For current counts, consult
`guile --no-auto-compile -L scripts/update -s scripts/update/report.scm`;
for the live L1/L2 promotion backlog, see
[`update-level-expansion-plan.md`](update-level-expansion-plan.md).

At the time this plan was written, the report said 20/44 packages were at L2+,
but four of those were
dependent variants (`pi-standalone`, `strata-cuda`, `codex-base`,
`codex-with-audio-and-zsh`).  The real independent coverage is 16/44.  This
plan raises independent coverage without inflating the number with derived
packages.

## Target

```text
L0: 7
L1: 10–12
independent L2+: 22–24
dependent L2+: 4–6
```

The primary success metric is **independent L2+**, not total L2+.

## Phase 1: separate independent and dependent coverage

- Add an `independent` boolean to each manifest entry, defaulting to `#t`.
- Mark the four current derived packages as dependent.
- Extend `scripts/update/report.scm` and the JSON report:
  - `independent-l2-plus`
  - `dependent-l2-plus`
  - total counts by level.
- Update the Scheme test expectations and README.
- Add an audit check: a dependent package must reference a parent package in
  the manifest and must not be counted as independent.

Exit: report distinguishes independent and dependent coverage; current
independent count is 16. (done)

## Phase 2: git-fetch adapter

The git-commit adapter currently supports url-fetch archives only.
`vimium-c` and `python-ms-ivy` use `git-fetch`, so they remain L1.

- Extend `scripts/update/git.scm` with `source_method: "git-fetch"`.
- For git-fetch:
  - clone or archive the exact commit;
  - remove `.git`;
  - compute the recursive sha256 with `guix hash -r`;
  - render `(method git-fetch)` with a `git-reference` and base32 hash.
- Add `vimium-c-pin.scm` and `ivy-pin.scm` modules.
- Migrate both recipes to the pin modules.
- Keep the existing version-file detection (`manifest.json` for vimium-c,
  `pyproject.toml` or the module `__init__.py` for ivy).
- Test current commits reproduce the checked-in hashes before promoting.
- Promote both to independent L2.

Exit: vimium-c and ivy build from generated pins; independent L2+ is 18. (done)

## Phase 3: qwenimage L2

`qwenimage-ncnn-vulkan` is a git commit plus a pinned ncnn submodule.

- Add a pin module for the main qwenimage commit.
- Keep the ncnn submodule pin explicit in the manifest, not silently updated.
- L2 updates only the main commit; a submodule change forces human review.
- Add a host smoke that checks the binary starts.

Exit: qwenimage is independent L2; independent L2+ is 19. (done)

## Phase 4: overleaf-ctl L2

`overleaf-ctl` follows the overleaf-toolkit commit.

- Add a pin module for the toolkit commit.
- Use the existing git-commit adapter with `source_method: "git-fetch"`.
- `overleaf-ctl` remains a dependent package if it has no separate source.
- If the wrapper has no independent upstream, keep it dependent and do not
  count it as independent.

Exit: toolkit update is mechanical; coverage accounting is honest. (done:
`overleaf-toolkit` is independent L2, `overleaf-ctl` is dependent, and the
git-fetch adapter now renders a real git checkout pin.)

## Phase 5: codex component accounting

The codex components are derived from the codex source:

- `codex-base`
- `codex-sdk`
- `codex-voice-host`
- `codex-code-mode-host`
- `codex-zsh`
- `codex-with-audio-and-zsh`

- [x] Mark all as dependent on `codex`.
- [x] Add dependent entries for `codex-sdk`, `codex-voice-host`,
  `codex-code-mode-host` and `codex-zsh`.
- Do not count them toward independent coverage.

Exit: dependent coverage is explicit; no metric inflation.

## Phase 6: verification and docs

- [x] `make update-audit`
- [x] Python + Scheme tests
- [ ] `make verify-ci`
- Update `README.md`, `STATUS.md`, `planning/update-facility-completion-plan.md`
- Commit one slice at a time with signed title-only messages.

## Non-goals

- No L4 auto-merge.
- No automatic update of precompiled packages.
- No forced promotion of Hermes/Helium/Camofox/browser backends.
- No rewrite of Python lockers.

## Risks

- `git-fetch` recursive hashes can differ from codeload hashes; always compare
  against the current pin before applying.
- Ivy's version file may move; fail closed rather than guessing.
- qwenimage submodule changes must remain human-gated.
- Dependent packages can make coverage look better than it is; the report must
  keep the two categories separate.
