# under-sea — a pinned Guix package collection

A personal collection of Guix packages, services and system tests: a
networking stack, the Hermes Agent, Codex, Pi, and several standalone tools.
Everything is built from source against a pinned channel set, with every
dependency as a fixed, hash-pinned origin fetched through guix-daemon, so
builds run offline. Components that ship no usable source are recorded as
explicit precompiled exceptions. Component definitions track the **latest
stable upstream release available at packaging time**: when an upstream
project publishes a new stable release, bump the pin (and its source hash and
any re-locked inputs), rebuild, and re-run the smoke gates before documenting
the new version.

The pinned channels (`channels.scm`) are **`guix@d434a41`** (including
`llvm-23`), **`nonguix@cf5e3b8f`**, and — for the CUDA toolkit used by
`strata-cuda` — **`guix-hpc@ea7b563`**, **`guix-science@ca82743`**,
**`guix-past@1ef1e51`**, **`guix-science-nonfree@b9cc745`** and
**`guix-hpc-non-free@ff0bba2`**. `guix time-machine` warns that the codeberg
and Inria channels are "not trusted"/"lack an introduction"; the warnings are
cosmetic, and the channels can be listed in
`~/.config/guix/trusted-channels.scm` (same format as `channels.scm`) to
silence them.

Delivery status, verification results, the exception manifest and known
limitations live in [STATUS.md](STATUS.md); the machine-readable exception list
is `planning/precompiled-exceptions.json`.

## Repository layout

| Path | Contents |
|---|---|
| `modules/under-sea/packages/` | Package definitions, one module per component. |
| `modules/under-sea/services/` | Shepherd service types (sing-box, dae, Moldflow SCM, Autodesk Licensing Service). |
| `modules/under-sea/system/` | Minimal `operating-system` declarations used by the system tests. |
| `modules/under-sea/tests/` | VM (marionette) system tests and the Xvfb browser end-to-end test. |
| `scripts/` | Source lockers, assemblers and the verification scripts. |
| `planning/` | Pinned build inputs and provenance records referenced by lockers/recipes (`precompiled-exceptions.json`, `*-Cargo.lock`, source inventories). See STATUS.md for which files are build inputs. |
| `Makefile`, `manifest.scm` | Convenience targets, and the development environment (`guix shell -m manifest.scm`). |

## Using this repository as a Guix channel

The repository is a self-contained Guix channel (`.guix-channel`, module root
`modules/`), and it is authenticated: commits from the introduction commit
onward are signed, and the signing key ships in the channel's `keyring`
branch, so `guix pull` verifies the whole history without any manual key
import. To consume it without a local checkout, add it to your channels
(`~/.config/guix/channels.scm`, or the `channels.scm` passed to
`guix time-machine -C`):

```scheme
(channel
 (name 'under-sea)
 (url "https://github.com/jetjinser/under-sea.git")
 (introduction
  (make-channel-introduction
   "32e8f043573bc1a7b0da7facd23b06f20d199490"
   (openpgp-fingerprint
    "CA5A 2189 12D3 CA70 E689  3FB9 0A9B 84C3 ADD0 A923"))))
```

After `guix pull`, the modules are available without `-L`:

```sh
guix build -e '(@ (under-sea packages helium) helium)'
guix time-machine -C channels.scm -- build \
  -e '(@ (under-sea packages helium) helium)'
```

Note the difference from the `-L "$PWD/modules"` form used throughout this
README: a channel tracks the *committed* state of the repository, so local
edits only become visible after `git commit`, while `-L` always builds the
working tree.

## Building

All Guix commands use the pinned channels. Heavy builds use
`--cores=1 --max-silent-time=7200 --keep-failed`.

```sh
# Any component, addressed by expression:
guix time-machine -C channels.scm -- build -L "$PWD/modules" \
  -e '(@ (under-sea packages hermes) hermes-agent-integrations)' \
  --cores=1 --max-silent-time=7200 --keep-failed
```

A `Makefile` wraps the common commands (`make help`; `guix shell make -- make
help` if `make` is not installed). `manifest.scm` is the development
environment (tooling only):

```sh
make env                                      # guix shell -m manifest.scm
make strata                                   # per-component shortcut
make build EXPR='(@ (under-sea packages hermes) hermes-agent-integrations)'
make copy  HOST=user@host:2222 EXPR='(@ (under-sea packages strata) strata)'
make verify-all
make clean                                    # drop stale /tmp/guix-build-* trees
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
guix time-machine -C channels.scm -- build -L "$PWD/modules" -e '(@ (under-sea packages sing-box) sing-box)'
guix time-machine -C channels.scm -- shell -L "$PWD/modules" -e '(@ (under-sea packages sing-box) sing-box)' -- sing-box version
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
guix time-machine -C channels.scm -- build -L "$PWD/modules" -e '(@ (under-sea packages dae) dae)'
guix time-machine -C channels.scm -- shell -L "$PWD/modules" -e '(@ (under-sea packages dae) dae)' -- dae --version
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
guix time-machine -C channels.scm -- build -L "$PWD/modules" \
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
guix time-machine -C channels.scm -- build -L "$PWD/modules" -e '(@ (under-sea packages hermes) hermes-agent)'
guix time-machine -C channels.scm -- shell -L "$PWD/modules" -e '(@ (under-sea packages hermes) hermes-agent)' -- hermes --cli
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
See the header of `modules/under-sea/packages/hermes-browser-backends.scm`.

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

`(@ (under-sea packages codex) codex-complete)` pins **0.163.0** and builds the
full tool with the channel's Rust: the CLI subcommands (exec/login/mcp/
app-server/remote-control/completion/apply), the local V8 `code-mode` host, the
voice host, a patched zsh and the SDK. Registry crates are verified against the
upstream `Cargo.lock`; Git dependencies keep their exact revisions and are
replaced with the matching local source, never a different crates.io version.
The build uses at most 4 Cargo jobs, disables cross-crate release LTO to lower
link memory, and sets `max-silent-time` to 7200s.

```sh
guix time-machine -C channels.scm -- build --cores=4 --max-silent-time=7200 \
  --keep-failed -L "$PWD/modules" -e '(@ (under-sea packages codex) codex-complete)'
guix time-machine -C channels.scm -- shell -L "$PWD/modules" \
  -e '(@ (under-sea packages codex) codex-complete)' -- codex --version
```

An explicit model catalog that switches upstream `tool_mode` to `direct` is
installed at `share/codex/guix-models-direct.json`; select it with
`model_catalog_json` in `~/.codex/config.toml` if code mode is unavailable.

Real-sandbox verification (on a host that allows unprivileged user namespaces):

```sh
guix time-machine -C channels.scm -- shell python-minimal -- \
  python3 scripts/check-codex.py --sandbox /gnu/store/…-codex-0.163.0
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
guix time-machine -C channels.scm -- build -L "$PWD/modules" \
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
`modules/under-sea/packages/kilocode-lock.scm` (1890 fixed-output origins, including
the URL dependency `xlsx`). At build time those origins are unpacked into bun's
offline cache, `bun install --frozen-lockfile --offline` assembles
`node_modules` fully offline, and `bun build --single` produces the single-file
binary. All fetching goes through guix-daemon's `url-fetch` (host network); the
build phase never touches the network (this host's build sandbox has no usable
DNS, so no fixed-output builder is used).

```sh
guix time-machine -C channels.scm -- build -L "$PWD/modules" -e '(@ (under-sea packages kilocode) kilocode)'
guix time-machine -C channels.scm -- shell -L "$PWD/modules" -e '(@ (under-sea packages kilocode) kilocode)' -- kilo --version
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

guix time-machine -C channels.scm -- build -L "$PWD/modules" -e '(@ (under-sea packages ghidra) ghidra)' \
  --cores=1 --max-silent-time=7200 --keep-failed
guix time-machine -C channels.scm -- shell -L "$PWD/modules" -e '(@ (under-sea packages ghidra) ghidra)' -- analyzeHeadless
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

`(@ (under-sea packages strata) strata)` builds **0.1.44.1** (MIT), a local
Qwen3.8-Flash-Next inference engine, from source for the **AMD HIP** backend
using Guix's ROCm 7 stack.

```sh
guix time-machine -C channels.scm -- build -L "$PWD/modules" -e '(@ (under-sea packages strata) strata)' \
  --cores=4 --max-silent-time=7200 --keep-failed
guix time-machine -C channels.scm -- shell -L "$PWD/modules" -e '(@ (under-sea packages strata) strata)' -- strata-device --help
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
package.

### NVIDIA (CUDA)

`(@ (under-sea packages strata) strata-cuda)` builds the same engine for the
**NVIDIA CUDA** backend against **CUDA 13.0.2** (`cuda-13`) from the non-free
**guix-hpc-non-free** channel (the toolkit itself lives in
guix-science-nonfree and is installed from NVIDIA's `.run` installer; it is
`#:substitutable? #f` and is recorded as a precompiled exception). The target
architecture is `120` (RTX 50 Blackwell consumer); upstream's sm_75 floor
admits RTX 20/30/40/50. CUDA 13 is required rather than the channel's older
12.4/12.9: upstream reports that sm_120 engines built with CUDA 12.8 crashed
on long prompts on Linux and recommends 13.0+ (issues #220/#224), and CUDA 12.4
cannot target sm_120 at all.

nvcc 13 supports host GCC up to 14, so the whole build runs on
`gcc-toolchain@14` (C and C++ compiler and `CMAKE_CUDA_HOST_COMPILER`),
`CUDAToolkit_ROOT` points at the toolkit, and the binaries get an rpath into
the toolkit's `lib`. `libcuda.so.1` (the kernel-mode driver library) is never
in the store: it must come from the host's NVIDIA driver at run time. The
closure is non-substitutable — build it locally or move it with `guix copy`.

```sh
make strata-cuda   # or: make build EXPR='(@ (under-sea packages strata) strata-cuda)'
guix time-machine -C channels.scm -- shell -L "$PWD/modules" \
  -e '(@ (under-sea packages strata) strata-cuda)' -- strata-device --help
```

## qwenimage-ncnn-vulkan

`(@ (under-sea packages qwenimage-ncnn-vulkan) qwenimage-ncnn-vulkan)` builds
Qwen-Image **20261010** text-to-image and instruction-driven image editing on
ncnn and Vulkan, together with the **20260924** `ncnn` revision the upstream
`src/ncnn` submodule pins (`(@ (under-sea packages qwenimage-ncnn-vulkan)
ncnn)`). ncnn is built for Vulkan compute with its in-house `NCNN_SIMPLEVK`
loader and Guix's `glslang` for the offline shader compile, with no third-party
copies of either. The tool links Guix's libjpeg-turbo, zlib, libpng and libwebp
rather than the bundled submodules: two patches make the `USE_SYSTEM_*`
branches of `deps_codec.cmake` use the discovered CMake targets and add a
`FindWebP.cmake` module, since upstream libwebp installs no CMake package
configuration.

ncnn's `NCNN_SIMPLEVK` loader `dlopen`s `libvulkan.so.1`, which a build input
cannot satisfy, so the installed binary is wrapped with an `LD_LIBRARY_PATH`
into `vulkan-loader`; the GPU driver's ICDs still come from the host.

```sh
guix time-machine -C channels.scm -- build -L "$PWD/modules" \
  -e '(@ (under-sea packages qwenimage-ncnn-vulkan) qwenimage-ncnn-vulkan)'
guix time-machine -C channels.scm -- shell -L "$PWD/modules" \
  -e '(@ (under-sea packages qwenimage-ncnn-vulkan) qwenimage-ncnn-vulkan)' \
  -- qwenimage-ncnn-vulkan
```

Model weights are runtime inputs: the tool looks for `models/qwenimage21` (the
`model` argument selects another path) and reports an incomplete graph when the
files are absent.

## IVy

`(@ (under-sea packages ivy) python-ms-ivy)` packages the IVy protocol
verification tool (Ken McMillan's interactive protocol prover).  IVy has no
upstream releases, so the package pins `master`; the version tracks
`setup.py`.  Verification conditions are discharged with the Z3 SMT solver:
Guix's `z3` package is built with `Z3_BUILD_PYTHON_BINDINGS=ON`, so the plain
`z3` package satisfies IVy's `z3-solver` requirement and is propagated.

`python-tarjan` (a small dependency missing from Guix proper) is packaged in
the same module.

The C++ backend (`ivyc`) is a known limitation: upstream builds it from the
picotls/aiger/abc/z3 submodules plus a system C++ toolchain, none of which
this package pins.  The Z3-backed workflows (`ivy`, `ivy_check`) work; run
them with an example from the repository's `examples/` directory.

Checking for upstream updates: the repository doubles as a Guix channel
(`.guix-channel` provided).  After adding it to your channels and running
`guix pull`, the `(guix import ms-ivy)` updater is discovered by `guix
refresh` (the nonguix `google-chrome` updater uses the same mechanism):

    guix pull
    guix refresh -t ms-ivy python-ms-ivy

## codex-session-patcher

`(@ (under-sea packages codex-session-patcher) codex-session-patcher)` cleans
refusal replies out of Codex/Claude Code/OpenCode session files. Pure Python
with no runtime dependencies for the core CLI, built with
`pyproject-build-system` from commit `cf7deab2d5b28c1f70f5b5498461848b69024a15`;
the optional `web`/FastAPI entry point is stripped. It installs
`bin/codex-patcher`.

## lazy.nvim plugin locks

`scripts/lazy-lock-import.scm` imports the plugin pins of a Neovim
configuration managed by lazy.nvim. Given a configuration repository whose root
holds `lazy-lock.json`, it resolves the repository in the store, reads the lock
with a JSON parser, and emits the configuration's own fixed-output origin plus
one `(SHORT REPO COMMIT HASH)` entry per locked plugin. HASH is the nar hash of
the checkout, so every entry is directly usable as a `git-fetch` origin. The
importer is generic over the configuration repository and the plugin forge
(`--plugin-base`); it was extracted from the navier configuration bundle and is
maintained here. Like the lockers below it needs network access to resolve the
configuration and check every plugin out; the build that consumes the emitted
origins does not.

`lazy-lock.json` records plugin *names* and revisions but no repository, so the
repository each name lives in comes from one of two sources:

- **`--ir=FILE`** — lazy.nvim's own resolved spec, which
  `scripts/lazy-ir-dump.lua` prints as JSON. It is authoritative (real URLs,
  and the plugins lazy disabled are honoured). Dump it from a session where the
  configuration has already called `require("lazy").setup()`, for example
  (run inside the under-sea checkout; `myrc` is assumed at `~/pkgs/myrc`):

  ```sh
  mkdir -p /tmp/myrc-nvim-config /tmp/myrc-nvim-data
  ln -sfn ~/pkgs/myrc /tmp/myrc-nvim-config/nvim
  XDG_CONFIG_HOME=/tmp/myrc-nvim-config XDG_DATA_HOME=/tmp/myrc-nvim-data \
    nvim --headless \
    --cmd 'lua require("lazy.core.loader").install_missing = function() end' \
    -c 'luafile scripts/lazy-ir-dump.lua' -c 'qa!' > /tmp/myrc-ir.json
  ```

  A configuration that bootstraps lazy.nvim (and spec macros such as
  tangerine/hibiscus) by cloning them at startup needs those on `runtimepath`
  first, and one whose plugins are missing will try to install them unless
  `install.missing` is false — in a headless run lazy's installer can be
  neutralised instead (the `--cmd` above). Point `nvim` at the configuration
  through a private `XDG_CONFIG_HOME` (with `<dir>/nvim` a symlink to it)
  rather than with `-u`: only in that layout does nvim put the configuration
  directory on `runtimepath`, which Fennel setups such as myrc's need before
  their `init.fnl` is ever sourced.

- **source scan (default)** — every `owner/repo` token the configuration's
  Fennel and Lua specs mention, intersected with the locked names. It needs no
  Neovim and no runnable configuration, but is a heuristic: unrelated
  `owner/repo`-looking text (LSP method names, and so on) is warned about and
  dropped.

```sh
guix time-machine -C channels.scm -- repl -- \
  scripts/lazy-lock-import.scm --ir=/tmp/myrc-ir.json \
  --output=/tmp/myrc-plugins.scm https://github.com/jetjinser/myrc
```

Options: `--commit=REV` pins the configuration itself (default: the tip of its
default branch), `--name=NAME` sets the base name of the emitted definitions
(default: the repository base name), `--ir=FILE` selects the resolved spec, and
`--plugin-base=URL` overrides the plugin forge (default `https://github.com`).
`guix repl --` is required so that options after `--` reach the importer rather
than `guix repl` itself. Three cases are reported on stderr and omitted:
plugins a spec references that `lazy-lock.json` does not pin, lock entries no
repository is known for (plugins lazy.nvim installed as another plugin's
dependency, whose repository the configuration never names — in `myrc`,
`hererocks` and `image.nvim`), and, with `--ir`, plugins lazy.nvim disabled.

Note that this is deliberately a standalone script and not a `guix import`
extension: `guix import` gates importers behind a hardcoded name list in
`guix/scripts/import.scm` and rejects unknown names before attempting to
resolve them from the load path (verified on Guix 1.5.0-6.64d4de2 and
65816f0), so a channel-provided `(guix scripts import lazy-lock)` would be
turned away as an "invalid importer".

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
  python3 scripts/lock-codex.py /tmp/codex-0.163.0.tar.gz /tmp/codex-rust-v0.163.0
```

`channels.scm` stays pinned. These definitions target this personal
collection; they are not proposed upstream.
