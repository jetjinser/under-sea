# Status

This repository builds a networking stack, the Hermes Agent, Codex, Pi and
several standalone tools from source against a pinned channel set, plus the
Shepherd services and system tests around them. This file records what is
delivered, how it is verified, the precompiled exceptions and the known
limitations. Build and usage instructions are in [README.md](README.md).

Pinned channels (`channels.scm`): **`guix@d434a41`** (including `llvm-23`),
**`nonguix@cf5e3b8f`**, plus **`guix-hpc@ea7b563`**, **`guix-science@ca82743`**,
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
| camofox | `(@ (under-sea packages camofox-browser) camofox-browser-for-hermes)` + `hermes-camofox-runtime` | `jo-inc/camofox-browser` REST service via `CAMOFOX_URL`. |

### Codex, Pi and standalone tools

| Component | Expression | Notes |
|---|---|---|
| Codex | `(@ (under-sea packages codex) codex-complete)` | 0.160.0; CLI subcommands, local V8 code-mode host, voice host, patched zsh, SDK. |
| Pi | `(@ (under-sea packages pi) pi)` | 1.0.4; npm source closure + source-built native/WASM (quickjs-wasi, photon, undici, esbuild, lightningcss, TUI N-API). |
| Pi standalone | `(@ (under-sea packages pi) pi-standalone)` | Single-file bun `build --compile` binary (about 94 MiB) with theme/assets/export-html/wasm/native. |
| bun | `(@ (under-sea packages bun) bun-for-hermes)` | Precompiled bootstrap exception; only the ELF interpreter is patched (no rpath, to avoid a segfault). |
| kilocode | `(@ (under-sea packages kilocode) kilocode)` | 7.8.8; single-file `kilo` CLI, all dependencies pinned per-origin and installed offline. |
| Ghidra | `(@ (under-sea packages ghidra) ghidra)` | 12.1.4; deployed from the official release distribution (precompiled exception). |
| Strata | `(@ (under-sea packages strata) strata)` | 0.1.44.1; AMD/HIP engine built from source against Guix's ROCm 7. |
| Strata CUDA | `(@ (under-sea packages strata) strata-cuda)` | Same engine, NVIDIA backend: CUDA 13.0.2 toolkit from guix-hpc-non-free (non-free, non-substitutable), sm_120 code, whole build on gcc-toolchain@14. |
| qwenimage-ncnn-vulkan | `(@ (under-sea packages qwenimage-ncnn-vulkan) qwenimage-ncnn-vulkan)` | 20261010; Qwen-Image text-to-image/editing on the ncnn 20260924 submodule pin (Vulkan, NCNN_SIMPLEVK, Guix glslang), linking Guix's jpeg/zlib/png/webp; wrapper supplies vulkan-loader. |
| codex-session-patcher | `(@ (under-sea packages codex-session-patcher) codex-session-patcher)` | Refusal-cleaning CLI for Codex/Claude Code/OpenCode session files. |
| Agent Cat | `(@ (under-sea packages agent-cat) agent-cat)` | Haskell framework (jwiegley) for modeling agentic workflows as a typed DSL with a verifying compiler and memoizing interpreter; MIT per cabal. Ships `ghc-ram` (memory fork) with it. **Parked**: upstream main is deeply coupled to the nixpkgs-unstable haskell
package set and cannot build against the guix haskell collection.  Three
blockers confirmed by exhaustive iteration (including ram→memory and
crypton→cryptonite substitutions): (1) `convertToBase` resolves to
`ram-0.22.1` modules via transitive deps conflicting with `memory`;
(2) crypton/cryptonite `Digest` lacks `ByteArrayAccess` instances for the
memory class hierarchy; (3) Client.hs needs crypton-x509 ≥1.10 exports.
Revisit when guix updates its haskell set or upstream fixes the ram/crypto
integration. |
| Hermes gateway service | `(@ (under-sea services hermes) hermes-service-type)` | shepherd service running `hermes gateway start` as the unprivileged `hermes` account (state in `/var/lib/hermes`).  VM system test `%test-under-sea-hermes`: 3/7 passing (service lifecycle, activation/ownership, log file); 4 failing — the mock-model service exits silently in the guest (empty log, no port), taking the process-identity/offline-turn assertions with it, and the diagnostics dump hits a guest-side `get-string-all` unbound.  Needs a live in-guest debugging session. |

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
  - `verify-locks.sh`: loads all `*-lock.scm` (currently 50 files / 27055
    origins) and requires every origin to be a fixed-output sha256.
  - `verify-exceptions.sh`: cross-checks `planning/precompiled-exceptions.json`
    — every source-unavailable package is listed, resolvable, and has a
    fixed-hash source.
  - `verify-elf.sh` (with `VERIFY_PACKAGING_ELF=1`): scans built outputs for
    shared objects with an executable stack (`PT_GNU_STACK RWE`);
    `scripts/clear-exec-stack.py` is the general fix.
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
- `modules/under-sea/tests/browser.scm`: Xvfb browser end-to-end.

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
| kilocode (native npm payloads) | with kilocode 7.8.8 | embedded-prebuilt | `@opentui`, `@parcel/watcher`, `@lydell/node-pty`, `@ff-labs/fff-bin`, `tree-sitter-bash/powershell` ship no source (hash-pinned origins). |
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
