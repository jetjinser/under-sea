# Independent follow-up tasks

This file splits the work that was deliberately left out of the standalone
packages goal into independently schedulable tasks.  Each task has its own
scope, validation and exit criteria, so a failure or a long build in one task
does not block the others.

The completed standalone work is tracked in
[`standalone-packages-plan.md`](standalone-packages-plan.md).  The current CI
subset is:

```sh
guix shell make -- make verify-ci
```

## Task matrix

| ID | Task | Priority | Size | Depends on |
|---|---|---|---|---|
| T1 | Seafile web stack (Seahub + seafdav + server bindings) | P2 | large | Seafile server core |
| T2 | REA source build | P2 | medium/large | existing REA npm package |
| T3 | Frida integration | P3 | large | T2 (optional) |
| T4 | opencode VM CPU/CI fix | P1 | done | existing opencode VM test |
| T5 | pydantic-ai/httpx2 refresh | P2 | done | current pydantic-ai stack |
| T6 | Qt5 / Seafile GUI | not scheduled | very large | Qt5 package set |

Recommended order: **T4 -> T5 -> T2 -> T1 -> T3**.  T6 is intentionally not
scheduled; see the note at the end.

## T1: Seafile web stack

**Goal:** provide a supported Guix deployment of Seahub (web UI) and seafdav
(WebDAV), backed by the already packaged `seafile-server` core.

**Scope**

- Enable or separately package the Seafile Python bindings (`seaserv` and the
  related `ccnet` modules).  The current `seafile-server` recipe deliberately
  disables Python bindings.
- Package `haiwen/seahub` at the `v14.0.9-server` tag.  It is a Python 3 /
  Django 5.x application; determine whether the tag ships built static assets
  or needs a locked Node frontend build.
- Package `haiwen/seafdav` at the same tag.  It imports `seahub.settings` and
  `seaserv`; either add those as runtime dependencies or make the imports
  lazy and fail only when the Seafile provider is selected.
- Add service types for the database, cache, `seaf-server`, Seahub (gunicorn)
  and seafdav.  Keep secrets and database state outside the store.
- Document the supported topology (single node; MariaDB/MySQL; Redis or
  memcached as required by the upstream version).

**Non-goals**

- Seafile Professional/enterprise features.
- Multi-node/HA deployment.
- S3/Ceph object backends.
- Migrating an existing production Seafile installation.

**Deliverables**

- `seahub`, `seafdav` and any missing Python dependencies.
- Service records with configuration validation and activation snippets.
- A VM test that starts the stack, creates a library, uploads and downloads a
  file through WebDAV, and checks the Seahub login/landing page.
- README/STATUS deployment notes, including the database migration step.

**Validation**

- All packages build offline with locked origins.
- `seaf-cli` can sync against the VM instance.
- `curl`/WebDAV PUT/GET round-trip succeeds.
- VM test is green, or the test documents a precise external prerequisite.

**Risks / exit criteria**

The main risk is scope: Seahub brings a large Django closure, static frontend
assets, database migrations and cache configuration.  If the frontend build or
the Python bindings cannot be made reproducible within the task budget, stop
and document the result rather than shipping a half-working service.  Exit
only when the VM test is green; otherwise mark the task blocked with the exact
missing upstream artifact.

## T2: REA source build

**Goal:** replace the current REA npm release artifact with an offline,
hash-pinned source build, without changing REA's user-facing behavior.

**Scope**

- Lock the complete `npm ci` dev/build closure for the REA source tree.
- Build the TypeScript/Node distribution and source-build `node-pty`.
- Keep the existing Guix host-detection patch and MCP/static-JavaScript tests.
- Update or remove the corresponding precompiled exceptions.

**Non-goals**

- Frida integration (T3).
- Packaging REA's optional external analysis engines.

**Deliverables**

- A `rea` package built from the source tag, with a source lock file.
- A reproducible build that does not consult the npm registry.
- VM/host smoke for `rea --version`, `rea doctor` and MCP stdio.

**Validation**

- `make verify-standalone` and the REA VM test pass.
- The package contains no unrecorded precompiled payloads.
- The build succeeds with the network disabled.

**Risks / exit criteria**

The dev/build closure is large and may contain install scripts or native
downloads.  If the closure cannot be locked cleanly, keep the npm artifact as
the accepted distribution and document the gap; do not mix a partial source
build with the release artifact.

## T3: Frida integration

**Goal:** make REA's optional Frida-dependent commands usable.

**Scope**

- Decide between a source build and an explicitly recorded precompiled
  exception for Frida (core, CLI and Python bindings as needed).
- Wire Frida into the REA package or a separate `rea-frida` variant.
- Add a smoke that proves REA detects Frida and can start a trivial script.

**Non-goals**

- iOS/Android instrumentation.
- Kernel-level tracing.
- Bundling Frida server payloads for non-Linux targets.

**Validation**

- `frida --version` works in a VM.
- `rea doctor` reports the Frida capability.
- The precompiled-exception manifest is updated if applicable.

**Risks / exit criteria**

Frida is a large native/Rust project with platform payloads.  If the source
build is not reproducible in the available time, record the exact prebuilt
artifact and its hash, or leave the feature unavailable; do not ship an
unverified binary.

## T4: opencode VM CPU/CI fix (done)

**Goal:** make the existing opencode VM test execute instead of skipping on
hosts whose QEMU CPU model lacks SSE4.2.

**Status:** completed.  `qemu-sse42` is a trivial wrapper around
`qemu-minimal` that appends `-cpu max`; the opencode VM test now runs all five
assertions.

**Scope**

- Add a test-only QEMU wrapper or VM option that exposes `-cpu max` (or an
  equivalent CPU model with SSE4.2).
- Keep the existing host phase-7 checks.
- Do not change the opencode packages themselves.

**Validation (passed)**

- The opencode VM test runs all five assertions (launchers, versions, help)
  instead of `test-skip`; result: 5/5.
- `make verify-ci` remains green.
- The wrapper is documented as a test-environment workaround, not a runtime
  requirement.

**Risks / exit criteria**

Guix's `virtual-machine` record does not expose a CPU field directly; the
implementation may need a small QEMU package wrapper.  If the wrapper becomes
more complex than the test is worth, keep the skip and record the host
limitation.  This task is small and should not block other work.

## T5: pydantic-ai/httpx2 refresh (done)

**Goal:** move the marimo AI extras from the compatibility pin
`pydantic-ai-slim` 2.30 to the current upstream release.

**Status:** completed.  `python-httpcore2-2.16` and `python-httpx2-2.16` are
packaged; `pydantic-ai-slim` and `pydantic-graph` are at 2.61.0.  The marimo
extras import smoke constructs an `Agent`.

**Scope**

- Package `httpx2` 2.16 and its matching `httpcore2` 2.16 plus `truststore`.
- Rebuild `genai-prices`, `pydantic-graph` and `pydantic-ai-slim` against the
  newer HTTP stack.
- Keep the marimo extras import smoke and add a small Agent construction test.

**Non-goals**

- Model-provider extras (OpenAI/Anthropic/etc.).
- Network calls in tests.

**Validation**

- `marimo-with-extras` imports `pydantic_ai` and constructs an `Agent`.
- `make verify-standalone` passes.
- The package metadata has no unsatisfied runtime requirement.

**Risks / exit criteria**

If the newer `httpx2`/`httpcore2` pair pulls an unpackageable dependency, keep
2.30 and document the exact blocker.  Do not relax the requirement without a
runtime test.

## T6: Qt5 / Seafile GUI

**Recommendation: do not schedule.**

Qt 5.15 is EOL for open-source users, the pinned channel ships Qt 6, and
`seafile-client` 9.0.22 still requires Qt 5.  Packaging a second Qt stack plus
the client's GUI dependencies is a large maintenance burden for a desktop
feature that is not required by the service/CLI use case.

If the GUI is ever required, make it a separate task with an explicit decision
to either:

- package Qt 5.15 and its dependency closure, or
- port/upgrade the client to a Qt 6 release and validate it upstream.

Until then, use the Seafile CLI/daemon and the web UI (T1) instead.
