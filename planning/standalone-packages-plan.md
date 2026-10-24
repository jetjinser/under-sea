# Standalone package completion plan

Status: Phase 1 is complete.  The base packages are built and committed in `4f6d34c`
(`seafile`, `rea`, `seaweedfs`, `marimo`).  This plan tracks the remaining
runtime integration, optional features and verification work.  Each phase is
independent; a phase is complete only when its acceptance command passes under
the pinned channels (`guix time-machine -C channels.scm`).

## Phase 1: services and real-system tests

Deliver shepherd services plus VM/container coverage.  This is the first
implementation slice because it turns the packages from build-only artifacts
into testable system components.

### SeaweedFS

- [x] `(under-sea services seaweedfs)` with a `seaweedfs-service-type` that
      runs `weed server` as an unprivileged `seaweedfs` account.
- [x] Declarative fields: package, data directory, bind/advertise IP, master /
      volume / filer / S3 ports, `filer?`, `s3?`, extra arguments, log file.
- [x] Activation creates and chowns the data directory; the service requires
      `networking` and `user-processes`.
- [x] VM test starts the service and checks the S3/filer ports and a minimal
      S3 request.
- [x] Container smoke uses the same OS declaration and checks the S3 port.

Acceptance:

```sh
guix time-machine -C channels.scm -- build -L modules \
  -e '(@ (under-sea tests seaweedfs) %test-under-sea-seaweedfs)'
```

### marimo

- [x] `(under-sea services marimo)` with a `marimo-service-type` that runs
      `marimo run NOTEBOOK --headless` as an unprivileged `marimo` account.
- [x] Fields: package, notebook file-like, host, port, token mode, working
      directory, user/group, extra arguments, log file.
- [x] Default to loopback and no token; allow a token-password file for
      non-loopback deployments without embedding secrets in the store.
- [x] VM test starts the service, checks the HTTP endpoint and notebook output.
- [x] Container smoke checks the HTTP port.

Acceptance:

```sh
guix time-machine -C channels.scm -- build -L modules \
  -e '(@ (under-sea tests marimo) %test-under-sea-marimo)'
```

### Seafile client

- [x] `(under-sea services seafile)` with a `seafile-client-service-type` that
      runs `seaf-daemon` in the foreground as an unprivileged `seafile`
      account.
- [x] Activation creates `conf/` and `data/`, runs `seaf-cli init` once when
      `conf/seafile.ini` is absent, and chowns the state tree.
- [x] VM test starts the service, checks `seafile.sock`, the daemon process
      user, and `seaf-cli status`.
- [x] Container OS declaration builds with `--network`; the VM test checks the
      socket and process lifecycle.

Acceptance:

```sh
guix time-machine -C channels.scm -- build -L modules \
  -e '(@ (under-sea tests seafile) %test-under-sea-seafile)'
```

### REA

REA is a CLI/MCP stdio program, not a long-running daemon.  It gets a
real-system smoke rather than a shepherd service.

- [x] Add `rea` to a minimal system profile and assert `rea --version` and
      `rea --help` in a VM/container.
- [x] Record the `rea doctor` output as informational; it reports
      `unsupported_host: guix` until the host-detection extension lands.

### Integration

- [x] Wire all new tests into `scripts/verify-system.sh`.
- [x] Add a combined container smoke where practical; keep the existing
      SKIP-on-unprivileged-userns behavior.  On this host all three container
      smokes build but report SKIP at `initialize-user-namespace`.
- [x] Document the services and test commands in README/STATUS.
- [x] Run `scripts/verify-packaging.sh`, `scripts/verify-phase7.sh` and the new
      system tests.

## Phase 2: Seafile extensions

- [ ] Package the desktop GUI `seafile-client` (Qt) from
      `haiwen/seafile-client`; reuse `seafile`/`libsearpc`.
- [ ] Package the server core `seafile-server` from
      `haiwen/seafile-server`, plus `seahub` (Python/Django) and `seafdav`
      (WebDAV).  These are separate upstream repositories and need their own
      service types and database/cache configuration.
- [ ] Build `libwebsockets` with SOCKS5 enabled (or add a package variant) so
      the client daemon's SOCKS proxy fields are available; currently Guix's
      libwebsockets lacks that feature.
- [ ] Add a server service type with data/configuration directories, database
      and cache backends, and a VM test that creates a library and syncs it
      through the client service.
- [ ] Add `seaf-cli`/`seaf-daemon` completion or documentation where upstream
      provides it.

Acceptance: `seafile-server` + `seahub` + `seafdav` build from source, the
server service starts in a VM, and a client can create/upload/download a
library.

## Phase 3: REA extensions

- [ ] Replace the published npm artifact with an offline TypeScript build from
      the GitHub source (`npm ci` + `turbo` + the `dist` build), locking the
      full dev/build dependency closure.  Keep the npm artifact only if the
      source build proves impractical.
- [ ] Package optional `frida` (source build or a recorded precompiled
      exception) and enable the Frida-dependent commands.
- [ ] Patch or upstream the Guix host detection so `rea doctor` recognizes a
      Guix-managed installation instead of reporting `unsupported_host`.
- [x] Add an integration test for the MCP stdio server (`rea --mcp`).
- [ ] Add an integration test for one static JavaScript/.NET analysis path
      that needs no external engine.
- [ ] Document external prerequisites (Ghidra/IDA/JADX/Hopper, `ps`, browsers)
      and add a readiness check.
- [ ] Evaluate a small MCP service wrapper only if REA grows a network
      transport; stdio is intentionally not a shepherd service.

Acceptance: source-built `dist`, `rea doctor` no longer reports an unsupported
host, and MCP tool listing succeeds in a VM.

## Phase 4: SeaweedFS extensions

- [ ] Add build variants for optional CGO-backed stores (RocksDB and the
      SQL/TiKV/YDB/Tarantool tags) with the required native inputs and lock
      coverage.
- [ ] Build the admin UI from source if upstream's committed assets are not
      sufficient; otherwise document the committed-asset path.
- [ ] Add FUSE mount support and the required `fusermount` runtime wiring.
- [ ] Extend the service to separate master/volume/filer/S3 roles for
      multi-node deployments, with a cluster VM test.
- [x] Add S3 API tests (bucket create, PUT/GET/DELETE object).
- [x] Add a `weed shell` smoke.
- [ ] Add a container image/OS declaration for a single-node `weed mini` or
      `weed server` deployment.

Acceptance: default and at least one CGO store variant build; multi-node
service starts in a VM; S3 round-trip passes.

## Phase 5: marimo extensions

- [ ] Package `loro` Python bindings (Rust/PyO3) and re-enable real-time
      collaborative editing.
- [ ] Package the Copilot LSP assets from source instead of deleting the
      sdist's prebuilt binaries; or keep the deletion and document the
      limitation permanently.
- [ ] Package the optional extras: SQL (`duckdb`, `polars`, `sqlglot`),
      sandbox (`uv`), LSP (`python-lsp-server`, `python-lsp-ruff`), MCP
      (`mcp`, `httpx2`), AI (`pydantic-ai-slim`, `marimo-lens`) and the
      recommended notebook dependencies.
- [ ] Upgrade Guix's `python-msgspec` (0.20 -> 0.22+) and
      `python-pymdown-extensions` (10.16 -> 10.21+) so the package no longer
      patches upstream lower bounds.
- [ ] Add a service auth story for non-loopback deployments (token password
      file, reverse proxy, TLS) and a VM test for the token path.
- [ ] Add notebook execution tests (export HTML, run as app) to phase 7.

Acceptance: optional extras import successfully, Loro RTC works, and the
unpatched `pyproject.toml` builds.

## Phase 6: maintenance and verification

- [ ] Add the four packages to the upstream refresh/lock documentation and
      verify `make refresh` reports their pins.
- [ ] Run the full `scripts/verify-all.sh` (including VM tests) and record the
      result in STATUS.
- [ ] Add a CI-friendly subset that skips long VM/container tests but still
      builds every package and runs phase 7.
- [ ] Review the REA npm-artifact decision after the source-build attempt; if
      it remains, record it explicitly as an accepted distribution choice (not
      a source-unavailable exception).

## Ordering

1. Phase 1 (services/tests) — immediate.
2. Phase 5 dependency upgrades and Phase 4 default-store coverage — highest
   user-visible value.
3. Phase 2 server/client GUI and Phase 3 source build — largest work.
4. Phase 6 documentation/CI once the first slices are stable.
