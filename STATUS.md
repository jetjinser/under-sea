# Status

This repository builds a networking stack, the Hermes Agent, Codex, Pi and
several standalone tools from source against a pinned channel set, plus the
Shepherd services and system tests around them. This file records what is
delivered, how it is verified, the precompiled exceptions and the known
limitations. Build and usage instructions are in [README.md](README.md).

Pinned channels (`channels.scm`): **`guix@d434a41`** (including `llvm-23`),
**`nonguix@47c20df`** (the build lock pin; `.guix-channel` deliberately leaves
nonguix unpinned), plus **`guix-hpc@ea7b563`**, **`guix-science@ca82743`**,
**`guix-past@1ef1e51`**, **`guix-science-nonfree@b9cc745`** and
**`guix-hpc-non-free@ff0bba2`** (the last group delivers the CUDA toolkit for
`strata-cuda`; guix-hpc and guix-hpc-non-free publish no signed introduction,
and `guix pull` warns that the codeberg channels are not in the user's trusted
list — both warnings are cosmetic).

## Delivered components

### Networking

| Component | Expression | Notes |
|---|---|---|
| sing-box | `(@ (under-sea packages sing-box) sing-box)` | 1.14.2; NaiveProxy (precompiled `libcronet.so` via cronet-go) and Tailscale enabled; `sing-box check` passes. |
| dae | `(@ (under-sea packages dae) dae)` | 2.1.1; source-built eBPF programs; GeoIP/geosite data source-generated (`dae-geodata`). |

### Hermes Agent

| Component | Expression | Notes |
|---|---|---|
| Core | `(@ (under-sea packages hermes) hermes-agent)` | Release v2026.9.24 (Python 0.21.5); source-built private Python runtime. |
| Interfaces | `(@ (under-sea packages hermes) hermes-agent-interfaces)` | ACP/MCP and dashboard Python dependencies. |
| Integrations | `(@ (under-sea packages hermes) hermes-agent-integrations)` | 213 packages: model SDKs/auth, search/image, cloud terminal, messaging gateways, cloud voice, memory, monitoring, skills/plugins, SQLite WAL. |
| Audio | `(@ (under-sea packages hermes-audio) hermes-agent-audio)` | CTranslate2 / ONNX Runtime / Sherpa / TFLite / FlatBuffers / Pilk / PortAudio + wake-word models; Porcupine is a source-unavailable exception. |
| Dashboard | `(@ (under-sea packages agent-browser) agent-browser)` | Rust CLI with the source-built Next static export embedded. |
| Desktop | `(@ (under-sea packages hermes-electron) hermes-electron-desktop)` | Electron shell (nongnu precompiled exception) over the source dashboard. |

### Browser / computer-use backends

| Backend | Expression | How it is wired |
|---|---|---|
| Local | `hermes-browser-runtime` | Wraps Hermes, exports `AGENT_BROWSER_EXECUTABLE_PATH` → source `ungoogled-chromium`, `agent-browser` on `PATH`. |
| Playwright | `(@ (under-sea packages hermes-browser-backends) hermes-browser-backend-playwright)` | playwright-core + ungoogled-chromium. |
| browser-use | `(@ (under-sea packages hermes-browser-use) hermes-browser-backend-browser-use)` | Source closure; CDP-driven. |
| Camoufox | `(@ (under-sea packages hermes-camoufox) hermes-browser-backend-camoufox)` | Source controller + precompiled Firefox exception (GTK3/ALSA wrapper, fpgen model). |
| camofox | `(@ (under-sea packages camofox-browser) camofox-browser-for-hermes)` + `hermes-camofox-runtime` | L3 generated-node lock for 169 runtime source archives; 1.18.1 pin and lock reproduce from upstream source. Post-install `node --check` and `/health` smoke pass. Native dependencies use the reviewed source-built/prebuilt providers. |

### Codex, Pi and standalone tools

> The former `codex` base package is now `codex-base`; `codex` resolves to the
> full V8/audio/zsh package.  Existing base users should switch to `codex-base`.

| Component | Expression | Notes |
|---|---|---|
| Codex | `(@ (under-sea packages codex) codex)` | 0.163.0; CLI subcommands, local V8 code-mode host, voice host, patched zsh, SDK. |
| Codex base | `(@ (under-sea packages codex) codex-base)` | L3 dependent on Codex's offline Cargo source lock; Rust 1.95/native inputs are channel-pinned; release build, CLI/version/help smoke and execpolicy tests pass. |
| Pi | `(@ (under-sea packages pi) pi)` | 1.0.4; npm source closure + source-built native/WASM (quickjs-wasi, photon, undici, esbuild, lightningcss, TUI N-API). |
| Pi standalone | `(@ (under-sea packages pi) pi-standalone)` | L3 dependent on Pi's generated Node lock; pinned Bun 1.4.2 is declared as a manual prebuilt toolchain. Standalone `--version` smoke and Guix `--check` pass. |
| bun | `(@ (under-sea packages bun) bun-for-hermes)` | Precompiled bootstrap exception; only the ELF interpreter is patched (no rpath, to avoid a segfault). |
| kilocode | `(@ (under-sea packages kilocode) kilocode)` | 7.8.20; single-file `kilo` CLI, all dependencies pinned per-origin and installed offline. |
| Ghidra | `(@ (under-sea packages ghidra) ghidra)` | 12.1.4; deployed from the official release distribution (precompiled exception). |
| Strata | `(@ (under-sea packages strata) strata)` | 0.1.44.1; AMD/HIP engine built from source against Guix's ROCm 7. |
| Strata CUDA | `(@ (under-sea packages strata) strata-cuda)` | Same engine, NVIDIA backend: CUDA 13.0.2 toolkit from guix-hpc-non-free (non-free, non-substitutable), sm_120 code, whole build on gcc-toolchain@14. |
| qwenimage-ncnn-vulkan | `(@ (under-sea packages qwenimage-ncnn-vulkan) qwenimage-ncnn-vulkan)` | 20261010; Qwen-Image text-to-image/editing on the ncnn 20260924 submodule pin (Vulkan, NCNN_SIMPLEVK, Guix glslang), linking Guix's jpeg/zlib/png/webp; wrapper supplies vulkan-loader. L3: `qwenimage-ncnn-pin.scm` makes the submodule explicit, `scripts/update/qwenimage.py` blocks a changed submodule, and the package smoke runs `qwenimage-ncnn-vulkan -h`. |
| IVy | `(@ (under-sea packages ivy) python-ms-ivy)` | 1.8.26 pinned to master 8858a024 (no upstream releases).  Z3-backed verification via Guix's z3 (built with Python bindings).  Also adds `python-tarjan` (missing from Guix proper).  Limitation: the `ivyc` C++ backend needs the picotls/aiger/abc/z3 submodules and a system C++ toolchain, which are not pinned. |
| codex-session-patcher | `(@ (under-sea packages codex-session-patcher) codex-session-patcher)` | Refusal-cleaning CLI for Codex/Claude Code/OpenCode session files; core has no runtime dependencies, updates at L3, and `codex-patcher --help` runs as the package smoke. |
| Seafile | `(@ (under-sea packages seafile) seafile)` | 9.0.22; sync client daemon + `seaf-cli`; includes `libsearpc` 3.2.0 and its `pysearpc` modules. `seafile-client-service-type` runs the daemon under Shepherd. |
| seafile-server | `(@ (under-sea packages seafile-server) seafile-server)` | 14.0.9; server core (`seaf-server`, controller, gc, fsck); libsearpc 3.3; FUSE/HTTP server disabled; Python `seafile`/`seaserv` bindings installed; Seahub/seafdav not included. |
| REA | `(@ (under-sea packages rea) rea)` | 6.7.0; source-built from the `rea-agents-6.7.0` tag with a 750-origin package-lock build closure; turbo is bypassed in favor of the TypeScript/artifact scripts; only the runtime closure is installed. `rea-release` keeps the npm artifact as a fallback. Source-built `node-pty`; `ps` from procps. Optional Frida omitted; `rea doctor` recognizes Guix. VM test 5/5. |
| SeaweedFS | `(@ (under-sea packages seaweedfs) seaweedfs)` | 4.49; default pure-Go `weed`, `seaweedfs-rocksdb` (RocksDB 11.8.1, cgo) and `seaweedfs-full` (RocksDB/SQLite/TiKV/YDB/Tarantool); Go modules locked as fixed-output origins. `seaweedfs-service-type` runs `weed server`; `seaweedfs-cluster-service-type` runs separate master/volume/filer/S3 services; `seaweedfs-mini-service-type` adds the admin UI on port 12535; `seaweedfs-fuse-service-type` mounts the filer with `weed mount` (root by default; configurable). |
| opencode-v1 | `(@ (under-sea packages opencode-v1) opencode-v1)` | 1.19.4; legacy OpenCode line (Kilo Code fork base), installed as `opencode-v1`; source-built Bun workspace with locked npm closure; native npm payloads recorded as exceptions. VM test uses `qemu-sse42` (`-cpu max`) so Bun's SSE4.2 requirement is met. |
| opencode-v2 | `(@ (under-sea packages opencode-v2) opencode-v2)` | 2.1.4; current OpenCode line, installed as `opencode-v2`/`opencode2`; source-built Bun workspace, locked closure, patched `opencode-pty` and `.node` payloads. |
| loro | `(@ (under-sea packages loro) loro)` | 1.17.1; Python CRDT bindings built from the PyPI sdist with an offline crates.io closure; propagated by marimo for RTC. |
| marimo | `(@ (under-sea packages marimo) marimo)` | 0.25.2; core notebook server/CLI/editor/tutorials. `marimo-with-extras` adds DuckDB/Polars/SQLGlot, MCP, Python LSP/Ruff, the uv sandbox, the `marimo-lens` AI context extension and the pydantic-ai stack (`logfire-api`, `genai-prices`, `griffelib`, `pydantic-graph`, `pydantic-ai-slim` 2.61 with httpx2 2.16). Loro RTC is provided by `loro`. `marimo-service-type` runs `marimo run`; token auth and HTML export have VM tests. |
| Agent Cat | `(@ (under-sea packages agent-cat) agent-cat)` | Haskell framework (jwiegley) for modeling agentic workflows as a typed DSL with a verifying compiler and memoizing interpreter; MIT per cabal. Ships `ghc-ram` (memory fork) with it. `make update-detect` tracks the upstream commit at L1; the package is not updated until the Haskell build gate is fixed. **Parked**: upstream main is deeply coupled to the nixpkgs-unstable haskell package set and cannot build against the guix haskell collection. Three blockers confirmed by exhaustive iteration (including ram→memory and crypton→cryptonite substitutions): (1) `convertToBase` resolves to `ram-0.22.1` modules via transitive deps conflicting with `memory`; (2) crypton/cryptonite `Digest` lacks `ByteArrayAccess` instances for the memory class hierarchy; (3) Client.hs needs crypton-x509 ≥1.10 exports. Revisit when guix updates its haskell set or upstream fixes the ram/crypto integration. |
| Hermes gateway service | `(@ (under-sea services hermes) hermes-service-type)` | shepherd service running `hermes gateway start` as the unprivileged `hermes` account (state in `/var/lib/hermes`).  VM system test `%test-under-sea-hermes`: 3/7 passing (service lifecycle, activation/ownership, log file); 4 failing — the mock-model service exits silently in the guest (empty log, no port), taking the process-identity/offline-turn assertions with it, and the diagnostics dump hits a guest-side `get-string-all` unbound.  Needs a live in-guest debugging session. |

### Helium browser

| Component | Expression | Notes |
|---|---|---|
| helium | `(@ (under-sea packages helium) helium)` | 0.19.4.1 (Chromium 155.0.8059.84), built fully from source: imputnet's prepared tarball layers plus the ungoogled + helium patch pipeline. Guix's rustc lacks the crubit FFI the tree expects, so the four Rust-interop headers (font_format, ift_patcher, signed_web_bundles, athm_ffi) are replaced by C++ shims or dropped. `bin/helium --version` verified. `scripts/build-helium.sh` pre-seeds the big tarballs into the store for offline rebuilds. `make update-detect-helium` reports the helium/helium-linux commits, Chromium version, Debian branch and bundled assets; updates remain manual-review (L1). |
| vimium-c | `(@ (under-sea packages vimium-c) vimium-c)` | L3; 2.12.3. Package build uses channel-pinned Guix `node`/`node-typescript`, compiles TypeScript and checks all manifest file references. Guix `--check` passes; no npm dependencies are consumed. |

### Overleaf

| Component | Expression | Notes |
|---|---|---|
| overleaf-toolkit | `(@ (under-sea packages overleaf) overleaf-toolkit)` | 5-toolkit.1ae1306; generated git-fetch pin for the official docker-compose toolkit, including the `lib/config-seed` templates used by `overleaf-ctl init`. |
| overleaf-ctl | `(@ (under-sea packages overleaf) overleaf-ctl)` | Wrapper around the official docker-compose toolkit (5.x); state and config live under `OVERLEAF_ROOT` (default `/var/lib/overleaf/toolkit`), nothing touches host services or data. |
| Overleaf service | `(@ (under-sea services overleaf) overleaf-service-type)` | Optional shepherd service; `overleaf-configuration` fields render `overleaf.rc` / `variables.env` declaratively; `runtime 'podman` generates docker shims backed by podman(-compose). |

### Autodesk Moldflow and licensing

| Component | Expression | Notes |
|---|---|---|
| Moldflow thin-client | `(@ (under-sea packages moldflow) moldflow-insight-thinclient)` | 2027.0.2; proprietary precompiled, non-substitutable; needs the user's archive. |
| Moldflow SCM service | `(@ (under-sea services moldflow) moldflow-scm-service-type)` | Optional SCM daemon service. |
| Autodesk Licensing Service | `(@ (under-sea packages adsk-licensing) adsk-licensing)` | 16.2.0.15195; proprietary precompiled, non-substitutable; from the same archive. |
| Licensing service | `(@ (under-sea services adsk-licensing) adsk-licensing-service-type)` | Runs as the unprivileged `adsklic` account. |

Moldflow source archive `Autodesk_MFIU_2027_Multilingual_Linux_64bit.tar.bz2`
(sha256 `f48e759290cbf4d11e37cfc928c0acf021426b4aaa3313c080aa600d1158ea29`,
601 MB) supplies both packages. The thin-client is relocatable; `mfclient.env`
exports `AUTODESK_ADLM_THINCLIENT_ENV`, `SCM_BASE`, `SCM_DATAPATH`,
`MFSYN_HOME`, `MFSYN_TMP`. Its external library closure resolves entirely from
the store plus bundled libraries (measured with the store loader: 0 missing).
Without a license the solvers print `environmentNotReady`; `license_diagnostics`
reaches the ADLM SDK but needs a subscription/license service. Autodesk
officially supports only RHEL 8.6+/9.0+, so Guix System is not a listed
platform.

## Verification

`scripts/verify-all.sh` runs all four layers and prints a summary; each can be
run individually.

- `scripts/verify-packaging.sh` — offline packaging quality:
  - `verify-lint.sh`: runs the offline `guix lint` checkers on every
    `(under-sea packages …)` module (noise checkers excluded).
  - `verify-hygiene.sh`: whole-channel source hygiene — unused module
    imports and unreferenced private definitions.
  - `verify-locks.sh`: loads all `*-lock.scm` (currently 58 files / 36235
    origins) and requires every origin to be a fixed-output sha256.
  - `verify-exceptions.sh`: cross-checks `planning/precompiled-exceptions.json`
    — every source-unavailable package is listed, resolvable, and has a
    fixed-hash source.
  - `verify-elf.sh` (with `VERIFY_PACKAGING_ELF=1`): scans built outputs for
    shared objects with an executable stack (`PT_GNU_STACK RWE`);
    `scripts/clear-exec-stack.py` is the general fix.
- `scripts/verify-standalone.sh` — focused matrix for the standalone packages
  (13 checks, including SeaweedFS variants, marimo extras and pydantic-ai).
- `scripts/verify-phase7.sh` — per-package smoke: CLI/version checks, Xvfb
  browser/desktop checks, and the runtime import gate
  (`verify-runtime-imports.sh`).
- `scripts/verify-system.sh` — service/system layer (container smoke + VM
  marionette tests); missing prerequisites are SKIP, not failure.
- `scripts/verify-credentials.sh` — environment-gated checks (credentials,
  network, devices); SKIP when not ready.

### Service and system tests

The tests layer the stack as package → service → system:

- `modules/under-sea/system/networking.scm` defines `%under-sea-sing-box-os` and
  `%under-sea-networking-os`, instantiating `sing-box-service-type` (loopback
  mixed inbound + direct outbound) and `dae-service-type` (a minimal `.dae` with
  `DAE_LOCATION_ASSET` assembled via `file-union`); `guix system build` passes.
- `modules/under-sea/tests/networking.scm` (marionette):
  - `%test-under-sea-sing-box`: service starts, listens on `127.0.0.1:2080`,
    state directory correct, a bad configuration is rejected (4/4).
  - `%test-under-sea-dae`: service starts, loads eBPF, builds the control plane,
    creates the data-plane interface (3/3).
- `modules/under-sea/tests/adsk-licensing.scm`: `%test-under-sea-adsk-licensing` checks
  the licensing service starts, the state directory is owned by `adsklic`, and
  `AdskLicensingService` runs as `adsklic` (3/3).
- `modules/under-sea/tests/seaweedfs.scm`: single-process, cluster, mini/admin
  and FUSE-mount tests; the FUSE test starts `seaweedfs-fuse` and writes through
  the mounted filer (4/4).
- `modules/under-sea/tests/marimo.scm`: service, token-auth and HTML-export
  tests; the export test runs `marimo export html` and checks the marker (6/6).
- `modules/under-sea/tests/browser.scm`: Xvfb browser end-to-end.

### Upstream refresh coverage

`make refresh` (or `scripts/refresh.sh`) runs the channel-provided
`guix refresh` updaters over every package declaring an `upstream-github`
property, plus the ms-ivy master-tip tracker.  Verified live
against the GitHub API on 2026-10-21: the run caught eight stale pins
(sing-box 1.14.3, ncnn 20261020, hermes 0.22.3, helium 0.20.1, bun 1.4.3,
pi 1.3.0, kilocode 7.8.20, strata 0.2.2) and confirmed the rest current.
Bumping a lock-closure component still requires a full re-lock; the
updater only reports drift.  `planning/update-manifest.json` and
`scripts/update/` now provide the programmatic detect/prepare/verify stages.
The public orchestration (manifest, audit, report, detect, update, L2 pin
prepare) is Guile Scheme; Python remains only behind the npm/Bun/Go/Cargo
locker adapter boundary.  `make update` prepares and verifies in an isolated
git worktree before copying pin/lock files, and `--determinism` runs the
adapter twice to compare outputs.  `make update PACKAGE=...` is the single entry point;
`make update-detect`, `make update-audit`, `make update-report`,
`make update-verify` and `make update-vm` are the focused commands.  GitHub
workflows split network preparation from offline verification and protected
signing; `update-publish` needs the repository-external GPG environment.

Run them with the expression, e.g.:
`guix time-machine -C channels.scm -- build -L "$PWD/modules" -e '(@ (under-sea tests networking) %test-under-sea-sing-box)'`
(the daemon mounts `/dev/kvm` into the build sandbox; QEMU comes from the
derivation).

## Precompiled / source-unavailable exceptions

The manifest is `planning/precompiled-exceptions.json`, checked by
`scripts/verify-exceptions.sh`. Kinds: `prebuilt` (upstream binary), `wheel`
(PyPI wheel only), `closed` (no source), `bootstrap` (self-hosting),
`channel-prebuilt` (supplied prebuilt by a channel), `embedded-prebuilt`
(binary embedded in a hash-pinned source).

| Package | Version | Kind | Reason |
|---|---|---|---|
| sing-box (libcronet.so) | with sing-box 1.14.2 | embedded-prebuilt | NaiveProxy requires the upstream precompiled `libcronet.so` (runpath patched). |
| porcupine-for-hermes | pvporcupine 4.0.3 | closed | Closed wake-word engine, no source. |
| playwright-for-hermes | 1.62.0 | wheel | PyPI ships only wheels (bundled Node driver; ELF interpreter patched). |
| ua-parser-builtins-for-hermes | 202610 | wheel | PyPI ships only wheels. |
| bun-for-hermes | 1.4.2 | bootstrap | Self-hosting build needs a prebuilt bootstrap; only the interpreter is patched. |
| camoufox-browser-for-hermes | 156.0.1-beta.36 | prebuilt | Prebuilt Firefox fork (interpreter patched; GTK3/ALSA wrapper). |
| hermes-electron-desktop | 27.3.11 | channel-prebuilt | Electron is distributed prebuilt by nonguix (non-free license). |
| strata-cuda (CUDA toolkit) | with strata-cuda 0.1.44.1 | channel-prebuilt | CUDA 13.0 toolkit installed from NVIDIA's non-free `.run` installer by guix-hpc-non-free/guix-science-nonfree; non-substitutable. |
| impit-linux-x64-gnu-for-hermes | with camofox | prebuilt | camofox dependency; only a prebuilt `.node` is published. |
| moldflow-insight-thinclient | 2027.0.2 | prebuilt | Proprietary installer (Autodesk EULA); user-supplied archive, non-substitutable. |
| adsk-licensing | 16.2.0.15195 | prebuilt | Proprietary RPM (Autodesk EULA); user-supplied archive, non-substitutable. |
| kilocode (native npm payloads) | with kilocode 7.8.20 | embedded-prebuilt | `@opentui`, `@parcel/watcher`, `@lydell/node-pty`, `@ff-labs/fff-bin`, `tree-sitter-bash/powershell` ship no source (hash-pinned origins). |
| ghidra | 12.1.4 | prebuilt | Official release distribution (Apache-2.0); an offline Gradle source build needs the whole Maven/plugin graph plus `ghidra.bin`. |

All other components are source-built; sources and hashes are pinned in the
corresponding `*-lock.scm`.

## Maintainer notes

- **Upstream version policy**: every component pins the latest stable upstream
  release available at packaging time. When a project ships a new stable
  release, refresh the version, its source hash and any re-locked inputs
  (llama.cpp pins, Cargo/npm locks), rebuild, and re-run the smoke gates
  before documenting the new version. A component left behind on an older
  release is a bug in this collection, not a pinning choice.
- **Build-script embedding**: `hermes.scm` embeds its build scripts inline as
  `plain-file`; the new `(under-sea gexp)` helper (`under-sea-script`) reads
  `scripts/<name>` at macro-expansion time and is robust to relative `-L`
  (the hermes-agent-audio closure is migrated and verified).  The remaining
  ~40 modules still reference `scripts/` via relative `local-file`, which
  requires an **absolute** `-L` (the Makefile's `$(CURDIR)/modules`); a
  relative `-L modules` breaks them with `canonicalize-path` errors.  See
  `planning/hermes-service-tests.md` for the repo-wide follow-up.
- `make-hermes-package` (`modules/under-sea/packages/hermes.scm`) appends conditional
  inputs from the source inventory via `%hermes-native-input-rules` /
  `%hermes-runtime-input-rules` (`python-uv-build`, `python-meson`, `zstd`,
  `libxml2`/`libxslt`, …) and disables `validate-runpath?` when a component
  ships its own loader. `#:smoke?` / `#:smoke-script?` run `hermes --help` at
  build time (the full runtime also runs `scripts/check-hermes.py`).
- `scripts/build-hermes.py` drives Cargo only for maturin/setuptools-rust
  backends (skipping setuptools packages that carry a stray `Cargo.lock`).
  `scripts/lock-hermes-browser.py --cargo-lock-overrides` injects missing crate
  locks (e.g. `planning/tiktoken-Cargo.lock`).
- `scripts/clear-exec-stack.py` clears the executable `PT_GNU_STACK` flag
  (e.g. onnxruntime).
- `planning/` holds pinned build inputs and provenance records. Files referenced
  by a scheme `local-file` or in use by a locker are build inputs and must not
  be deleted (`precompiled-exceptions.json`, `*-Cargo.lock`/`*.toml`,
  `hermes-*-source*.json`, `*-node-inventory/archives.json`, …); the remaining
  one-off inventories are provenance. Lockers/prepare scripts also take these
  files as CLI arguments (`--inventory`, `--source-overrides`,
  `--cargo-lock-overrides`, `--providers`, `--peer-bindings`, `--archives`), so
  a file may be referenced only there.

## Known limitations

- **IVy C++ backend**: the `ivyc` protocol compiler and the compiled-C++
  verification workflow require the `picotls`, `aiger`, `abc` and `z3`
  submodules (built by upstream's `build_submodules.py`) plus a C++ toolchain
  on `PATH`.  Only the Z3-backed toolchain (`ivy`, `ivy_check`, the
  interactive prover) is packaged.
- **External prerequisites** (credentials/network/devices): real sing-box
  egress, Codex login/execution, the Porcupine wake word
  (`PORCUPINE_ACCESS_KEY`), end-to-end Hermes LLM use, and cloud browser
  providers (API keys). Gated in `scripts/verify-credentials.sh`.
- **Upstream conflict**: in one process, importing `onnxruntime` and
  `sherpa_onnx` together aborts with a duplicate ONNX protobuf descriptor
  (`File already exists in database: onnx/onnx-ml.proto`) — the `onnxruntime`
  pybind extension and `libonnxruntime` each statically include the ONNX
  protos, and `sherpa_onnx` triggers a second registration through
  `libonnxruntime`. Use them in separate processes (e.g. wake-word engine and
  VAD), or wait for an upstream fix.
- **Container smoke**: the unprivileged `guix system container` smoke needs root
  or an `/etc/subuid` range matching Guix's (0..65536); on this host it is SKIP
  with a reason, and the PASS path works on a host that meets the requirement.
- **Not packaged (optional)**: lightpanda — `--engine lightpanda` is supported,
  but upstream ships only a prebuilt binary and it could not be downloaded from
  GitHub Releases here. Camoufox UBO is excluded by default (pass
  `exclude_addons` to change).

## Follow-ups

- **Strata NVIDIA/CUDA backend: delivered and device-verified** as `strata-cuda`
  (see the table above). The channels are pinned and authenticated;
  `cuda-toolkit@13.0.2` builds from NVIDIA's `.run` installer; the engine builds
  for sm_120 with CUDA 13.0.2 and `gcc-toolchain@14`. On the RTX 5060 host
  (i7-12700KF, AVX2 only): the wrapped `strata-device` enumerates the GPU
  (compute capability 12.0, driver 13020 / runtime 13000), and two full engine
  runs were verified on the card — the ISTA-DASLab Coder pack (native pack via
  `tools/iq_pack.py`, MTP draft layer from the original checkpoint) at ~33
  tok/s, and Qwen3.6-35B-A3B UD-Q4_K_XL in the hybrid mode (~58 tok/s, MTP
  acceptance 92%) after bumping the pin to 0.1.44.1, the first engine with the
  qwen35moe path. Note: a pack missing `native_experts.txt` is treated as a
  canonical pack whose CPU kernels are AVX-512-only — the packing tool writes
  that file last, so a half-finished `iq_pack.py` run looks like a hard
  AVX-512 requirement. The Qwen3.6 hybrid mode has no such requirement.
- **Ghidra source build.** Vendor the Gradle plugin/Maven graph plus the
  external `ghidra.bin` and switch to a source package built offline
  (`fetchDependencies → prepdev → buildGhidra`), replacing the current prebuilt
  exception.
