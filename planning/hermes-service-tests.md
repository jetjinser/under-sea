# Hermes service-level test plan

Status: **service and offline end-to-end test passes 7/7 assertions** as of
2026-11-01. Package-level and service-level Hermes checks pass. Author:
under-sea maintenance. Scope:
exercise the Hermes components as *services* (boot real Guix systems, run
shepherd services, verify functional behaviour), on top of the existing
package-level smoke checks.

## Implementation notes (Phases 1–3)

- The gateway service runs **`hermes gateway start`** (the upstream start
  subcommand).  An earlier draft ran the bare `hermes gateway`, which prints
  usage and exits; and a draft carrying `#:environment-variables`,
  `#:directory` and `apply` in the start gexp silently failed to register in
  the guest shepherd (the boot-time loader swallows per-file load errors).
  The working shape is the plain adsk-style
  `make-forkexec-constructor` form; channel credentials belong in the
  gateway's own configuration under the state directory.
- Current assertion set in `%test-under-sea-hermes`: service start,
  state-directory ownership, gateway process identity (30 s polling window),
  Shepherd configuration diagnostics, mock model availability, offline agent
  turn, and a non-empty gateway log. All seven passed in the latest VM run.

## Why

The service VM test complements package-level checks by booting Hermes under
Shepherd and checking its account, state directory, process, and offline model
request path. ACP/dashboard-specific deployment modes remain separate work.
The VM test follows the repository's existing service patterns:
`services/adsk-licensing.scm` + `system/adsk-licensing.scm` +
`tests/adsk-licensing.scm` (marionette VM, service lifecycle) and
`tests/browser.scm` (in-guest real-client end-to-end).

## Test prerequisites

- `hermes-agent` (and variants) rebuilt locally: outputs were GC'd; the
  package needs a full rebuild before any VM test (the VM imports the
  packages into the guest system closure).
- QEMU under the guix daemon works on this host (proven by the adsk test).
- Hermes features requiring a live model and external credentials remain out
  of scope; the test uses an in-guest mock model.

## Phase 1 — `(under-sea services hermes)`

A service definition following the adsk-licensing pattern. The implemented
configuration exposes the package, state directory, service user/group,
gateway arguments, and extra environment variables:

- Long-running entry point: **`hermes gateway start`** (confirmed from the upstream
  README — "Start the messaging gateway (Telegram, Discord, etc.) … all from a
  single gateway process"; the service also serves the built-in cron
  scheduler, so it stays useful without any messaging channel).
- Shepherd service: unprivileged `hermes` account, state directory chown in
  `start`, log file under `/var/log/hermes.log`, `respawn? #t`,
  `(requirement '(networking user-processes))`.
- Activation extension: create `HERMES_HOME`/state directory.
- Account extension: system `hermes` user/group with nologin shell.

## Phase 2 — `(under-sea system hermes)`

`%under-sea-hermes-os`: minimal operating-system (static networking like
`%under-sea-adsk-networking`, a `tester` account, `%base-services`/packages)
instantiating the Hermes service.  Keep the guest offline; everything under
test is local.

## Phase 3 — `(under-sea tests hermes)` marionette test

One system test, `%test-under-sea-hermes`, with these assertions:

1. **Lifecycle**: `start-service 'hermes` returns a running Shepherd service.
2. **Identity**: the engine process runs as the `hermes` user (same
   `/proc`-walk pattern as the adsk test; 30 s polling window).
3. **State**: `HERMES_HOME`/state directory exists and is owned by `hermes`.
4. **Diagnostics**: captures Shepherd configuration to diagnose guest
   startup failures.
5. **Mock model**: the in-guest OpenAI-compatible server accepts connections.
6. **Offline agent turn**: the gateway completes a mocked model turn and local
   tool call.
7. **Log**: `/var/log/hermes.log` exists and is non-empty.

Register in `scripts/verify-system.sh` next to the browser test:

    run_system_test hermes '(@ (under-sea tests hermes) %test-under-sea-hermes)'

## Offline full-path E2E — passing

The test runs a mock OpenAI-compatible server inside the guest and points the
service at it, then asserts a full agent turn: request → model mock → tool
execution (LocalEnvironment) → response. The mock emits OpenAI-compatible
server-sent events, including a tool call followed by a final response. The
VM test passes all seven assertions without network access.

## Follow-up (separate from this plan): repo-wide local-file robustness

While preparing this plan, a latent hazard was found and partially fixed:
`local-file "../../../scripts/…"` fails with
`canonicalize-path: No such file or directory` when the package modules are
compiled from a *relative* `-L` load path (the baked source directory can
end up empty).  ~140 references across ~40 modules share it.

- Done: `hermes.scm` embeds its three build scripts inline as `plain-file`;
  `scripts/check-hermes.py`, `scripts/build-hermes.py` and
  `scripts/import-hermes-python-components.py` were deleted.
- Done: new helper module `(under-sea gexp)` provides `under-sea-script`,
  which reads `scripts/<name>` at macro expansion and expands to a
  `plain-file` — robust to relative `-L` and any working directory.  The
  hermes-agent-audio closure (hermes-tflite/sherpa/onnx/emscripten-tools)
  is migrated and verified to compute with a relative `-L`.
- Interim rule: always build through the Makefile (absolute
  `-L $(CURDIR)/modules`).  Never hand-run `guix build -L modules` with a
  relative path outside the repository root.
- Recommended follow-up: migrate the remaining ~135 `local-file
  "../../../scripts/…"` call sites to `under-sea-script` (mechanical; a
  dry-run walk reports each site as the closure is computed).

## Effort

- Phases 1–3: about a day (service + OS + test follow the existing patterns
  closely; the main unknown is the exact long-running CLI mode).
- Phase 4: half a day on top.
- local-file follow-up: mechanical, about half a day repo-wide.
