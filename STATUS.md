# under-sea 成果与状态（STATUS）

本仓库用固定 channel（`channels.scm`）从源码构建一套网络代理、Hermes Agent、
Codex 与 Pi，以及它们的浏览器/桌面/音频组件。本文汇总**已交付成果、当前状态、
已知限制、预编译例外与验证方式**。

固定 channel：`guix@d434a41`（含 `llvm-23`）+ `nonguix@cf5e3b8f`。

## 构建与验证

```sh
# 构建任意组件（示例）
guix time-machine -C channels.scm -- build -L . \
  -e '(@ (under-sea packages hermes) hermes-agent-integrations)' \
  --cores=1 --max-silent-time=7200 --keep-failed

# 单命令跑全部门禁并汇总（推荐）
scripts/verify-all.sh

# 各层单独运行：
scripts/verify-packaging.sh   # 打包质量（lint / 锁完整性 / 预编译例外 / ELF 卫生）
scripts/verify-phase7.sh      # 包级冒烟（含 Xvfb 下的浏览器/桌面冒烟 + 运行时 import 门禁）
scripts/verify-system.sh      # 服务/系统级（container 冒烟 + VM marionette 系统测试）
scripts/verify-credentials.sh # 凭据/网络依赖项（就绪则 RUN，否则 SKIP，不判失败）
```

> 所有 Guix 操作显式使用 `guix time-machine -C channels.scm -- …`；重型构建设置
> `--cores=1 --max-silent-time=7200 --keep-failed`。

## 服务与系统验证

在包级冒烟之外，另加 **服务 → 系统** 两层验证（`包 → 服务 → 系统`）：

- **最小系统声明**：`under-sea/system/networking.scm` 定义 `%under-sea-sing-box-os`
  与 `%under-sea-networking-os`，实例化 `sing-box-service-type`（loopback 混合入站 +
  direct 出站）与 `dae-service-type`（最小 `.dae` + `file-union` 组装 `DAE_LOCATION_ASSET`）；
  `guix system build` 通过。
- **VM 系统测试（marionette）**：`under-sea/tests/networking.scm`
  - `%test-under-sea-sing-box`：服务启动、监听 `127.0.0.1:2080`、状态目录、坏配置被拒（4/4）。
  - `%test-under-sea-dae`：服务启动、加载 eBPF 并构建控制面、创建数据面接口（3/3）。
  - 运行：`guix time-machine -C channels.scm -- build -L . -e '(@ (under-sea tests networking) %test-…)'`
    （daemon 把 `/dev/kvm` 挂进构建沙箱，QEMU 由派生自带）。
- **统一运行器**：`scripts/verify-system.sh`（容器冒烟 + 上述 VM 测试；缺条件 SKIP 不判失败）。

> dae 要求配置文件不可被组/其他用户读取（0640/0600），故 `dae-service-type` 在 activation
> 时把配置复制到状态目录并 `chmod 0600` 再运行 dae。

## 交付组件

### 网络
| 组件 | 包表达式 | 说明 |
|---|---|---|
| sing-box | `(@ (under-sea packages sing-box) sing-box)` | 1.14.2；S1 NaiveProxy（cronet-go **purego** 绑定预编译 `libcronet.so`）、S2 Tailscale；`sing-box check` 通过 |
| dae | `(@ (under-sea packages dae) dae)` | 2.1.1；GeoIP/geosite 数据由源码生成 |

### Hermes Agent
| 组件 | 包表达式 | 说明 |
|---|---|---|
| 核心 | `(@ (under-sea packages hermes) hermes-agent)` | 私有 Python 运行时（源码闭包） |
| 界面 | `(@ (under-sea packages hermes) hermes-agent-interfaces)` | TUI/ACP 等 |
| 集成 | `(@ (under-sea packages hermes) hermes-agent-integrations)` | 213 包：模型 SDK/认证、搜索/图像、云终端、消息网关、云语音、记忆、监控、技能/插件、SQLite WAL 等 |
| 音频 | `(@ (under-sea packages hermes-audio) hermes-agent-audio)` | faster-whisper/CTranslate2/ONNX Runtime/sherpa/TFLite/Pilk/PortAudio + wakeword 模型；Porcupine 例外 |
| dashboard | `(@ (under-sea packages agent-browser) agent-browser)` | Rust CLI，内嵌 Next 静态导出（`_next/**`） |
| 桌面 | `(@ (under-sea packages hermes-electron) hermes-electron-desktop)` | Electron（nongnu 预编译例外）+ 源码 dashboard |

### 浏览器 / computer-use 后端
| 后端 | 包表达式 | 接入方式 |
|---|---|---|
| 本地 | `hermes-browser-runtime` | 包装 Hermes，导出 `AGENT_BROWSER_EXECUTABLE_PATH` → 源码 `ungoogled-chromium`，`agent-browser` 入 PATH |
| playwright | `(@ (under-sea packages hermes-browser-backends) hermes-browser-backend-playwright)` | playwright-core + ungoogled-chromium |
| browser-use | `(@ (under-sea packages hermes-browser-use) hermes-browser-backend-browser-use)` | 源码闭包；CDP 驱动 |
| Camoufox | `(@ (under-sea packages hermes-camoufox) hermes-browser-backend-camoufox)` | 控制端源码 + 预编译 Firefox 例外（GTK3/ALSA 包装、fpgen 模型） |
| camofox | `(@ (under-sea packages camofox-browser) camofox-browser-for-hermes)` + `hermes-camofox-runtime` | `jo-inc/camofox-browser` REST 服务；`CAMOFOX_URL` |

> Hermes 的浏览器选择机制（审计结论）：本地默认走 `agent-browser` +
> `AGENT_BROWSER_EXECUTABLE_PATH`；`CAMOFOX_URL` 激活 camofox 模式；`BROWSER_CDP_URL`
> 覆盖一切；云 provider 走 `plugins/browser/{browserbase,browser_use,firecrawl}`。
> 见 `under-sea/packages/hermes-browser-backends.scm` 头部说明。

### Codex 与 Pi
| 组件 | 包表达式 | 说明 |
|---|---|---|
| Codex | `(@ (under-sea packages codex) codex-complete)` | 0.160.0；CLI 子命令（exec/login/mcp/app-server/remote-control/completion/apply）+ V8 code-mode host + voice + 补丁 zsh + SDK |
| Pi | `(@ (under-sea packages pi) pi)` | 1.0.4；npm 源码闭包 + 原生/WASM 源码构建（quickjs-wasi/photon/undici/esbuild/lightningcss/TUI N-API） |
| Pi standalone | `(@ (under-sea packages pi) pi-standalone)` | bun `build --compile` 单文件（约 94 MiB），随附 theme/assets/export-html/wasm/native |
| bun | `(@ (under-sea packages bun) bun-for-hermes)` | 预编译例外（仅改 ELF 解释器，禁 rpath 以避免段错误） |

## 打包质量校验

`scripts/verify-packaging.sh` 汇总四项离线检查（也可单独运行）：

- `scripts/verify-lint.sh`：对全部 `(under-sea packages …)` 跑 `guix lint` 的离线 checker（排除格式化/输入标签等噪声项；覆盖 minimal 变体、description/synopsis、license、源 URL、patch 名等）。
- `scripts/verify-locks.sh`：加载 50 个 `*-lock.scm`，要求每个 origin 都是固定输出 sha256。
- `scripts/verify-exceptions.sh`：核对 `planning/precompiled-exceptions.json`——所有描述标注为 source-unavailable 的包都必须在清单中，且清单条目可解析并有固定哈希源。
- `scripts/verify-elf.sh`（`VERIFY_PACKAGING_ELF=1` 启用）：扫描运行时输出，确认没有 `PT_GNU_STACK RWE` 可执行栈的共享库（`scripts/clear-exec-stack.py` 为通用修复）。

`make-hermes-package` 支持 `#:smoke?` / `#:smoke-script?`：构建期跑 `hermes --help`（完整运行时另跑 `check-hermes.py`）。

### 维护者说明（共享构建与运行时）

- `make-hermes-package`（`under-sea/packages/hermes.scm`）：用声明式
  `%hermes-native-input-rules` / `%hermes-runtime-input-rules` 按源码清单追加条件输入
  （`python-uv-build`、`python-meson`、`zstd`、`libxml2`/`libxslt` 等）；存在独立组件时关闭
  `validate-runpath?`。`#:smoke?` / `#:smoke-script?` 在构建期跑 `hermes --help`（完整运行时
  另跑 `scripts/check-hermes.py`）。
- `scripts/build-hermes.py`：仅当构建后端为 maturin/setuptools-rust 时才驱动 Cargo
  （排除携带多余 `Cargo.lock` 的 setuptools 包）。`scripts/lock-hermes-browser.py`
  的 `--cargo-lock-overrides` 注入缺失的 crate 锁（如 `planning/tiktoken-Cargo.lock`）。
- `scripts/clear-exec-stack.py`：清除 `PT_GNU_STACK` PF_X 可执行栈的通用修复（如 onnxruntime）。
- Camoufox 运行时维护点：预编译 ELF 补解释器指向 store 的 glibc loader；包装器注入 GTK3
  传递闭包与 `alsa-lib` 的 `LD_LIBRARY_PATH`；`fpgen` 模型经 `CAMOUFOX_FPGEN_DATA` 指向可写
  目录（规避只读 store）。
- 来源锁刷新：各 locker 联网生成 `*-lock.scm`；`scripts/seed-source-cache.guile` 用
  `guix download file://` 把已验证输入预热进 store，避免构建期重复下载（见 README 各 locker 小节）。
- `planning/` 说明：存放打包用的固定输入与审计记录。**被 scheme 的 `local-file` 或在用
  locker 直接引用的文件是构建/刷新输入，不可删除**（如 `precompiled-exceptions.json`、
  各 `*-Cargo.lock`/`*-Cargo.toml`、`hermes-*-source*.json`、`*-node-inventory/archives.json`
  等）；其余一次性 inventory/audit 记录为历史溯源，保留但不参与构建。各 locker/prepare
  脚本以 CLI 参数（`--inventory`/`--source-overrides`/`--cargo-lock-overrides`/`--providers`/
  `--peer-bindings`/`--archives`）手动接收这些文件，故其引用未必出现在源码中。

## 预编译 / 源码不可得例外

| 包 | 版本 | 理由 |
|---|---|---|
| cronet（sing-box NaiveProxy） | 随 sing-box 1.14.2 | 上游仅发行预编译 `libcronet.so`（patchelf runpath） |
| Porcupine（唤醒词） | pvporcupine 4.0.3 | 闭源引擎，无源码 |
| playwright / ua-parser-builtins | 1.62.0 / 202610 | PyPI 仅发行 wheel（playwright 捆绑 Node driver，已打 ELF 解释器补丁） |
| bun | 1.4.2 | 自举构建需预编译 bootstrap；仅 patchelf 改解释器 |
| Camoufox 浏览器 | 156.0.1-beta.36 | 仅发行预编译 Firefox 分叉（已打解释器补丁 + GTK3/ALSA 包装） |
| electron | 27.3.11（nongnu） | nonguix channel 以预编译发行（license Nonfree） |
| impit-linux-x64-gnu | 随 camofox | camofox 依赖，仅发行预编译 `.node` |
| kilocode 原生 npm 负载 | 随 kilocode 7.8.8 | `@opentui`/`@parcel`/`@lydell`/`@ff-labs`/`tree-sitter` 预构建二进制（哈希固定 origin） |
| ghidra | 12.1.4 | 官方 release 发行包（Apache-2.0）；Gradle 离线源码构建需整套 Maven/插件依赖 + `ghidra.bin`，本机 GitHub/plugin-portal 限速，暂用发行包 |

其余组件均为源码构建；来源与哈希固定在对应 `*-lock.scm`。清单以
`planning/precompiled-exceptions.json` 为准，由 `scripts/verify-exceptions.sh` 核对。

## Autodesk Moldflow Insight 2027（thin-client，专有例外，已打包）

`(@ (under-sea packages moldflow) moldflow-insight-thinclient)`（2027.0.2，预编译例外，
已登记 `planning/precompiled-exceptions.json`）；可选 SCM 守护进程服务
`(@ (under-sea services moldflow) moldflow-scm-service-type)`。

许可基础：`(@ (under-sea packages adsk-licensing) adsk-licensing)`（16.2.0.15195，预编译
例外）提供 **Autodesk Licensing Service**（`AdskLicensingService`，静态 Go，自定位到
executable；`AdskLicensingAgent`/`InstHelper`/`IdentityManager` 为动态，仅需 store
解释器 + libstdc++/libgcc_s）；服务 `(@ (under-sea services adsk-licensing)
adsk-licensing-service-type)` 运行 `AdskLicensingService --run`，状态目录
`/var/opt/Autodesk/AdskLicensingService`。服务以**非特权 `adsklic` 账号**运行（与上游
systemd 单元一致），仅创建固定系统目录需 root（由 activation/服务启动时完成）。VM 系统
测试 `(@ (under-sea tests adsk-licensing) %test-under-sea-adsk-licensing)`（marionette；
**3/3 PASS**：服务启动、状态目录属 adsklic、`AdskLicensingService` 进程以 adsklic 运行）
已接入 `scripts/verify-system.sh`（需本地归档）。启用许可服务并配置许可方式后，Moldflow
才能真正求解。许可门控见 `scripts/verify-credentials.sh`；用法见 `README.md`。源与上述
thin-client 同为一个归档（sha256 `f48e…`）。

- **来源**：`Autodesk_MFIU_2027_Multilingual_Linux_64bit.tar.bz2`
  （sha256 `f48e759290cbf4d11e37cfc928c0acf021426b4aaa3313c080aa600d1158ea29`，601 MB，
  5 个 Makeself 2.4.0 自解压脚本）。EULA 禁止再分发 → 仅本地包、`#:substitutable? #f`、不发布。
- **thin-client 可重定位**：解 `autodesk-moldflow-insight-2027-50.2.102.tar.gz` +
  `simulation-compute-2.9.1.tgz` 到任意目录，`ComputeTool --config merge` 注册 SCM，
  生成 `mfclient.env`（`AUTODESK_ADLM_THINCLIENT_ENV`/`SCM_BASE`/`SCM_DATAPATH`/`MFSYN_HOME`/`MFSYN_TMP`）。
- **Guix 适配（spike 实测）**：① 嵌入脚本 `#!/bin/bash`，Guix 无 `/bin/bash` → 以 bash 显式运行/patch
  shebang；② ELF 解释器 `/lib64/ld-linux-x86-64.so.2` → `patchelf --set-interpreter` 到 store loader；
  ③ 安装器用 `ldd` 检测 glibc，Guix 无 `ldd` → 需 `--force`（其必需库清单为空）。
- **外部库闭包**（store loader `--list` 实测 0 missing）：`attr`、`gfortran:lib`
  （libgfortran/libstdc++/libgcc_s）、`libtirpc`、`mit-krb5`、`openssl-1.1`、`util-linux:lib`；
  其余（Poco/TBB/`libiomp5`/VTK/zlib/ACIS/`libAdskLicensingSDK` 等）自带于产品 `lib/`，RPATH `$ORIGIN/../lib`。
- **运行门**：`flow`/`synmesh` 打印 `environmentNotReady`；`license_diagnostics checkout …`
  可达 ADLM SDK 但需订阅/许可服务 → 归 `scripts/verify-credentials.sh` 门控。
- **未受支持平台**：Autodesk 官方仅列 RHEL 8.6+/9.0+，Guix System 不在列；SCM 非 MPI（分发子分析）。

## kilocode（TUI，已打包）

`(@ (under-sea packages kilocode) kilocode)`（v7.8.8，MIT）。TUI 非独立程序：
`packages/tui`（`@opencode-ai/tui`，SolidJS，渲染基于 native `@opentui/core` 的 Zig 核）
由 `packages/opencode`（`@kilocode/cli`）消费；打包「TUI」= 打包单文件 `kilo` CLI（TUI 打包在内）。

- **来源**：`github.com/kilo-org/kilocode`，MIT，pin **v7.8.8**（归档 sha256 `ade22a13…`）。
- **per-origin 策略（已落地）**：`scripts/lock-kilocode.py` 从 `bun.lock`（JSONC）+ 下载的
  registry tarball 直算 sha256，生成 `under-sea/packages/kilocode-lock.scm`：**1890 个固定输出
  origin**（registry 包按 `https://registry.npmjs.org/<name>/-/<basename>-<version>.tgz` 推导；
  含 URL 依赖 `xlsx`）。构建期把这些 origin 解包进 `$BUN_INSTALL_CACHE_DIR`（复刻 bun 离线缓存
  布局：`<name>@<ver>@@@1/` 解包目录 + `cache/<name>/<sub>@@@1` 相对符号链接），再
  `bun install --frozen-lockfile --offline --ignore-scripts` **完全离线装配 node_modules**
  （1890 包），最后由 `bun build --single` 产出单文件 `kilo`。**依赖获取全部经 daemon 的
  `url-fetch`**（host 网络），因此绕开本机构建沙箱 DNS 不可用（10.0.2.3）的问题；构建阶段不触网。
- **构建期要点**：① 用 Python `tarfile`（`filter='data'`）解包 npm tar（部分含无执行位目录，
  GNU tar 会失败）并拍平唯一顶层目录；② `--ignore-scripts`（原生件已带预构建负载）；
  ③ 把 `node_modules/.bin/*` 的 `#!/usr/bin/env node` patch 到 store node；④ 跳过可选 web
  “Kilo Console”（Vite，与 TUI 无关）的构建；⑤ **禁用 build.ts 的 `patchelf --set-interpreter`**
  ——bun 编译的单文件二进制已内嵌 store glibc loader，patchelf 会破坏其自包含 ELF（exec 段错误）；
  ⑥ `#:strip-binaries? #f`——`strip` 会破坏 bun 单文件负载（退化成裸 bun）。
- **运行前置**：包装 `bubblewrap`（`KILO_BWRAP_PATH`）+ `ripgrep`（PATH）；`KILO_CHANNEL=local`、
  `KILO_VERSION=7.8.8`、`KILO_SKIP_BUNDLED_BWRAP=1`；模型快照 `MODELS_DEV_API_JSON` 固定为
  `planning/kilocode-models-dev-api.json`（sha256 `61ad2c…`），构建期不联网取模型。
- **安装布局**：`bin/kilo`（wrapper）与 `bin/.kilo-real` 及其运行期辅助件（`tree-sitter/` 的 37 个
  wasm、`kilo-sandbox-mutation-worker.js`/`kilo-sandbox-network-relay.js`/`kilo-sandbox-seccomp`
  静态 helper、`console/`、`licenses/`）一并安装到同目录（二进制按可执行文件所在目录解析它们）；
  剔除约 94 MiB 的调试 source map。
- **验证**：构建期烟雾（`--version`=7.8.8、`--pure models anthropic`、sandbox worker）全过；
  安装后 `kilo --version`=7.8.8、`kilo --help` 列出 kilo 子命令、`kilo completion bash` 正常。
- **预编译例外**：`@opentui/core-linux-x64`（Zig native）、`@parcel/watcher-linux-x64-glibc`、
  `@lydell/node-pty-linux-x64`、`@ff-labs/fff-bin-linux-x64-gnu`、`tree-sitter-bash/powershell`
  预构建——均以固定哈希 origin 表示，登记于 `planning/precompiled-exceptions.json`
  （kind `embedded-prebuilt`）。

## Ghidra（预编译发行版，已打包）

`(@ (under-sea packages ghidra) ghidra)`（**12.1.4**，Apache-2.0）。

- **来源**：官方 release 发行包
  `ghidra_12.1.4_PUBLIC_20260921.zip`（sha256 `ddac49f9…`，569,649,598 B），从
  `github.com/NationalSecurityAgency/ghidra/releases` 固定。
- **为何走预编译**：上游用 Gradle 构建；完全离线源码构建需要 vendoring 整套 Gradle 插件/Maven
  依赖闭包 + 外部 `ghidra.bin` 仓库（binutils/Z3/BSim postgres/GhidraServer yajsw/PyGhidra wheels
  等）。实测本机直连 GitHub ≈2 KB/s、Gradle plugin portal ≈0、raw ≈11 KB/s（Maven Central ≈211 KB/s、
  gh-proxy/Tencent 镜像 ≈27 MB/s）——源码路线可行但成本高，故先交付官方发行包（已登记预编译例外）。
- **Guix 适配**：① 启动脚本 shebang 改为 store bash；② 生成 `bin/` wrapper
  （`ghidraRun`/`analyzeHeadless`/`bsim`/`bsim_ctl`/…）设 `JAVA_HOME` 与 `PATH`；③
  `JAVA_HOME_OVERRIDE` pin 到 openjdk@21 的 **`jdk` 输出**（LaunchSupport 需完整 JDK 的 `javac`，
  纯 JRE 报 `unsupported java version`）；④ 原生件：`demangler_gnu`/`lzfse` 用 `patchelf` 改
  store 解释器 + `libstdc++`/`libgcc_s`（`gcc:lib`）RPATH；**`decompile`/`sleigh` 不能用 patchelf**
  ——会破坏 ELF 段（加载任何库之前即 SIGSEGV），改为保留 zip 原始件 `*.orig` 并用 store loader
  `--library-path` 的 wrapper 代理。
- **验证**：`analyzeHeadless` 打印 usage；导入+自动分析 `rc=0`；**真反编译**（Java GhidraScript
  反编译 `true` 的全部函数）`DECOMPILED 180/180 cchars=94776`，即反编译路径可用；构建期新增
  `check-native` 冒烟会以 `</dev/null` 跑每个原生件，若退出 ≥128（SIGSEGV）即构建失败。GUI
  （`ghidraRun`）需 X/显示环境。
- **残留（后续可升级为源码构建）**：跑通 `fetchDependencies → prepdev → buildGhidra`（镜像种子 +
  Gradle 离线缓存）后，可换成逐源锁定的源码包。

## Strata（本地大模型推理引擎，AMD/HIP 源码构建，已打包）

`(@ (under-sea packages strata) strata)`（**0.1.43.1**，MIT）。上游只发 Windows 预编译件；
NVIDIA 后端需 CUDA toolkit（Guix 与 nonguix 均无），故本包构建 **AMD/HIP** 后端。

- **工具链（实测跑通）**：`clang-rocm`(clang 20) + `rocm-device-libs` + `rocm-hip-runtime` +
  `rocr-runtime` + `hipblas`/`hipblas-common`/`rocblas`/`hipblaslt` + `lld` + `llvm`(objcopy) +
  `binutils` + `linux-libre-headers` + `gcc-toolchain@14`（clang 20 无法解析 GCC 16 的 libstdc++）。
- **ggml**：`llama-cpp-for-strata`（固定 llama.cpp 提交 `3cf03257…`），经 `-DSTRATA_GGML_DIR`
  提供，CMake 不再联网 FetchContent → 构建期离线。
- **关键接线**：`-DHIP_PLATFORM=amd`、`CMAKE_HIP_COMPILER=clang-rocm/bin/clang++`、
  `CMAKE_HIP_COMPILER_ROCM_ROOT=<hip-runtime>`、`CMAKE_HIP_FLAGS` 带 `--rocm-path=<device-libs>`、
  `-include __clang_hip_runtime_wrapper.h`、`-nostdinc++` + GCC14 的 C++ 头；HIP 设备链接需要
  `lld`→`ld.lld` 与 `llvm-objcopy`（构建期生成 PATH shim）；`CMAKE_PREFIX_PATH` 含
  hip-runtime/hipblas/hipblas-common/rocblas/hipblaslt/device-libs/rocr。
- **架构**：默认 `gfx1100;gfx1201`（上游验证的 RDNA3/RDNA4）；产物设 rpath 指向 ROCm/GCC 运行库
  （`#:validate-runpath? #f`）。
- **验证**：`strata --help`、`strata-device --help` 正常；`scripts/verify-packaging.sh` 全 PASS。
- **限制**：需 **AMD 独显**（RDNA2/3/4）；模型权重（数十 GB）运行期从 HuggingFace 下载，不在包内；
  本机只有 gfx1103 核显（不受支持）→ 仅做构建期验证，未跑模型。**NVIDIA/CUDA 后端未构建**。

### Strata 的 NVIDIA/CUDA 路线（后续；须在带 NVIDIA 卡的机器上继续）

CUDA toolkit 不在 `guix`/`nonguix`，而在 **`guix-hpc-non-free`**（re-export 自
**`guix-science-nonfree`**，`guix-science-nonfree/packages/cuda.scm`），提供
`cuda-10.2/11.0/11.7/11.8/12.2/12.3/12.4`：用 NVIDIA 官方 `.run` 安装器 + `install-linux.pl`
装出**含 `nvcc` 的完整 toolkit**，并已 `patchelf` 好 RPATH/解释器。做法：

1. `channels.scm` 追加频道（**需 pin 提交**；会连带拉 `guix-science-nonfree`/`guix-hpc`；
   与 `guix@d434a41` 的兼容性要实测）：
   ```scheme
   (channel (name 'guix-hpc-non-free)
            (url "https://gitlab.inria.fr/guix-hpc/guix-hpc-non-free.git")
            (commit "<pin>"))
   ```
2. 构建 `(@ (guix-science-nonfree packages cuda) cuda-12.4)`：`#:substitutable? #f`，本体是
   ~4 GB 的 NVIDIA `.run`（FOD，daemon url-fetch；慢的话按本仓库惯例用镜像 seed 进 store）。
3. 在 `under-sea/packages/strata.scm` 增加 NVIDIA 变体（或参数化）：
   - `-DSTRATA_ENABLE_HIP=OFF -DSTRATA_ENABLE_CUDA=ON`
   - `-DCMAKE_CUDA_ARCHITECTURES=89`（或 `75`/`86`；**CUDA 12.4 最高 sm_90，不支持
     RTX 50 的 sm_120**）
   - `CUDAToolkit_ROOT=<cuda>`（或 `-DCMAKE_CUDA_COMPILER=<cuda>/bin/nvcc`），去掉 ROCm 专属接线
     （clang-rocm/device-libs/lld shim 等）。
4. CUDA 属非自由预编译 → 登记 `planning/precompiled-exceptions.json`、`#:substitutable? #f`。
5. 功能验证须在带 NVIDIA 卡的机器上做（本机只有 AMD gfx1103 核显，仅完成了 HIP 的构建期验证）。

现有的 AMD/HIP 包（本文件上一节，提交 `d6821a2`）已构建通过并入库，可直接带走复用。

## codex-session-patcher（已打包）

`(@ (under-sea packages codex-session-patcher) codex-session-patcher)`：清理
Codex/Claude Code/OpenCode 会话文件里的拒绝回复。纯 Python、**核心 CLI 零运行期依赖**；
pin 提交 `cf7deab2d5b28c1f70f5b5498461848b69024a15`（源码归档 sha256
`52ae43fbf79c6ba53bda9c0cf089f0235040bc9ca6b1664022855e56247c74b3`），用
`pyproject-build-system` 构建，安装 `bin/codex-patcher`（`codex-patcher --help` 通过）。
构建期把可选 `web` 包/FastAPI 入口 `codex-patcher-web` 去掉（需要 fastapi 与 Vite 前端构建，
后者 dist 未提交）。许可：上游无 LICENSE 文件但 `pyproject.toml` 声明 MIT。

## 可选 extras（已打包）

| 组件 | extras | 说明 |
|---|---|---|
| Camoufox 运行时 | `geoip` + `gui` | `maxminddb@2.6.3`（`maxminddb-for-hermes`）、`PySide6@6.9.2` + `shiboken6@6.9.2`（channel `python-pyside-6`/`python-shiboken-6` 组件）；已 `import` 验证 |
| browser-use 运行时 | `examples`/`aws`/`oci`/`video` | `oci@2.166.0`、`boto3@1.42.37`/`botocore`、`imageio@2.37.2`+`imageio-ffmpeg@0.6.0`+`numpy@2.4.1`、`imgcat@0.6.0`、`agentmail@0.0.59`、`langchain-openai@1.1.14`+`tiktoken@0.14.0`；已 `import` 验证 |

- `tiktoken` sdist 不含 `Cargo.lock`；构建时由其 crate 清单生成
  `planning/tiktoken-Cargo.lock`，`lock-hermes-browser.py --cargo-lock-overrides` 注入。
- `orjson` 约束为 `3.11.4`（最新可被 channel 的 rustc 1.93 构建的版本）。

## 已知限制与可选未做

- **需外部条件**（凭据/网络/设备）：sing-box 真实出站连通、Codex 登录/执行、
  Porcupine 唤醒词（`PORCUPINE_ACCESS_KEY`）、Hermes LLM 端到端、云浏览器 provider（API key）。
  见 `scripts/verify-credentials.sh`。
- **已知上游冲突**：`hermes-agent-audio` 中在同一进程 import `onnxruntime` 与 `sherpa_onnx`
  会因重复注册 ONNX protobuf 描述符而 abort（`File already exists in database:
  onnx/onnx-ml.proto`）——`onnxruntime` 的 pybind 扩展与 `libonnxruntime` 各自静态编入
  ONNX 原型，`sherpa_onnx` 通过 `libonnxruntime` 触发二次注册。二者需分进程使用
  （如唤醒词引擎与 VAD 分进程），或待上游修复注册方式。
- **容器冒烟（R5）**：`guix system container` 的非特权冒烟需要 root，或与 Guix 映射
  (0..65536) 匹配的 `/etc/subuid` 子 uid 段；本机不满足（`sudo` 需密码），脚本按 SKIP
  处理并给出原因；PASS 路径在具备条件的主机上可用。
- **未做（可选）**：lightpanda 引擎二进制——`--engine lightpanda` 已支持，但上游仅发行
  预编译二进制（`lightpanda-x86_64-linux`，1.0.0 `sha256 aa5a4b8e…`），本机无法从 GitHub
  Releases 下载（TLS 反复中断），故未打包；Camoufox UBO 扩展默认排除（可传
  `exclude_addons` 关闭下载）。

