# 四个包的缺口与补全顺序

整理日期：2026-10-05。固定版本和完整实施记录见 [COMPLETION-PLAN.md](COMPLETION-PLAN.md)。
本清单仅整理已识别缺口，不启动新构建或功能验证。已有独立产物仍须接入最终包，不能据此认定功能完整。技能和插件的动态依赖尚需继续审计。

## Codex

| 编号 | 组件 | 剩余工作 |
|---|---|---|
| C1 | V8 / code-mode host | 完成正式 host 源码构建及最终包接入；已有 V8 静态库产物不能替代 host。 |
| C2 | voice host | 已有独立/组合构建记录；核对最新最终包的音频库、插件及资源路径。 |
| C3 | 上游补丁 zsh | 已有源码产物；核对最新最终组合使用的固定路径。 |
| C4 | TypeScript SDK、辅助入口 | 交付 SDK 独立包；核对消费者所需的辅助程序。CLI 子命令与独立程序分别登记。 |

## Hermes

| 编号 | 组件 | 剩余工作 |
|---|---|---|
| H1 | MCP | 将协议、stdio/HTTP 依赖及入口接入共同 Python 运行时；外部 MCP server 单独登记。 |
| H2 | ACP | 接入协议依赖和恢复对应入口。 |
| H3 | Node TUI | 接入已有前端与完整后端，核对源码根目录、工作目录和启动器。 |
| H4 | Web dashboard | 接入后端及已有静态资源；补齐 Shiki、Three 等动态资源与 WASM，统一 Python 运行时。 |
| H5 | Linux 桌面端 | 源码构建 Electron、node-pty，接入共享前端、图标、资源及桌面入口。 |
| H6 | 模型 SDK / 认证 | 整合 Anthropic、Bedrock、Vertex、Azure、Mistral 原生 SDK 和共同依赖。 |
| H7 | 搜索 / 图像后端 | 接入 Exa、Firecrawl、Parallel Web、fal-client。 |
| H8 | 云终端后端 | 接入 Modal、Daytona、Vercel；登记 Docker、SSH 等外部程序与服务条件。 |
| H9 | 消息网关 | 整合 Telegram、Discord/voice、Slack、Matrix/加密、钉钉、飞书、企业微信、Teams、Google Chat；登记 Home Assistant/SMS 条件。 |
| H10 | 云语音 | 整合 Edge TTS、ElevenLabs、Mistral 语音接口及源码构建的 SILK 解码器。 |
| H11 | 本地语音 / 采集 | 完成 faster-whisper、CTranslate2、ONNX Runtime、PortAudio 和匹配 NumPy 的最终音频组合。 |
| H12 | 唤醒词 | 整合 openWakeWord、TFLite、sherpa-onnx、sentencepiece 及模型路径；Porcupine 保留源码不可得条件项。 |
| H13 | 记忆后端 | 整合 Honcho、Supermemory、Mem0；继续核对插件的嵌入模型、数据库及服务要求。 |
| H14 | 技能 / 插件 / 上传 | 接入已有常用 CLI 集合；继续审计 gws、brv、Ollama、OpenViking、buzz、raft 等专用工具及动态调用；补齐 transcript、Workspace、轨迹上传依赖。 |
| H15 | 监控 | 整合 OpenTelemetry SDK、OTLP HTTP exporter 及匹配 protobuf。 |
| H16 | 浏览器 / computer-use | 完成 agent-browser 的 Rust CLI、Next dashboard 源码链；提供源码浏览器、驱动及发现路径，继续审计 Camofox/browser-use 等后端。 |
| H17 | SQLite WAL | 将已有匹配 SQLite/Python 接入所有最终入口。 |

H16 的前置链必须单独完成：源码 Node 模块和工具 → 匹配 SWC/Rspack、图像库与 WASM → Next 16.0.8/analyzer → Next 16.1.1 → dashboard 静态导出 → agent-browser CLI。来源锁或原生 binding 成功均不能替代整条链完成。

其中 React 的 canary/experimental vendor 和 React Compiler 也须从匹配源码生成；补齐 esbuild Node API、Rollup 原生与 JS 工具、Closure Compiler 等构建依赖后，才能完成 Next 的 vendor 任务。Next 的 WASI 标准库、错误处理插件、polyfill 与 OG 资源分别跟踪，不能仅用现成 registry 编译产物填充。

## sing-box 与 dae

| 编号 | 组件 | 剩余工作 |
|---|---|---|
| S1 | NaiveProxy outbound | 按约定延期；后续源码构建 Cronet/Chromium，启用 tag 并更新来源锁。 |
| S2 | Tailscale 集成 | 按约定延期；后续构建嵌入 Web 资源、启用 tag 并更新来源锁。 |
| S3 | sing-box 服务配套 | 收尾已有 Shepherd 定义的配置、数据目录、TUN/路由及权限说明。 |
| D1 | dae GeoIP/geosite | 已有源码生成的数据产物；收尾固定来源、许可、更新流程及资源路径说明。 |
| D2 | dae 服务配套 | 收尾已有普通/trace 构建及服务定义的配置、内核条件、权限与状态目录说明。 |

## 执行计划

1. 收尾 Codex host、SDK、辅助入口及最终组合。
2. 收尾 Hermes 共同 Python 环境，统一 integrations、音频、dashboard 的依赖和资源路径。
3. 接入 TUI/Web，补齐前端动态资源。
4. 完成 agent-browser 嵌套源码构建链，再提供源码浏览器与驱动。
5. 完成 Electron 桌面端，共享已构建的界面资源。
6. 收敛技能、插件、模型与外部服务清单，组装 Hermes 最终包。
7. 收尾网络包的数据与服务文档；NaiveProxy、Tailscale 保持延期。
8. 补全交付后统一开展功能验证，记录通过、失败和外部条件未满足的用例。

独立组件允许并行构建；最终组合须按依赖顺序完成。所有 Guix 操作显式使用 `guix time-machine -C channels.scm -- …`；重型构建设置 `--max-silent-time=7200`。

### 交付里程碑

| 里程碑 | 交付条件 | 主要不确定性 |
|---|---|---|
| M1：Codex 完整组合 | C1–C4 的源码产物、SDK、入口和运行资源进入最终安装闭包 | V8 host 的重型链接、SDK 与 CLI 的版本配套 |
| M2：Hermes 共同运行时 | 协议、SDK、网关、记忆、监控、音频和 SQLite 使用匹配的共同 Python 环境 | 原生音频依赖与 NumPy 兼容、动态插件的额外依赖 |
| M3：Hermes 全部 Linux 界面和浏览器 | TUI、Web、Electron、agent-browser 及浏览器/驱动从源码交付，资源与入口接入 | React/Next 嵌套工具链、Electron/浏览器的大型源码构建 |
| M4：范围收敛与最终交付 | 技能工具清单、模型和外部条件登记完成；四包配套说明齐全；每项都有安装闭包证据 | 插件生态可扩展，必须明确固定版本与审计范围 |
| M5：统一功能验收 | M1–M4 完成后，按详细计划集中执行用例并记录结果 | 凭据、设备、模型、内核或远程服务未就绪的用例单独保留 |

里程碑按实际依赖推进，不预估未经证实的完成日期。新增缺口继续归入对应编号；
源码不可得项和延期项须明确列入最终交付说明，不能通过缩小清单变成“已完成”。

每项分别记录：来源锁定、配方定义、独立产物构建、最终组合接入、功能验证。补全阶段只做必要的编译、元数据和安装布局检查，不提前执行 CLI/import、联网接口、浏览器、音频设备或网络路由功能测试。

统一验收覆盖 Codex code-mode/voice/zsh/SDK；Hermes 协议、界面、网关、音频、唤醒、浏览器、记忆及监控；sing-box 的已启用协议/TUN/DNS；dae 的 eBPF、路由、地理规则与服务生命周期。所需凭据、模型、设备、内核与远程服务先登记，由对应条件就绪后验收。

源码不可得的载荷、用户凭据、远程服务、平台外组件和延期项分别保留，不计作本轮已补齐。最终验收范围须明确这些例外。
