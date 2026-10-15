# Hermes service-level test plan

Status: **Phases 1–3 implemented and passing** (`%test-under-sea-hermes`:
4/4 assertions).  Phase 4 proposed.  Author: under-sea maintenance.  Scope:
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
- Final assertion set in `%test-under-sea-hermes`: lifecycle
  (`herd start`), state-directory ownership, gateway process running as the
  `hermes` account (30 s polling window), log file non-empty, plus a
  diagnostics dump of the guest shepherd's registered services.

## Why

Today the Hermes components are verified only as packages: the build runs
`hermes --help` and the embedded `check-hermes.py` functional smoke against
the installed runtime.  Nothing boots Hermes as a service, so lifecycle
handling (state directories, account, restart), the long-running entry points
(ACP server, dashboard) and the service environment (env vars, HOME, PATH)
are untested.  The repo already has the full pattern for this:
`services/adsk-licensing.scm` + `system/adsk-licensing.scm` +
`tests/adsk-licensing.scm` (marionette VM, service lifecycle) and
`tests/browser.scm` (in-guest real-client end-to-end).

## Preconditions

- `hermes-agent` (and variants) rebuilt locally: outputs were GC'd; the
  package needs a full rebuild before any VM test (the VM imports the
  packages into the guest system closure).
- QEMU under the guix daemon works on this host (proven by the adsk test).
- Hermes features that require a live model stay out of scope for the base
  plan; Phase 4 adds an offline mock-model path.

## Phase 1 — `(under-sea services hermes)`

A service definition following the adsk-licensing pattern:

- `hermes-configuration` record: `hermes-agent` package, `interfaces`
  package (dashboard/ACP dependencies), `state-directory`
  (default `/var/lib/hermes`), `user`/`group` (default `hermes`), `port`
  (default 8089), `mode` (`acp` | `dashboard`).
- Long-running entry point: **`hermes gateway`** (confirmed from the upstream
  README — "Start the messaging gateway (Telegram, Discord, etc.) … all from a
  single gateway process"; the service also serves the built-in cron
  scheduler, so it stays useful without any messaging channel).
- Shepherd service: unprivileged `hermes` account, state directory chown in
  `start`, log file under `/var/log/hermes.log`, `respawn? #t`,
  `(requirement '(networking))`.
- Activation extension: create `HERMES_HOME`/state directory.
- Account extension: system `hermes` user/group with nologin shell.

## Phase 2 — `(under-sea system hermes)`

`%under-sea-hermes-os`: minimal operating-system (static networking like
`%under-sea-adsk-networking`, a `tester` account, `%base-services`/packages)
instantiating the Hermes service.  Keep the guest offline; everything under
test is local.

## Phase 3 — `(under-sea tests hermes)` marionette test

One system test, `%test-under-sea-hermes`, with these assertions (final set,
all passing):

1. **Lifecycle**: `herd start hermes` succeeds; `herd status` reports running.
2. **Identity**: the engine process runs as the `hermes` user (same
   `/proc`-walk pattern as the adsk test; 30 s polling window).
3. **State**: `HERMES_HOME`/state directory exists, owned by `hermes`, and
   the service initialized its database there (file existence).
4. **Log**: `/var/log/hermes.log` exists and is non-empty.
0. **Diagnostics** (first): dumps the guest shepherd's registered services,
   proving which services registered at boot.

Register in `scripts/verify-system.sh` next to the browser test:

    run_system_test hermes '(@ (under-sea tests hermes) %test-under-sea-hermes)'

## Phase 4 — offline full-path E2E (optional, strongest)

Real agent turns need a model.  To keep everything offline, run a
mock OpenAI-compatible server *inside the guest* (a ~40-line
`http.server` script emitting a fixed completion), point the service at it
via the model SDK's base-url configuration, and assert a full agent turn:
request → model mock → tool execution (LocalEnvironment) → response.
This exercises the complete request path, including the model SDK layer,
with zero network.

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
