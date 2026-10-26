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
      `unsupported_host: guix` until the host-detection extension lands; the
      packaged build patches the bundled detector to accept Guix.

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
      `haiwen/seafile-client`; reuse `seafile`/`libsearpc`.  Blocked on the
      pinned channel: it has Qt 6 only, while seafile-client 9.0.22 requires
      Qt 5.
- [x] Package the server core `seafile-server` 14.0.9 (libsearpc 3.3).
- [ ] `seahub`/`seafdav`: deferred.  They need the Python 2-era Seafile server
      bindings, MySQL and a Django/WSGI stack; the server core is packaged with
      Python bindings disabled.
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

- [ ] REA source build: deferred.  The published npm artifact is the accepted
      distribution choice; a source build would lock the full multi-thousand
      package dev/build closure.  See the Phase 6 decision above.
- [ ] Frida: deferred.  It is a large native/Rust project with platform
      payloads; the optional commands remain unavailable.
- [x] Patch the bundled host detection so `rea doctor` recognizes Guix as a
      supported host instead of reporting `unsupported_host`.
- [x] Add an integration test for the MCP stdio server (`rea --mcp`).
- [x] Add an integration test for a static JavaScript analysis path that
      needs no external engine.
- [ ] .NET analysis test: deferred; the static JavaScript path is covered and
      .NET analysis needs a separate runtime/engine fixture.
- [ ] Document external prerequisites (Ghidra/IDA/JADX/Hopper, `ps`, browsers)
      and add a readiness check.
- [ ] Evaluate a small MCP service wrapper only if REA grows a network
      transport; stdio is intentionally not a shepherd service.

Acceptance: source-built `dist`, `rea doctor` no longer reports an unsupported
host, and MCP tool listing succeeds in a VM.

## Phase 4: SeaweedFS extensions

- [x] Add a RocksDB CGO variant (`seaweedfs-rocksdb`, RocksDB 11.8.1) with a
      tag-specific module lock and cgo inputs.
- [x] Add the SQLite/TiKV/YDB/Tarantool build tags in `seaweedfs-full`, with
      a tag-specific module lock.
- [x] Serve the admin UI from `weed mini` using upstream's committed assets;
      the VM test checks the admin HTTP endpoint on port 12535.
- [ ] Add FUSE mount support and the required `fusermount` runtime wiring.
      Deferred: this host denies FUSE mounts (`Operation not permitted` even
      with `-allowOthers=false`); a VM test needs `/dev/fuse` and mount
      privileges that the current harness does not provide.
- [x] Extend the service to separate master/volume/filer/S3 roles for
      multi-node deployments, with a cluster VM test.
- [x] Add S3 API tests (bucket create, PUT/GET/DELETE object).
- [x] Add a `weed shell` smoke.
- [ ] Add a container image/OS declaration for a single-node `weed mini` or
      `weed server` deployment.

Acceptance: default and at least one CGO store variant build; multi-node
service starts in a VM; S3 round-trip passes.

## Phase 5: marimo extensions

- [x] Package `loro` Python bindings (Rust/PyO3) and re-enable real-time
      collaborative editing in marimo.
- [ ] Copilot LSP: deferred.  The sdist ships only prebuilt native binaries;
      rebuilding the upstream Node/Electron LSP needs a toolchain that is not
      part of this channel.  The binaries are deleted and Copilot is disabled.
- [x] Package the available SQL (DuckDB, Polars, SQLGlot) and MCP
      (`python-mcp`) extras in `marimo-with-extras`.
- [x] Package the sandbox (`uv`) and LSP (`python-lsp-server`,
      `python-lsp-ruff`) extras in `marimo-with-extras`.
- [x] Package `marimo-lens` and its `agent-plugins`/`anywidget`/`psygnal`
      chain; add it to `marimo-with-extras`.
- [ ] `pydantic-ai-slim`/recommended deps: deferred.  Its build backend uses
      `uv-dynamic-versioning` plus dynamic dependency templates, which are not
      yet packaged.  The marimo-lens AI context extension is already included
      and does not require pydantic-ai-slim.
- [x] Upgrade Guix's `python-msgspec` (0.20 -> 0.22+) and
      `python-pymdown-extensions` (10.16 -> 10.21+) so the package no longer
      patches upstream lower bounds.
- [x] Add token-password-file authentication and a VM test for the token
      path.
- [x] Document a reverse-proxy/TLS deployment for non-loopback use.
- [ ] Add notebook execution tests (export HTML, run as app) to phase 7.

Acceptance: optional extras import successfully, Loro RTC works, and the
unpatched `pyproject.toml` builds.

## Phase 6: maintenance and verification

- [x] Document the new packages' `upstream-github` properties and lockers in
      README/STATUS; `scripts/refresh.sh` is generic and no longer hardcodes a
      package list.
- [x] Run `verify-all` with the CI skips: packaging, phase 7 and system gates
      all PASS (`VERIFY_SYSTEM_SKIP_VM=1`, `VERIFY_PHASE7_SKIP_HERMES=1`,
      `VERIFY_PHASE7_SKIP_AGENT_BROWSER=1`, `VERIFY_SUBSTITUTE_URLS=...`).
      New-package VM tests were run individually; the optional credential
      check hangs on the `hermes-agent-audio` substitute and was stopped.
- [x] Add a CI-friendly subset: `VERIFY_SYSTEM_SKIP_VM=1 scripts/verify-all.sh`
      runs the packaging gates and phase 7 while skipping the slow VM/container
      system tests.
- [x] Accept the REA npm-release artifact as an explicit distribution choice:
      the source workspace's dev/build closure is thousands of Bun packages,
      while the release `dist` is the upstream tested artifact.  The native
      `node-pty` binding is source-built; other native payloads are recorded as
      precompiled exceptions.  A source build remains a future enhancement, not
      a correctness requirement.


## Phase 7: opencode v1 and v2

Upstream: <https://github.com/anomalyco/opencode> (MIT).  This is a Bun
monorepo with two materially different lines that must be packaged as separate
variants.  The v1 line is the architecture that `kilocode` forked; use the
existing `kilocode`/`pi`/`rea` Bun/Node packaging patterns as the starting
point.  The v2 line is a large workspace reorganisation (new `packages/cli`,
`core`, `server`, `protocol`, `app`, `desktop`, `console`, and services) and
needs its own lock and build recipe.

Pins observed on 2026-10-24 (re-check before locking):

- v1: tag `v1.19.4` (2026-10-22), commit
  `148842ef7cb1bc34192b3fff57d0f9721ab9c801`.
- v2: tag `v2.1.4` (npm `@opencode/cli@2.1.4`, 2026-10-23), commit
  `68bc26b7da1990ce10ffecfbc1e09eb13aa5d824`.  The `v2` branch is stale; use
  the tag, not the branch or `dev`.
- Both npm packages are tiny launchers; the platform payloads are 215/240 MB
  standalone Bun binaries, so build from the source tags instead.
- v1 builds `packages/opencode`; v2 builds `packages/cli`.  Both need Bun
  1.4.4 (the existing `bun-for-hermes` 1.4.2 is too old).

Tasks:

- [x] Add `bun-for-opencode` 1.4.4.
- [x] Pin exact v1 and v2 source tarball hashes.
- [x] Package `opencode-v1` from the v1 tree: Bun workspace install/build,
      offline cache, native `node-pty`/ripgrep handling, TUI/server/web assets.
- [x] Package `opencode-v2` from the v2 tree: separate lock, new workspace
      layout, CLI/server/TUI build, and the additional native dependencies.
      Patch the embedded `opencode-pty` interpreter/RUNPATH before the build
      hashes it; patch `.node` RUNPATHs for libstdc++/libgcc_s.
- [x] Install distinct `opencode-v1` and `opencode-v2` launchers so both can
      coexist in one profile; document which upstream line each represents.
- [ ] Add Makefile targets, README/STATUS entries and phase-7 smoke checks.
- [ ] Add VM/container smokes for `--version`, `--help`, config-directory
      creation and MCP/server mode where the line supports it.  The VM test is
      wired in, but this host's QEMU CPU model lacks SSE4.2 (required by the Bun
      standalone binary), so it skips; host phase-7 checks pass and the
      container OS declaration builds.
- [x] Build native payloads from source, or record each precompiled exception
      explicitly; do not silently ship npm platform binaries.
- [x] Add refresh/lock documentation and CI-friendly phase-7 checks for both
      variants.

Acceptance: `opencode-v1` and `opencode-v2` build offline under the pinned
channels, coexist in one profile, report their versions, and pass a minimal
CLI/MCP smoke in a VM.

## Ordering

1. Phase 1 (services/tests) — complete.
2. Phase 4 remaining coverage and Phase 5 remaining marimo work — continue.
3. Phase 3 REA source build/Frida/host detection — medium.
4. Phase 7 opencode v1 and v2 — large, but higher priority than the Seafile
   server/GUI work because both variants are explicitly requested.
5. Phase 2 Seafile server/client GUI — largest work.
6. Phase 6 documentation/CI once the first slices are stable.
