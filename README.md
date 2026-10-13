# under-sea — a pinned Guix package collection

A personal collection of Guix packages, services and system tests: a
networking stack, the Hermes Agent, Codex, Pi, and several standalone tools.
Everything is built from source against a pinned channel set, with every
dependency as a fixed, hash-pinned origin fetched through guix-daemon, so
builds run offline. Components that ship no usable source are recorded as
explicit precompiled exceptions.

The pinned channels (`channels.scm`) are **`guix@d434a41`** (including
`llvm-23`) and **`nonguix@cf5e3b8f`**.

Delivery status, verification results, the exception manifest and known
limitations live in [STATUS.md](STATUS.md); the machine-readable exception list
is `planning/precompiled-exceptions.json`.

## Repository layout

| Path | Contents |
|---|---|
| `under-sea/packages/` | Package definitions, one module per component. |
| `under-sea/services/` | Shepherd service types (sing-box, dae, Moldflow SCM, Autodesk Licensing Service). |
| `under-sea/system/` | Minimal `operating-system` declarations used by the system tests. |
| `under-sea/tests/` | VM (marionette) system tests and the Xvfb browser end-to-end test. |
| `scripts/` | Source lockers, assemblers and the verification scripts. |
| `planning/` | Pinned build inputs and provenance records referenced by lockers/recipes (`precompiled-exceptions.json`, `*-Cargo.lock`, source inventories). See STATUS.md for which files are build inputs. |

## Building

All Guix commands use the pinned channels. Heavy builds use
`--cores=1 --max-silent-time=7200 --keep-failed`.

```sh
# Any component, addressed by expression (this avoids scanning channels.scm
# as a package module):
guix time-machine -C channels.scm -- build -L . \
  -e '(@ (under-sea packages hermes) hermes-agent-integrations)' \
  --cores=1 --max-silent-time=7200 --keep-failed
```

## Verification

`scripts/verify-all.sh` runs every gate and prints a summary. Each layer can
also be run on its own:

```sh
scripts/verify-packaging.sh    # lint, lock integrity, exceptions, ELF hygiene
scripts/verify-phase7.sh       # per-package smoke (Xvfb browser/desktop, runtime imports)
scripts/verify-system.sh       # service/system layer (container smoke + VM marionette tests)
scripts/verify-credentials.sh  # environment-gated checks (RUN when ready, else SKIP)
```

## Maintenance

`--keep-failed` builds leave intermediate trees in `/tmp/guix-build-*`.
`scripts/clean-build-artifacts.sh` removes trees owned by the current user that
have seen no writes for `--min-age` minutes (default 120), after `chmod -R u+w`
on the read-only npm/Go subdirectories, and skips any in-progress build. A
root-owned `/tmp/guix-build-*.pivot` must be removed manually.

```sh
scripts/clean-build-artifacts.sh --dry-run   # preview
scripts/clean-build-artifacts.sh             # remove trees idle for >2h
```

## Networking

### sing-box

Builds sing-box **1.14.2** and its Go dependencies from source, with the
upstream default build tags plus `with_naive_outbound` (NaiveProxy, via the
precompiled `libcronet.so` in the cronet-go module) and `with_tailscale`. Each
module `.mod`/`.info` and selected source `.zip` is a hash-pinned origin; the
build compiles through a local `file://` module proxy with `GOTOOLCHAIN=local`
and `-mod=readonly`, so it cannot download dependencies or another compiler.
`sing-box check`, `sing-box version` and an invalid-protocol rejection run in
the build. Binary substitution is disabled for sing-box itself.

```sh
guix time-machine -C channels.scm -- build -L . -e '(@ (under-sea packages sing-box) sing-box)'
guix time-machine -C channels.scm -- shell -L . -e '(@ (under-sea packages sing-box) sing-box)' -- sing-box version
```

### dae

Builds dae **2.1.1** and its embedded eBPF programs from source (including
`dae trace`), pinning both `dae_bpf_headers` submodules to the release commit
`56937c66784879fe5e2ff89db5bc05aa061d594c`. It uses Guix's Go and
Clang/LLVM and regenerates the Go/C constants rather than embedding precompiled
objects. The check phase runs the upstream configuration/parser/eBPF-constant
tests and rejects an unknown routing function; live eBPF attachment needs a
suitable kernel and is not run in the build container.

```sh
guix time-machine -C channels.scm -- build -L . -e '(@ (under-sea packages dae) dae)'
guix time-machine -C channels.scm -- shell -L . -e '(@ (under-sea packages dae) dae)' -- dae --version
```

GeoIP/geosite data are separate runtime inputs when using geographic rules: set
`DAE_LOCATION_ASSET` to their directory, or use the source-built `dae-geodata`
package and reference it from the service (below).

### Services

`(under-sea services networking)` provides `dae-service-type` and
`sing-box-service-type`. Add them explicitly to an `operating-system`; the
configuration files are user-managed. Both run with root privileges for
TUN/eBPF and keep their state directory at `0700`.

```scheme
(use-modules (under-sea services networking))

(service dae-service-type
         (dae-configuration
          (config-file "/etc/dae/config.dae")
          (state-directory "/var/lib/dae")))
(service sing-box-service-type
         (sing-box-configuration
          (config-file "/etc/sing-box/config.json")
          (state-directory "/var/lib/sing-box")))
```

dae refuses a configuration readable by group/other, so `dae-service-type`
copies it into the state directory and `chmod 0600` before starting. A
`dae-configuration` may take an `asset-directory` (a string, or
`(file-append dae-geodata "/share/dae")` to pull the data into the system
closure). `dae-geodata` bundles the source-generated GeoIP/geosite data:

```sh
guix time-machine -C channels.scm -- build -L . \
  -e '(@ (under-sea packages dae-data) dae-geodata)' \
  --cores=1 --max-silent-time=7200 --keep-failed
```

The DB-IP attribution and license are kept in the package's documentation
directory; updating the data requires re-locking sources and rebuilding.

## Hermes Agent

### Core runtime

`(@ (under-sea packages hermes) hermes-agent)` builds release **v2026.9.24**
(Python project **0.21.5**) from source: the Python CLI, its locked core
dependencies, and Rust extensions built in the Guix sandbox from hash-pinned
registry crates (no downloaded binary wheels). It bundles the skills, plugins,
translations and a source-built Chinese FTS5 extension. `hermes update` refuses
in-place store changes and automatic pip installation is disabled; update the
recipe instead.

```sh
guix time-machine -C channels.scm -- build -L . -e '(@ (under-sea packages hermes) hermes-agent)'
guix time-machine -C channels.scm -- shell -L . -e '(@ (under-sea packages hermes) hermes-agent)' -- hermes --cli
```

The pinned Python links SQLite 3.39.3; Hermes detects its WAL issue and falls
back to DELETE journal mode. `hermes-agent-interfaces` adds the ACP/MCP and
dashboard Python dependencies; `hermes-agent-integrations` is the full
integration runtime (model SDKs/auth, search/image, cloud terminal, messaging,
voice, memory, monitoring, skills/plugins). Configuration, credentials and
state stay in the user's Hermes home.

### Audio

`(@ (under-sea packages hermes-audio) hermes-agent-audio)` combines the locked
protocol/cloud/audio Python sources with source-built CTranslate2, ONNX Runtime,
TFLite, Sherpa, FlatBuffers and Pilk, plus PortAudio and the bundled wake-word
models. It builds successfully and the `pvporcupine` import smoke passes; full
audio testing needs devices and wake-word credentials
(`scripts/verify-credentials.sh`). Porcupine ships a native engine with no
source, so it is not copied and is recorded as a source-unavailable component.

`(@ (under-sea packages hermes-audio-interfaces) hermes-agent-audio-interfaces)`
wires the source TUI and dashboard to the same private audio runtime and puts
the common Linux skill tools on the subprocess `PATH`. The optional
`hermes-linux-skill-tools` set references 16 pinned CLIs (image/audio/video,
Git, Node/npm, PDF/office conversion, network diagnostics, audio sessions, and
the Docker/uv clients); Docker and PulseAudio still need separate service,
permission or device setup.

### Browser / computer-use backends

Hermes selects a backend as follows: the local default uses `agent-browser`
with `AGENT_BROWSER_EXECUTABLE_PATH` (source `ungoogled-chromium`);
`CAMOFOX_URL` activates camofox mode; `BROWSER_CDP_URL` overrides everything;
cloud providers go through `plugins/browser/{browserbase,browser_use,firecrawl}`.
See the header of `under-sea/packages/hermes-browser-backends.scm`.

| Backend | Package |
|---|---|
| Local | `hermes-browser-runtime` |
| Playwright | `(@ (under-sea packages hermes-browser-backends) hermes-browser-backend-playwright)` |
| browser-use | `(@ (under-sea packages hermes-browser-use) hermes-browser-backend-browser-use)` |
| Camoufox | `(@ (under-sea packages hermes-camoufox) hermes-browser-backend-camoufox)` |
| camofox | `(@ (under-sea packages camofox-browser) camofox-browser-for-hermes)` + `hermes-camofox-runtime` |

Camoufox's precompiled Firefox gets its ELF interpreter patched to the store
loader, its wrapper injects the GTK3 closure and `alsa-lib` `LD_LIBRARY_PATH`,
and the fpgen model is pointed at a writable directory via
`CAMOUFOX_FPGEN_DATA`.

### Dashboard and desktop

`(@ (under-sea packages agent-browser) agent-browser)` is a Rust CLI with the
source-built Next static export (`_next/**`) embedded.
`(@ (under-sea packages hermes-electron) hermes-electron-desktop)` is an
Electron shell (the nongnu precompiled exception) over the source dashboard.

## Codex

`(@ (under-sea packages codex) codex-complete)` pins **0.160.0** and builds the
full tool with the channel's Rust: the CLI subcommands (exec/login/mcp/
app-server/remote-control/completion/apply), the local V8 `code-mode` host, the
voice host, a patched zsh and the SDK. Registry crates are verified against the
upstream `Cargo.lock`; Git dependencies keep their exact revisions and are
replaced with the matching local source, never a different crates.io version.
The build uses at most 4 Cargo jobs, disables cross-crate release LTO to lower
link memory, and sets `max-silent-time` to 7200s.

```sh
guix time-machine -C channels.scm -- build --cores=4 --max-silent-time=7200 \
  --keep-failed -L . -e '(@ (under-sea packages codex) codex-complete)'
guix time-machine -C channels.scm -- shell -L . \
  -e '(@ (under-sea packages codex) codex-complete)' -- codex --version
```

An explicit model catalog that switches upstream `tool_mode` to `direct` is
installed at `share/codex/guix-models-direct.json`; select it with
`model_catalog_json` in `~/.codex/config.toml` if code mode is unavailable.

Real-sandbox verification (on a host that allows unprivileged user namespaces):

```sh
guix time-machine -C channels.scm -- shell python-minimal -- \
  python3 scripts/check-codex.py --sandbox /gnu/store/…-codex-0.160.0
```

## Pi

`(@ (under-sea packages pi) pi)` builds Pi **1.0.4** from an npm source closure
plus source-built native/WASM components (quickjs-wasi, photon, undici,
esbuild, lightningcss, the TUI N-API addon).
`(@ (under-sea packages pi) pi-standalone)` is the single-file bun
`build --compile` binary (about 94 MiB) with its theme/assets/export-html/wasm/
native files.
`(@ (under-sea packages bun) bun-for-hermes)` is the precompiled bun bootstrap
exception (only the ELF interpreter is patched; rpath is left alone to avoid a
segfault).

## Autodesk Moldflow and the Autodesk Licensing Service

Both are proprietary precompiled exceptions (`#:substitutable? #f`), built from
a user-supplied archive. Moldflow **2027.0.2**
(`(@ (under-sea packages moldflow) moldflow-insight-thinclient)`) is the
relocatable thin-client plus the Simulation Compute Manager, generating
`mfclient.env` and `insight.config.json`; source that file before running
solvers (`AUTODESK_ADLM_THINCLIENT_ENV`, `SCM_BASE`, `SCM_DATAPATH`,
`MFSYN_HOME`). The optional `moldflow-scm-service-type` runs the SCM daemon.

```sh
export MOLDFLOW_ARCHIVE=/path/to/Autodesk_MFIU_2027_Multilingual_Linux_64bit.tar.bz2
guix time-machine -C channels.scm -- build -L . \
  -e '(@ (under-sea packages moldflow) moldflow-insight-thinclient)' \
  --cores=1 --max-silent-time=7200 --keep-failed
```

Licensing is provided by the **Autodesk Licensing Service**
(`(@ (under-sea packages adsk-licensing) adsk-licensing)`, 16.2.0.15195) from
the same archive, started with `adsk-licensing-service-type` and keeping state
in `/var/opt/Autodesk/AdskLicensingService`:

```scheme
(use-modules (under-sea services adsk-licensing))
(service adsk-licensing-service-type)
```

The service runs as the unprivileged `adsklic` account (as upstream does); only
creating the fixed system directory needs root. A marionette VM test
(`%test-under-sea-adsk-licensing`, wired into `scripts/verify-system.sh`) checks
that the service starts, the state directory is owned by `adsklic`, and the
process runs as `adsklic`. Solver and license checks are gated in
`scripts/verify-credentials.sh`.

## kilocode (TUI)

`(@ (under-sea packages kilocode) kilocode)` builds **7.8.8** (MIT). The TUI is
not a standalone program: `packages/tui` (`@opencode-ai/tui`, SolidJS, rendered
on the native `@opentui/core`) is consumed by `packages/opencode`
(`@kilocode/cli`), so packaging the TUI means packaging the single-file `kilo`
CLI that already embeds it.

Dependencies are pinned per-origin: `scripts/lock-kilocode.py` turns the
`bun.lock` (JSONC) plus downloaded registry tarballs into
`under-sea/packages/kilocode-lock.scm` (1890 fixed-output origins, including
the URL dependency `xlsx`). At build time those origins are unpacked into bun's
offline cache, `bun install --frozen-lockfile --offline` assembles
`node_modules` fully offline, and `bun build --single` produces the single-file
binary. All fetching goes through guix-daemon's `url-fetch` (host network); the
build phase never touches the network (this host's build sandbox has no usable
DNS, so no fixed-output builder is used).

```sh
guix time-machine -C channels.scm -- build -L . -e '(@ (under-sea packages kilocode) kilocode)'
guix time-machine -C channels.scm -- shell -L . -e '(@ (under-sea packages kilocode) kilocode)' -- kilo --version
```

Build notes: npm tarballs are extracted with Python `tarfile` (some carry
directories without the execute bit) and flattened; install scripts are skipped
(`--ignore-scripts`); `node_modules/.bin` shebangs are repointed at the store
`node`; the optional web "Kilo Console" build is skipped; the standalone bun
binary must not be `patchelf`-ed (it already embeds the store loader) and must
not be stripped (`#:strip-binaries? #f`), or it breaks. The wrapper sets
`KILO_BWRAP_PATH` (bubblewrap), `PATH` (ripgrep) and
`KILO_DISABLE_MODELS_FETCH=1`, and the binary resolves its runtime auxiliaries
(`tree-sitter/`, sandbox worker/seccomp, `console/`, `licenses/`) from its own
directory. The model snapshot is pinned in
`planning/kilocode-models-dev-api.json`.

## Ghidra

`(@ (under-sea packages ghidra) ghidra)` deploys **12.1.4** (Apache-2.0) from
the official release distribution (a precompiled exception). A fully offline
Gradle source build would require vendoring the whole Maven/plugin dependency
graph plus the external `ghidra.bin` repository, and this host's direct access
to GitHub and the Gradle plugin portal is throttled to a few KB/s, so the
release zip is used for now.

```sh
# Direct GitHub is slow; fetch through a mirror and seed the store, then the
# daemon can build offline:
curl -fL -o ghidra_12.1.4_PUBLIC.zip \
  https://gh-proxy.com/https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.4_build/ghidra_12.1.4_PUBLIC_20260921.zip
guix time-machine -C channels.scm -- download "file://localhost$PWD/ghidra_12.1.4_PUBLIC.zip"

guix time-machine -C channels.scm -- build -L . -e '(@ (under-sea packages ghidra) ghidra)' \
  --cores=1 --max-silent-time=7200 --keep-failed
guix time-machine -C channels.scm -- shell -L . -e '(@ (under-sea packages ghidra) ghidra)' -- analyzeHeadless
```

The launcher shebangs are repointed at store bash; generated `bin/` wrappers
(`ghidraRun`, `analyzeHeadless`, `bsim`, …) set `JAVA_HOME` (the `jdk` output of
openjdk@21, because LaunchSupport needs `javac`) and `PATH`. The native helpers
are adapted for Guix: `demangler_gnu`/`lzfse` are `patchelf`-ed to the store
loader with a libstdc++/libgcc_s rpath, while `decompile`/`sleigh` must **not**
be `patchelf`-ed (it corrupts their ELF segments, causing a SIGSEGV before any
library loads) — they keep a pristine `*.orig` and are exec'd through the store
loader via a wrapper. A build-time `check-native` phase runs each helper and
fails on a signal exit (≥128). `analyzeHeadless` imports and analyzes a binary,
and a Java GhidraScript decompiles all functions of a test binary (180/180).
The GUI (`ghidraRun`) needs an X/display environment.

## Strata

`(@ (under-sea packages strata) strata)` builds **0.1.43.1** (MIT), a local
Qwen3.8-Flash-Next inference engine, from source for the **AMD HIP** backend
using Guix's ROCm 7 stack. Upstream ships Windows-only binaries and the NVIDIA
path needs the CUDA toolkit (available only via the non-free
`guix-hpc-non-free`/`guix-science-nonfree` channels, not the pinned set), so the
AMD/HIP backend is built here.

```sh
guix time-machine -C channels.scm -- build -L . -e '(@ (under-sea packages strata) strata)' \
  --cores=4 --max-silent-time=7200 --keep-failed
guix time-machine -C channels.scm -- shell -L . -e '(@ (under-sea packages strata) strata)' -- strata-device --help
```

The engine compiles with `clang-rocm` (HIP), `rocm-device-libs`,
`rocm-hip-runtime`, `rocr-runtime` and hipBLAS/rocBLAS/hipBLASLt; ggml comes
from a pinned llama.cpp snapshot (`llama-cpp-for-strata`) via
`-DSTRATA_GGML_DIR`, so CMake never fetches it. clang-rocm 20 cannot parse GCC
16's libstdc++, so `gcc-toolchain@14` is used, and the HIP device-link step
needs `lld`→`ld.lld` and `llvm-objcopy` on `PATH`. The default target
architectures are `gfx1100;gfx1201` (upstream-validated RDNA3/RDNA4).

Running the engine needs an AMD discrete GPU (RDNA2/3/4); the tens-of-GB model
weights are downloaded at run time from Hugging Face and are not part of the
package. The NVIDIA/CUDA backend is not built — see STATUS.md for the follow-up
steps.

## codex-session-patcher

`(@ (under-sea packages codex-session-patcher) codex-session-patcher)` cleans
refusal replies out of Codex/Claude Code/OpenCode session files. Pure Python
with no runtime dependencies for the core CLI, built with
`pyproject-build-system` from commit `cf7deab2d5b28c1f70f5b5498461848b69024a15`;
the optional `web`/FastAPI entry point is stripped. It installs
`bin/codex-patcher`.

## Refreshing source locks

Each component's sources are pinned in a `*-lock.scm` produced by a locker under
`scripts/`. Locking requires network access; the subsequent Guix build does not.
Use a fresh `--cache` directory when the version or inputs change. The lockers
preserve the upstream checksum verification (Go modules via the checksum
database, registry crates against `Cargo.lock`) and write the lock atomically.
To avoid downloading the same hash-pinned files twice, seed the store from the
locker's downloaded inputs (Guix still verifies their hashes):

```sh
guix time-machine -C channels.scm -- repl -- \
  scripts/seed-source-cache.guile /tmp/under-sea-<component>-lock/inputs
```

The network-dependent lockers are, for example:

```sh
# sing-box
guix time-machine -C channels.scm -- shell go@1.25.12 python-minimal -- \
  python3 scripts/lock-sing-box.py 1.14.2 /tmp/sing-box-1.14.2.tar.gz /tmp/sing-box-1.14.2

# dae (source + eBPF headers submodule commit)
guix time-machine -C channels.scm -- shell go@1.26.8 python-minimal -- \
  python3 scripts/lock-dae.py 2.1.1 /tmp/dae-2.1.1.tar.gz /tmp/dae-2.1.1 \
  56937c66784879fe5e2ff89db5bc05aa061d594c /tmp/dae-bpf-headers-56937c6.tar.gz

# Hermes Agent
guix time-machine -C channels.scm -- shell python-minimal curl -- \
  python3 scripts/lock-hermes.py /tmp/hermes-agent-2026.9.24.tar.gz /tmp/hermes-agent-2026.9.24

# Codex
guix time-machine -C channels.scm -- shell python-minimal -- \
  python3 scripts/lock-codex.py /tmp/codex-0.160.0.tar.gz /tmp/codex-rust-v0.160.0
```

`channels.scm` stays pinned. These definitions target this personal
collection; they are not proposed upstream.
