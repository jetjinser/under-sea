# under-sea Guix packages

Package definitions are evaluated with the Guix commit in `channels.scm`.

交付成果、预编译例外、已知限制与验证方式见 [成果与状态](STATUS.md)。单命令汇总门禁为
`scripts/verify-all.sh`（依次跑打包质量、包级冒烟、服务/系统级、凭据/网络门控）；各层也可
单独运行：`verify-packaging.sh`、`verify-phase7.sh`（含运行时 import 门禁
`verify-runtime-imports.sh`）、`verify-system.sh`、`verify-credentials.sh`。系统声明见
`under-sea/system/networking.scm`，VM 测试见 `under-sea/tests/`（含浏览器 e2e
`browser.scm`）。

## 清理构建残留

重型构建使用 `--keep-failed` 保留构建失败时的中间树于 `/tmp/guix-build-*`，反复
尝试会累积占用大量磁盘，完成后应及时清理：

```sh
scripts/clean-build-artifacts.sh --dry-run   # 预览
scripts/clean-build-artifacts.sh             # 删除超过 2 小时未写入的构建树
```

脚本只处理当前用户所有、且 `--min-age`（默认 120 分钟）内无写入的目录，先
`chmod -R u+w` 清掉 npm/Go 解包产生的只读子目录，避免误删正在进行的构建。root
保留的 `/tmp/guix-build-*.pivot` 需 root 手动删除。

## sing-box

The package targets `x86_64-linux` and builds sing-box **1.14.2** and its Go
dependencies from source. It uses upstream default build tags except
`with_naive_outbound` (precompiled cronet libraries) and `with_tailscale`
(prebuilt web client). This includes QUIC/Hysteria/TUIC, WireGuard, uTLS,
gVisor, ACME, DHCP, Clash API and the remaining upstream default features.

```sh
guix time-machine -C channels.scm -- build -L . -e '(@ (under-sea packages sing-box) sing-box)'
guix time-machine -C channels.scm -- shell -L . -e '(@ (under-sea packages sing-box) sing-box)' -- sing-box version
guix time-machine -C channels.scm -- install -L . -e '(@ (under-sea packages sing-box) sing-box)'
```

The explicit package expression avoids scanning `channels.scm` as a package
module. These commands were verified against the pinned channel; compilation
and the CLI configuration checks passed with Go 1.25.12.

The package compiles with Guix's Go 1.25. Each module `.mod`, `.info` and
selected source `.zip` is a hash-pinned Guix origin. Compilation uses a local
`file://` module proxy with `GOTOOLCHAIN=local` and `-mod=readonly`: the build
cannot download dependencies or another compiler. The upstream `go.sum` is
also retained. Guix hashes authenticate the downloaded inputs even though
the online Go checksum database is disabled during the offline build.
Binary substitution is disabled for sing-box itself; Guix may still obtain
the compiler and other build tools from its usual substitute servers.

Build checks run `sing-box version`, validate a minimal direct-outbound
configuration, and require an invalid protocol to be rejected. Network and
privileged TUN integration tests are not run in
the build container. Shell completions and the license are installed; this
package does not configure a running proxy or install a Shepherd service.

## Refreshing the source lock

Run this only when changing the version or build tags. Dependency resolution
requires network access; the subsequent Guix build does not.

```sh
curl -fL https://codeload.github.com/SagerNet/sing-box/tar.gz/refs/tags/v1.14.2 \
  -o /tmp/sing-box-1.14.2.tar.gz
tar -xzf /tmp/sing-box-1.14.2.tar.gz -C /tmp
guix time-machine -C channels.scm -- shell go@1.25.12 python-minimal -- \
  python3 scripts/lock-sing-box.py 1.14.2 \
  /tmp/sing-box-1.14.2.tar.gz /tmp/sing-box-1.14.2
```

Use a fresh `--cache` directory when changing sources or features; interrupted
downloads for the same source/features can be resumed. The script preserves Go's
checksum verification during resolution and writes the lock atomically only
after all required sources have been downloaded. Review the generated
`under-sea/packages/sing-box-lock.scm` before building.

The locker respects `GOPROXY` or an explicit `--proxy`. Its default tries
`goproxy.cn` directly, then `proxy.golang.org`; Go checksum verification stays
enabled. Generated origins use the canonical `proxy.golang.org` addresses.

Optional: avoid downloading the same hash-pinned files twice by seeding the
store with the locker's downloaded files. Guix still verifies their hashes.

```sh
guix time-machine -C channels.scm -- repl -- \
  scripts/seed-source-cache.guile /tmp/under-sea-sing-box-lock/inputs
guix time-machine -C channels.scm -- build -L . -e '(@ (under-sea packages sing-box) sing-box)'
```

`channels.scm` is unchanged. The source lock is intended for this personal
package collection; contributing to upstream Guix would additionally require
reviewing its packaging conventions and the bundled module dependencies.

## dae

The dae package targets `x86_64-linux` and pins release **2.1.1**. It builds
the Go executable and embedded eBPF programs from source, including `dae trace`.
Both `dae_bpf_headers` submodules are pinned to the release's commit
`56937c66784879fe5e2ff89db5bc05aa061d594c`. The builder uses Guix's Go 1.26
and Clang/LLVM 15, and retains the upstream Go experiment settings.
The commands below were verified with the pinned channel: the source build,
selected upstream tests and CLI configuration checks all passed.

```sh
guix time-machine -C channels.scm -- build -L . \
  -e '(@ (under-sea packages dae) dae)'
guix time-machine -C channels.scm -- shell -L . \
  -e '(@ (under-sea packages dae) dae)' -- dae --version
guix time-machine -C channels.scm -- install -L . \
  -e '(@ (under-sea packages dae) dae)'
```

All Go module archives and metadata are hash-pinned inputs to an offline
`file://` proxy. The builder regenerates the Go/C constants and compiles the
eBPF programs rather than embedding precompiled objects or building with
`dae_stub_ebpf`. Read-only Go module flags and a local toolchain prevent
dependency downloads during compilation. Binary substitution is disabled for
dae itself; build tools may use Guix's signed substitutes.

The check phase runs upstream tests for configuration decoding, the config
parser, prefix tries and eBPF constants. It also checks version/trace CLI output,
accepts a minimal direct-routing configuration and rejects an unknown routing
function. Privileged eBPF attachment and live traffic tests require a suitable
Linux kernel and are not run in the build container.

Shell completions and `example.dae` are installed. GeoIP/geosite data are
separate runtime inputs when using geographic rules; set `DAE_LOCATION_ASSET`
to their directory or place them beside the configuration. The package does
not start a daemon or install a Shepherd service.

To refresh the lock, download the release source and the headers archive for
the exact submodule commit recorded in the release's Git tree, then run:

```sh
guix time-machine -C channels.scm -- shell go@1.26.8 python-minimal -- \
  python3 scripts/lock-dae.py 2.1.1 \
  /tmp/dae-2.1.1.tar.gz /tmp/dae-2.1.1 \
  56937c66784879fe5e2ff89db5bc05aa061d594c \
  /tmp/dae-bpf-headers-56937c6.tar.gz
guix time-machine -C channels.scm -- repl -- \
  scripts/seed-source-cache.guile /tmp/under-sea-dae-lock/inputs
```

The locker uses the same proxy fallback and checksum verification policy as
the sing-box locker. Its cache is independent; use a fresh `--cache` directory
for a different release, headers commit or toolchain.

## 可选的网络服务集成

`(under-sea services networking)` 提供 `dae-service-type` 和
`sing-box-service-type`。在 Guix System 配置中显式加入所需服务：

```scheme
(use-modules (under-sea services networking))

;; 加入 operating-system 的 services 列表；配置文件由用户管理。
(service dae-service-type
         (dae-configuration
          (config-file "/etc/dae/config.dae")
          (state-directory "/var/lib/dae")))
(service sing-box-service-type
         (sing-box-configuration
          (config-file "/etc/sing-box/config.json")
          (state-directory "/var/lib/sing-box")))
```

这两个服务使用 root 权限满足 TUN/eBPF 功能，状态目录权限为 0700。
dae 可用 `asset-directory` 指定已有 GeoIP/geosite 数据目录。
本仓库提供 `dae-geodata`，将源码生成的两种数据集中于 `share/dae`：

```sh
guix time-machine -C channels.scm -- build -L . \
  -e '(@ (under-sea packages dae-data) dae-geodata)' \
  --cores=1 --max-silent-time=7200 --keep-failed
```

服务配置可直接引用数据包，Guix 会将其纳入系统闭包：

```scheme
(use-modules (guix gexp) (under-sea packages dae-data))
(service dae-service-type
         (dae-configuration
          (config-file "/etc/dae/config.dae")
          (asset-directory (file-append dae-geodata "/share/dae"))))
```

已有数据目录仍可传字符串；手动运行 dae 时也可将数据目录赋给
`DAE_LOCATION_ASSET`。GeoIP、geosite 和组合包均已源码构建成功，实际路由
验证留待统一验收。DB-IP 数据署名及许可保留于包的文档目录，更新时
需重新锁定来源和构建数据包。

配置文件保留在 store 之外；添加服务前先准备对应配置和内核/网络条件。
目前只完成服务定义的固定 channel 解析；服务生命周期和真实流量验证留待统一验收。
本次打包没有执行系统 reconfigure，也没有启动服务。

### 更新 dae 地理数据

数据更新保持 `channels.scm` 固定。先选择官方完整提交、取得对应源码归档并
解包，再对每个新提交使用独立缓存生成 Go 来源锁。例如当前来源的锁定命令为：

```sh
guix time-machine -C channels.scm -- shell go@1.25.12 python-minimal -- \
  python3 scripts/lock-geosite.py \
  63777333b7dd1ac57f790e466c0f6a647b9c7281 \
  /tmp/under-sea-dae-data/geosite-source.tar.gz \
  /tmp/under-sea-dae-data/domain-list-community-63777333b7dd1ac57f790e466c0f6a647b9c7281
guix time-machine -C channels.scm -- shell go@1.26.8 python-minimal -- \
  python3 scripts/lock-geosite.py \
  fd96fbac6cffc06ab9a10d6ee8fad61afe9b771c \
  /tmp/under-sea-dae-data/geoip-source.tar.gz \
  /tmp/under-sea-dae-data/geoip-fd96fbac6cffc06ab9a10d6ee8fad61afe9b771c \
  --project geoip
```

脚本需要 PATH 中可联网且有正确 CA 配置的 curl；Go zip/mod 仍通过 checksum
数据库验证，`.info` 核对代理与缓存的完整 JSON 内容后锁定代理原始字节。
更新提交时加 `--cache` 指向新目录，审查生成的 geosite-lock/geoip-lock 和
`planning/dae-data-sources.json`。DB-IP 更新单独选择年月 CSV，记录新 URL、
SHA256 和许可，更新 `planning/dae-dbip-source.json` 及 `dae-data.scm` 的
CSV origin、版本、署名年月；不只修改版本字符串。

最后重新构建 `dae-geodata`。服务配置引用包后，新的数据会随后续系统配置
更新纳入闭包；已有 store 文件不原地替换，旧配置仍引用其固定数据版本。
真实地理规则和服务生命周期验证留到统一验收。

## Hermes Agent

The package targets `x86_64-linux`, release **v2026.9.24** (Python project
version **0.21.5**). It provides the classic Python CLI and its 62 locked core
Python dependencies. Runtime dependencies, including Rust extensions, are
built from source in the Guix sandbox using 746 hash-pinned registry crates.
Wheels are built locally as intermediate artifacts; binary Python wheels are
not downloaded.

The pinned-channel source build passed the installed CLI, exact dependency
version checks, Pydantic/JSON validation, native cryptography and image checks,
Chinese FTS5 loading/search, database initialization, local terminal execution
and the Guix update guard. These checks do not call model APIs.

```sh
guix time-machine -C channels.scm -- build -L . \
  -e '(@ (under-sea packages hermes) hermes-agent)'
guix time-machine -C channels.scm -- shell -L . \
  -e '(@ (under-sea packages hermes) hermes-agent)' -- hermes --cli
guix time-machine -C channels.scm -- install -L . \
  -e '(@ (under-sea packages hermes) hermes-agent)'
```

The package includes bundled skills, plugins, translations and the source-built
Chinese FTS5 extension. Configuration, credentials and persistent state stay
in the user's usual Hermes home. `hermes update` refuses in-place changes to
the store installation; update the definition and use Guix instead. Automatic
pip installation is disabled for the packaged runtime.

The pinned Python links SQLite 3.39.3. Hermes detects its WAL-reset issue and
automatically uses DELETE journal mode; the database checks exercise this
fallback. A newer SQLite runtime is needed to use WAL mode.

Node TUI, web/desktop interfaces, ACP, and optional messaging, voice and browser
extras are outside this initial core package. Use `--cli` if an existing
configuration selects another interface. Model APIs still require the user's
credentials. The package does not start services or modify user profiles.

独立 `hermes-agent-interfaces` 组合增加 MCP、ACP、dashboard 后端等 Python 依赖，
尚不包含 Node 前端及其他完整集成。

Nemo Relay's precompiled `protoc-bin-vendored` dependencies are replaced with
Guix's protobuf compiler. Native extensions link to Guix store libraries.

To refresh the lock, download and extract the exact release source, then run:

```sh
guix time-machine -C channels.scm -- shell python-minimal curl -- \
  python3 scripts/lock-hermes.py \
  /tmp/hermes-agent-2026.9.24.tar.gz /tmp/hermes-agent-2026.9.24
# Optional: reuse already verified source downloads.
cp /tmp/hermes-agent-2026.9.24.tar.gz /tmp/under-sea-hermes-lock/inputs/
guix time-machine -C channels.scm -- repl -- \
  scripts/seed-source-cache.guile /tmp/under-sea-hermes-lock/inputs
```

Use a fresh `--cache` directory for a different release. The optional
`--crate-mirror https://mirrors.sjtug.sjtu.edu.cn/crates.io/crates` changes only
the download location: generated origins retain official addresses and every
file must match the upstream lock's SHA-256 checksum. Dependency markers use
fixed Linux x86_64 and Python 3.12 values rather than the locker's host values.

### Hermes 界面组件的构建状态

`hermes-web-assets` 已从锁定 Node 来源、源码原生 binding 和 Three 核心
源码构建，安装到 `share/hermes-web`，包含首页及其引用的资源。此包只提供
静态文件。Shiki 4.3.1 和 Streamdown 内嵌的 Shiki 3.23.0 WebAssembly 均由
固定 Oniguruma 子模块源码构建，并替换前端归档中的内嵌载荷；替换来源、原
归档及 WASM SHA256 记录在 `share/hermes-web/hermes-shiki-wasm-source-replacements.json`。
`hermes-dashboard` 组合 Python 集成运行时并提供同名启动命令，
通过上游 `HERMES_WEB_DIST` 指向这些文件；组合包仍在构建，尚未做功能验收。
TUI、桌面端和完整音频运行时的状态见 `STATUS.md`。

### Hermes 音频组合

`hermes-agent-audio` 配方组合锁定的协议、云集成和音频 Python 来源，以及
源码构建的 CTranslate2、ONNX Runtime、TFLite、Sherpa、FlatBuffers 和 Pilk。
PortAudio 使用明确的 store 库路径，FFmpeg 同时用于 PyAV 编译和转换工具。
该组合已构建成功（`import pvporcupine` 等冒烟通过）；完整音频功能验证需设备与
唤醒词凭据，见 `scripts/verify-credentials.sh`。

```sh
guix time-machine -C channels.scm -- build -L . \
  -e '(@ (under-sea packages hermes-audio) hermes-agent-audio)' \
  --cores=1 --max-silent-time=7200 --keep-failed
```

Porcupine 4.0.3 的归档包含原生库，但未提供对应引擎源码，因此不复制这些库。
这个未完成项记录于来源锁及安装目录的
`share/hermes-agent/source-unavailable-components.scm`。模型、音频设备和
第三方服务凭据仍需单独配置；Node/桌面入口是另外的组件。

刷新该组合来源时，locker 的 `--record-unbuildable` 必须配合精确版本和归档
哈希匹配的 `--source-audit`。此选项保留源码不可得记录并锁定其余来源，
不会将组合标记为完整；不传此选项时，locker 继续拒绝这类完整来源锁。

```sh
guix time-machine -C channels.scm -- build -L . \
  -e '(@ (under-sea packages hermes-node) hermes-web-assets)' \
  --cores=1 --max-silent-time=7200 --keep-failed
guix time-machine -C channels.scm -- build -L . \
  -e '(@ (under-sea packages hermes-node) hermes-dashboard)' \
  --cores=1 --max-silent-time=7200 --keep-failed
```

### 共享音频运行时的界面组合和技能工具

`hermes-agent-audio-interfaces` 将源码 TUI 和 dashboard 接到同一个
`hermes-agent-audio` 私有 Python 运行时，并将常见 Linux 技能工具目录接入
CLI、TUI 和 dashboard 的子进程 PATH，复用独立组件输出。桌面端与浏览器构建链
已作为独立组件交付（见 `STATUS.md`）。
TUI 后端默认使用启动时的工作目录，可用 `HERMES_CWD` 指定；Python 模块
仍由固定私有运行时提供。

```sh
guix time-machine -C channels.scm -- build -L . \
  -e '(@ (under-sea packages hermes-audio-interfaces) hermes-agent-audio-interfaces)' \
  --cores=1 --max-silent-time=7200 --keep-failed
```

可选的 `hermes-linux-skill-tools` 引用固定 channel 的 16 个常见 CLI：
图像和音视频处理、Git、Node/npm、PDF/办公文档转换、网络诊断、音频会话
及 Docker/uv 客户端。Docker 和 PulseAudio 仍需要单独配置服务、权限或设备；
该集合不启动服务。专用客户端、模型和技能动态依赖仍待审计。

```sh
guix time-machine -C channels.scm -- build -L . \
  -e '(@ (under-sea packages hermes-tools) hermes-linux-skill-tools)' \
  --cores=1 --max-silent-time=7200 --keep-failed
```

技能工具集合已完成实际组装，16 个入口及来源路径记录在
`planning/hermes-linux-skill-tools-artifacts.json`；已随 `hermes-agent-integrations`
接入 Hermes 运行时。功能验证见 `scripts/verify-phase7.sh`。

## Codex（本地维护）

Codex 固定为 `0.160.0`，使用 `channels.scm` 中的 Rust 1.95.0。
上游 Guix 已删除旧 Codex 包，本仓库独立维护包定义及源码依赖锁。
registry crates 按上游 `Cargo.lock` 的 SHA256 校验；Git 依赖保留准确提交，
构建中替换为对应的本地源码路径，不替换成不同的 crates.io 版本。

```sh
guix time-machine -C channels.scm -- build --cores=4 --max-silent-time=7200 \
  --keep-failed -L . -e '(@ (under-sea packages codex) codex)'
guix time-machine -C channels.scm -- shell -L . \
  -e '(@ (under-sea packages codex) codex)' -- codex --version
guix time-machine -C channels.scm -- install -L . \
  -e '(@ (under-sea packages codex) codex)'
```

构建最多使用 4 个 Cargo 任务，关闭跨 crate 的 release LTO 以降低链接内存，
关闭调试符号以减少构建产物；包属性设置 `max-silent-time` 为 7200 秒，
避免长时间静默编译或链接被终止。
检查限定为 CLI 启动、帮助信息和 execpolicy 单元测试，不运行整个 workspace
依赖网络或内核沙箱的集成测试。

已验证默认 graft 构建、7 个 execpolicy 单元测试，以及安装后的 CLI、规则解析、
direct 模型目录和辅助程序。4 个 Cargo 任务下，主程序编译阶段约 38 分钟，
不含输入下载和测试；这仍是一个较大的 Rust 构建。

在支持非特权 user namespace 的本地环境中，可以额外检查真实 Linux 沙箱：

```sh
guix time-machine -C channels.scm -- shell python-minimal -- \
  python3 scripts/check-codex.py --sandbox /gnu/store/…-codex-0.160.0
```

请替换实际构建输出路径，并从 `/tmp` 之外的可写目录运行。
省略 `--sandbox` 可只运行离线 CLI 检查。检查使用临时配置，不发送模型请求。

第一版包含 CLI、Linux sandbox，以及 Guix 的 bubblewrap 和 ripgrep。
**不包含本地 V8 `codex-code-mode-host`、独立语音 host 或托管 zsh。**
本地 V8 code mode 无法使用；要求 code mode 的模型需要另外配置。
包中提供 `share/codex/guix-models-direct.json` 作为显式选择的替代模型目录，
仅将上游模型目录中的 `tool_mode` 改为 `direct`，不改变用户配置或内置目录。
可以在 `~/.codex/config.toml` 的顶层设置：

```toml
model_catalog_json = "/gnu/store/…-codex-0.160.0/share/codex/guix-models-direct.json"
```

请用实际构建结果替换上述 store 路径。该目录随包版本固定；模型在 direct
模式下的效果与完整 V8 code mode 版本可能不同。

更新依赖锁（联网在构建外进行）：

```sh
curl -fL https://codeload.github.com/openai/codex/tar.gz/refs/tags/rust-v0.160.0 \
  -o /tmp/codex-0.160.0.tar.gz
tar -xzf /tmp/codex-0.160.0.tar.gz -C /tmp
guix time-machine -C channels.scm -- shell python-minimal -- \
  python3 scripts/lock-codex.py /tmp/codex-0.160.0.tar.gz /tmp/codex-rust-v0.160.0
# 可选：复用锁定时下载且验证过的输入。
guix time-machine -C channels.scm -- repl -- \
  scripts/seed-source-cache.guile /tmp/under-sea-codex-lock/inputs
```

## Autodesk Moldflow Insight 2027（专有 thin-client）

固定版本 **2027.0.2**。上游仅发行专有预编译安装器（Autodesk EULA 禁止再分发），
故本包是**预编译例外**且 `#:substitutable? #f`，需自备从 Autodesk 账户下载的归档：

```sh
export MOLDFLOW_ARCHIVE=/path/to/Autodesk_MFIU_2027_Multilingual_Linux_64bit.tar.bz2
guix time-machine -C channels.scm -- build -L . \
  -e '(@ (under-sea packages moldflow) moldflow-insight-thinclient)' \
  --cores=1 --max-silent-time=7200 --keep-failed
```

包内是产品树（`.../autodesk-moldflow-insight-2027/bin/{runstudy,flow,cool,warp,…}`）
与 Simulation Compute Manager，并生成 `mfclient.env`、`insight.config.json`。
运行前 source 该文件（导出 `AUTODESK_ADLM_THINCLIENT_ENV`/`SCM_BASE`/`SCM_DATAPATH`/`MFSYN_HOME`）：

```sh
. /gnu/store/…-moldflow-insight-thinclient-2027.0.2/mfclient.env
```

许可（Autodesk Licensing Service）与 SCM 生命周期是外部条件；`flow` 等求解器在无许可时
报 `environmentNotReady`，`license_diagnostics` 可达 ADLM SDK 但需订阅/许可服务，
因此归入 `scripts/verify-credentials.sh` 的门控项。

可选：用 `moldflow-scm-service-type`（`(under-sea services moldflow)`）运行 SCM 守护进程，
状态目录可写、许可服务器可选（Named-user/云许可则省略 `license-server`）：

```scheme
(use-modules (under-sea services moldflow))
(service moldflow-scm-service-type
         (moldflow-scm-configuration
          (state-directory "/var/lib/moldflow-scm")
          (license-server "lic.example.com:2080")))
```

许可服务：Moldflow 经 **Autodesk Licensing Service** 取许可。该服务由同一归档的
workstation 安装器提供（包 `(@ (under-sea packages adsk-licensing) adsk-licensing)`），
用 `adsk-licensing-service-type` 启动，状态在 `/var/opt/Autodesk/AdskLicensingService`：

```scheme
(use-modules (under-sea services adsk-licensing))
(service adsk-licensing-service-type)
```

启用后配置许可方式（`ADSK_SERVICE_ADDRESS` 指向网络许可服务器，或 named-user/云登录），
再 source `mfclient.env` 运行 `runstudy`。就绪情况见 `scripts/verify-credentials.sh`。

服务以非特权 `adsklic` 账号运行（与上游一致），只有创建 `/var/opt/Autodesk/...` 需 root。
该服务有 VM 系统测试（`scripts/verify-system.sh` 里的 `adsk-licensing` 项，marionette，
不需要主机 root），验证服务启动、状态目录归属与进程用户；它需要本地归档才能构建。

注意：Autodesk 官方仅列 RHEL 8.6+/9.0+ 为受支持平台，Guix System 不在列；SCM 不是 MPI
求解器（它把 DOE/优化等子分析分发到节点）。

## kilocode（TUI）

固定版本 **7.8.8**（MIT）。TUI 不是独立程序：`packages/tui`（`@opencode-ai/tui`，SolidJS，
渲染基于 native `@opentui/core`）由 `packages/opencode`（`@kilocode/cli`）消费，因此打包「TUI」
即打包单文件 `kilo` CLI（TUI 已打进该二进制）。

```sh
guix time-machine -C channels.scm -- build -L . \
  -e '(@ (under-sea packages kilocode) kilocode)' \
  --cores=1 --max-silent-time=7200 --keep-failed

guix time-machine -C channels.scm -- shell -L . \
  -e '(@ (under-sea packages kilocode) kilocode)' -- kilo --version
```

依赖以 **per-origin** 固定：`under-sea/packages/kilocode-lock.scm` 为 `bun.lock` 里的 1890 个
非 workspace 包各生成一个固定 sha256 的 `url-fetch` origin（由 `scripts/lock-kilocode.py` 生成）。
构建期把这些 origin 解包进 bun 的离线缓存目录，`bun install --frozen-lockfile --offline`
完全离线装配 node_modules，再 `bun build --single` 产出单文件二进制——**获取全部经 guix-daemon
的 `url-fetch`，构建阶段不触网**（本机沙箱 DNS 不可用，故不走 FOD）。

- 运行前置：`bubblewrap` 与 `ripgrep` 已包装进 `bin/kilo`（分别经 `KILO_BWRAP_PATH` 与 `PATH`）；
  wrapper 同时设 `KILO_DISABLE_MODELS_FETCH=1`（使用内嵌模型快照）。二进制按可执行文件所在目录
  解析运行期辅助件，故 `tree-sitter/`、sandbox worker/seccomp、`console/`、`licenses/` 与其同目录安装
  （调试 source map 已剔除）。
- 模型目录使用固定的 `planning/kilocode-models-dev-api.json`（`MODELS_DEV_API_JSON`），构建期不联网。
- 预编译原生件（`@opentui/core-linux-x64`、`@parcel/watcher-linux-x64-glibc`、
  `@lydell/node-pty-linux-x64`、`@ff-labs/fff-bin-linux-x64-gnu`、`tree-sitter-bash/powershell`）
  以哈希固定的 origin 表示，登记在 `planning/precompiled-exceptions.json`。
- 刷新锁：联网运行 `scripts/lock-kilocode.py`（见脚本 `--help`），随后跑 `scripts/verify-locks.sh`。

## Ghidra

固定版本 **12.1.4**（Apache-2.0），**来自官方 release 发行包**（预编译例外）。Ghidra 用 Gradle
构建；完全离线的源码构建需要把整套 Gradle 插件/Maven 依赖闭包与外部的 `ghidra.bin` 仓库一起
vendoring，而本机直连 GitHub 与 Gradle plugin portal 被限速到几 KB/s（实测），故先采用官方发行包。

```sh
# 直连 GitHub 很慢（~2 KB/s）。可先经镜像下载再 seed 进 store，daemon 之后即可离线构建：
curl -fL -o ghidra_12.1.4_PUBLIC.zip \
  https://gh-proxy.com/https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.4_build/ghidra_12.1.4_PUBLIC_20260921.zip
guix time-machine -C channels.scm -- download "file://localhost$PWD/ghidra_12.1.4_PUBLIC.zip"

guix time-machine -C channels.scm -- build -L . \
  -e '(@ (under-sea packages ghidra) ghidra)' \
  --cores=1 --max-silent-time=7200 --keep-failed

guix time-machine -C channels.scm -- shell -L . \
  -e '(@ (under-sea packages ghidra) ghidra)' -- analyzeHeadless
```

- 安装 `bin/{ghidraRun,analyzeHeadless,bsim,bsim_ctl,ghidraClean,ghidraDebug,GhidraGo,buildGhidraJar,pyghidraRun}`；
  wrapper 设 `JAVA_HOME`（openjdk@21 的 `jdk` 输出——Ghidra 的 LaunchSupport 需要完整 JDK 的
  `javac`，纯 JRE 会被拒绝）与 `PATH`。
- 脚本 shebang 改为 store bash。原生件：`demangler_gnu`/`lzfse` 用 `patchelf` 指向 store loader 并
  加 `libstdc++`/`libgcc_s`（`gcc:lib`）RPATH；**`decompile`/`sleigh` 不可 patchelf**（会破坏 ELF
  段，加载库前即 SIGSEGV），故保留原始件为 `*.orig`，用 store loader `--library-path` 的 wrapper 代理。
  构建期 `check-native` 冒烟会以 `</dev/null` 跑各原生件，退出码 ≥128（SIGSEGV）即失败。
- 预编译例外，登记于 `planning/precompiled-exceptions.json`。`analyzeHeadless` 已实测导入+分析
  成功，且**真反编译**（Java GhidraScript 反编译 `true` 全部函数）`DECOMPILED 180/180`；GUI
  （`ghidraRun`）需要 X/显示环境。

## Strata（本地大模型推理引擎，AMD/HIP）

固定版本 **0.1.43.1**（MIT）。上游是「在消费级显卡上跑 Qwen3.8-Flash-Next」的本地推理引擎，
**仅发 Windows 预编译件**；Linux 需从源码编译。NVIDIA 后端需要 CUDA toolkit（Guix 与 nonguix
都没有），因此本包构建 **AMD/HIP** 后端，使用 Guix 的 ROCm 7 工具链。

```sh
guix time-machine -C channels.scm -- build -L . \
  -e '(@ (under-sea packages strata) strata)' \
  --cores=4 --max-silent-time=7200 --keep-failed

guix time-machine -C channels.scm -- shell -L . \
  -e '(@ (under-sea packages strata) strata)' -- strata-device --help
```

- 引擎用 `clang-rocm`（HIP）、`rocm-device-libs`、`rocm-hip-runtime`、`rocr-runtime`、
  `hipBLAS`/`rocBLAS`/`hipBLASLt` 编译；ggml 取自固定的 llama.cpp 快照
  （`llama-cpp-for-strata`，提交 `3cf03257…`），CMake 不再联网 FetchContent。
- clang-rocm 20 无法解析 GCC 16 的 libstdc++，故用 `gcc-toolchain@14`；设备链接需要
  `lld`→`ld.lld` 与 `llvm-objcopy`（构建期以 PATH shim 提供）。
- HIP 目标架构默认 `gfx1100;gfx1201`（上游验证的 RDNA3/RDNA4）。
- 运行需要 **AMD 独立显卡**（RDNA2/3/4）；模型权重（数十 GB）在运行期从 HuggingFace 下载，
  不在包内。NVIDIA/CUDA 后端未构建。
