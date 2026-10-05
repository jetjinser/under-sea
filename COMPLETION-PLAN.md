# 四个包的组件补全计划

记录日期：2026-10-05。基线：sing-box 1.14.2、dae 2.1.1、Hermes
v2026.9.24（Python 0.21.5）、Codex 0.160.0，沿用 `channels.scm`。
本文件是待办计划，不代表组件已经补全或功能已经验证。

本次清单与计划整理不启动功能验证。先完成下述源码构建、资源安装和最终组合；
随后集中开展功能验收。技能与插件的动态依赖仍需审计，因此 26 个组件组覆盖
当前已识别范围，不宣称外部生态的全部传递依赖已经穷尽。

阅读顺序：[当前缺口摘要](#当前缺口摘要) → [逐项清单](#缺口清单) →
[实施顺序](#实施顺序) → [统一验证](#补全后的统一验证安排)。实施记录用于追溯，
不应替代当前状态判断。下方 C/H/S/D 共 26 项是组件或功能组，不是依赖包数量；
Python/Node 的传递依赖另见 `planning/` 清单和生成的来源锁。

本轮计划交付边界：先完成 Linux 可源码构建组件的包定义、固定输入、构建产物、
资源安装及最终运行时接入，再统一验证功能。闭源条件项、外部服务和延期项仍逐项
列出，不能将其悄悄删去后称为“全部完整”。

### 当前执行待办

| 对应项目 | 下一步交付 | 完成证据 |
|---|---|---|
| C1、C4 | 完成 V8/host、辅助程序及独立 TypeScript SDK，接入 Codex 完整组合 | 最新包定义实际构建成功；host、SDK、辅助入口和资源进入安装闭包 |
| C2、C3 | 将已有 voice host、补丁 zsh 接入最终组合并核对运行资源 | 最终组合构建及安装布局记录；独立组件成功不替代组合成功 |
| H1、H2、H6–H9、H13–H15 | 完成协议、SDK、网关及插件依赖组合，逐项收敛外部工具清单 | 来源锁、私有 Python 环境和各入口使用同一匹配运行时 |
| H3、H4、H17 | 完成 TUI/dashboard 后端与 SQLite/Python 接入，核对前端动态资源 | 最新组合产物、启动入口、静态及动态资源安装记录 |
| H5、H16 | 独立打包 Electron、浏览器/驱动和 agent-browser 等工具 | 从源码得到产物，使用固定资源路径，无首次运行下载二进制 |
| H10–H12 | 整合云/本地音频、采集、唤醒引擎与共享 NumPy；登记模型来源 | 完整音频运行时构建记录及模型配置边界；Porcupine 保留源码条件项 |
| D1、D2、S3 | 收尾已构建数据和已定义服务的配套说明 | 数据来源、许可、更新步骤、服务配置、状态路径和权限说明齐全 |
| S1、S2 | NaiveProxy、Tailscale 按此前约定留后续 | 后续独立交付源码闭包、启用 tag 和匹配资源；延期期间明确标为缺口 |

每项交付记录采用“来源已锁定 / 配方已定义 / 独立产物已构建 / 最终组合已接入 /
功能已验证”五个独立字段。构建期间只进行必要的编译、元数据与安装产物检查；
最后一个字段在统一验证阶段填写，不用 import 成功或文件存在替代功能验证。

## 当前缺口摘要

下表区分组件产物与最终包集成；后面的实施记录按时间追加，早期的“正在构建”
不能作为当前状态依据。所有新增功能的运行验证统一留到补全之后。

| 包 | 尚需补齐或集成 | 已有组件产物，但不能据此称为完整 |
|---|---|---|
| Codex | V8/code-mode host 与完整包集成；独立辅助程序的实际构建、TypeScript SDK | voice host、补丁 zsh、CLI 的组合已源码构建；V8 原生静态库已有成功构建记录，但正式 host、SDK 和最终组合仍需实际构建交付。 |
| Hermes | MCP/ACP 和 SDK 组合的最终运行时；TUI/Web/桌面入口与资源；消息、记忆、监控、语音、唤醒、浏览器及技能外部依赖 | SQLite/Python、Node 构建基础、TUI 和 Web 静态资源已有独立产物；CTranslate2、FlatBuffers、ONNX Runtime、TFLite、sherpa-onnx、pilk，以及浏览器使用的 libvips、Sharp、oxide 已有源码构建记录。完整音频运行时、dashboard 后端、浏览器及最终入口组合仍待完成。依赖来源锁不等于全部功能已接入。 |
| sing-box | NaiveProxy、Tailscale；可选服务配套的最终文档与验收 | 其他默认 tag 已构建；Shepherd 定义已写入。NaiveProxy/Tailscale 按先前约定延后。 |
| dae | 数据更新流程及服务配套的最终文档与统一验收 | 普通和 trace/eBPF、源码生成的 GeoIP/geosite 和组合数据包已有；Shepherd 定义支持包引用。尚未发现主动裁掉的核心运行组件。 |

优先完成共享 Python/Node 构建基础和 Codex host，再整合界面、SDK、音频与浏览器，
随后补网络数据和服务配套。源码不可得的组件、第三方服务凭据、模型资源和平台外项
分别登记；它们不能通过复制预编译载荷或安装 `all` extra 被视为已经补齐。

### 各项交付的共同要求

每个编号均须留下以下可复核结果，再进入统一功能验证：

1. **来源**：版本或提交、哈希、许可、传递依赖和模型/资源清单；标明源码不可得项。
2. **构建**：仓库包定义、离线构建输入及实际构建日志；预编译载荷须由对应源码产物替换。
3. **接入**：最终包入口、私有 Python/Node 环境、原生库和资源发现路径；避免首次运行下载程序。
4. **说明**：配置示例、所需凭据/设备/服务、可写目录和已知缺口；不在构建时修改用户配置。
5. **待验收**：登记功能用例及外部条件，补全后统一执行；在此之前状态保持“未验证”。

H16 的嵌套构建链单独跟踪：agent-browser 0.26.0 Rust CLI → Next 16.1.1
dashboard 静态导出 → 匹配 SWC、oxide、Lightning CSS、Sharp/libvips →
source-map、resvg、Yoga 三个 WASM 源码产物 → 源码浏览器及固定发现路径。
现有 Rust/Node 来源清单与独立原生 binding 不能替代这条完整链的交付。
H4 的动态前端资源和 H5 的 Electron 也分别登记，避免仅有静态页面便认为界面完整。

### 剩余工作的具体拆分

以下是后续执行清单；已有构建记录的组件只需完成尚缺的接入工作，不重复计作全新缺包。

| 顺序 | 尚待交付 | 前置条件和边界 |
|---|---|---|
| 1 | 收尾 Codex code-mode host、辅助入口和 TypeScript SDK，构建最终组合 | 复用已有 V8、voice host、补丁 zsh；独立 SDK 保留为可选包，核对其与完整 CLI 的配套关系。 |
| 2 | 收尾 Hermes integrations、audio、dashboard 的完整 Python 环境 | 共用匹配 Python/SQLite、NumPy、原生库和固定来源锁；将 MCP/ACP、网关、SDK、记忆和监控依赖接入实际入口。 |
| 3 | 完成 Hermes TUI/Web 的入口及全部前端资源 | 复用独立前端产物，补齐动态加载资源；最终界面使用包含所需协议及音频依赖的后端。 |
| 4 | 完成 agent-browser 的嵌套源码构建链 | 复用已构建的 Next SWC、source-map、resvg、Yoga、Satori、Vercel OG、ncc 和相应源码工具链；完成匹配版本的 SWC/Rspack、Sharp 运行依赖接入及 analyzer 的 Next 16.0.8 构建链，再交付完整 Next 16.1.1、dashboard 静态导出和 Rust CLI。独立原生组件成功不替代最终框架构建。 |
| 5 | 提供源码浏览器、驱动和其固定发现路径 | 分别审计 agent-browser、Camofox、browser-use、computer-use 的要求；不得依赖首次运行下载浏览器。 |
| 6 | 完成 Linux 桌面端 | 源码构建 Electron，接入共享前端、node-pty、资源与桌面入口；大型工具链独立维护。 |
| 7 | 收敛技能、插件、外部工具和模型清单，形成 Hermes 最终组合 | H14/H16 的外部生态尚未穷尽，继续逐项审计；凭据、远程服务、用户选择的模型分别登记，不能当成已打包程序。 |
| 8 | 收尾 dae/sing-box 配套说明，再统一功能验收 | 复用已有地理数据和服务定义；NaiveProxy、Tailscale 继续延期，不因本轮其他项目完成而改成已补全。 |

Porcupine 的原生引擎没有对应可用源码，保留为“无法按源码构建目标补齐”的条件项；
继续提供可源码构建的唤醒后端。功能验收前，只进行必要的编译、依赖元数据和
安装布局检查。所有实际 Guix 构建沿用固定 channel，并显式设置
`--max-silent-time=7200`，避免 LTO 或重型编译的长时间静默被误判为失败。

## 实施记录

H4源码组件已成功构建：固定vscode-oniguruma1.7.0及Oniguruma子模块
08d36110…，通过Emscripten从源码编出464590字节`onig.wasm`，安装双方许可和
来源/wasm SHA256，Guix输出
`/gnu/store/gy5za5k5agfc2hcmd1q2g6cpdaga385a-oniguruma-wasm-for-hermes-shiki-1.7.0`。
拆出独立`hermes-esbuild.scm`解除构建工具模块环，使Hermes Node/Web包可引用
浏览器WASM提供者；browser WASM对上游源码包的误引用已换成独立esbuild模块。
构建组装器现依据认证归档路径与原WASM哈希，将匹配源码产物写回Shiki 4.3.1及
Streamdown嵌套Shiki 3.23.0模块，并生成替换来源记录，Web/TUI安装配方都携带
此来源证据。Hermes Web完整源码组合handle62916实际exit0，安装到
`/gnu/store/qkb50zw2c5pfqf9mjvzhmh333s3zy98h-hermes-web-assets-0.21.5`；静态
资源包内的替换记录证实两个版本都使用源码WASM SHA256
`5d37ad50562c22946baddda2703bea6013084e29072ce7903050480aa9eba7de`，且记录保留
归档哈希和旧载荷哈希。TUI完整源码组合handle65464实际exit0，安装输出
`/gnu/store/rqjamly3d0avvfyrvjzw2zvzd4ymgz35-hermes-node-tui-0.21.5`；其私有接口
运行时与入口、来源替换receipt和许可均已安装。Web静态资源和TUI组合结果仍不替代
dashboard后端集成或统一功能验收。

本轮权威状态：React发布重试16477因Hooks缺少`@types/babel__core`失败；补入声明包
后，重试70034又因其传递类型闭包选用了不匹配的Babel 7.27而在严格类型检查失败。
现让`@types`依赖复用编译器工作区的Babel 7.26.3，并新增固定parser归档；Guix
dry-run通过。重试handle54585目前已完成主React、JSX runtime、React DOM及多个
发布渠道，仍在renderer/server余项；Hooks Babel类型修复要等该阶段重新运行后才
能确认，正式发布尚未完成。Codex V8 host handle25919仍活跃，Ninja最新可见
1563/2434；Hermes音频组合
76988已完成NumPy、PyAV、hf-xet、tokenizers、obstore源码wheel，当前构建SciPy
源码wheel。Hermes TUI handle65464实际exit0，`hermes-agent-interfaces`及
`hermes-node-tui`源码derivation均成功并经graft完成，输出
`/gnu/store/rqjamly3d0avvfyrvjzw2zvzd4ymgz35-hermes-node-tui-0.21.5`。其安装包含
`bin/hermes-tui`、入口bundle、双版本Shiki WASM源码替换receipt和许可；不代表
dashboard、完整音频后端或功能验收完成。

React正式发布重试中，组件作者bundle在Hooks阶段实际暴露Rollup TypeScript
插件的tslib peer预检。该可选peer不在React Yarn根图内；已引用仓库Rollup
4.34.9锁中同版本tslib 2.8.1固定源，作为明确补充根加入Hooks来源清单和Guix
archive路径，并刷新清单哈希。补充操作脚本
`scripts/add-react-typescript-tslib-peer.py` 已落盘；配方接入仍在构建核对。
此前遗漏的React recipe module import已显式补入。完整构建handle21529因此前
未导入锁表退出；修复后正式构建handle21529实际完成React/React DOM和多数
server/client release bundles，在Hooks插件阶段仍报缺少tslib。故障树显示源码包
真实路径位于`.sources`，解析时不会经过组装器直接根别名；已在模块真实路径的
`node_modules/tslib`添加补充peer实体别名，并更新组装器及peer审计hash。最新完整
正式重试handle16477已启动；已越过tslib解析阶段并产出大量release bundle，
仍未完成。功能验证延后。

Oniguruma autoconf重试揭示Guix隔离环境无`/bin/sh`：`emconfigure`曾将相对
configure视为不存在；改用Bash启动后已进入作者配置及Emscripten编译。配置脚本
内部仍调用环境变量`SHELL`，曾指向缺失的`/bin/sh`；构建helper现显式设置为包内
Bash，make也固定SHELL路径。随后交叉编译从Guix环境继承宿主机头文件搜索路径，
Emscripten标准库误读glibc头文件而失败；清理宿主搜索变量后已通过C编译器检查，
但Autoconf生成文件硬编码调用`/bin/sh ./config.sub`，又因chroot无该路径退出。
helper现把生成文本中的`/bin/sh`指向固定Bash输入；首轮改写被只读源权限拒绝，
随后已修复权限并成功构建完整Oniguruma静态库。Emscripten正确产物为`.a`，已
改用该静态库。handle92318完成库构建及WASM链接调用，但最后作者`remove-print.js`
步骤因配方漏列Node退出；Node已加入固定构建输入，正式重试handle1105实际exit0，
WASM已从源码构建并安装，产物为
`/gnu/store/gy5za5k5agfc2hcmd1q2g6cpdaga385a-oniguruma-wasm-for-hermes-shiki-1.7.0`，
SHA256 `5d37ad50562c22946baddda2703bea6013084e29072ce7903050480aa9eba7de`；包含双方
许可与来源记录。其被Web资源组合引用并生成替换记录，尚待TUI组合结束；功能验收延后。

Hermes音频正式组合的上次源码构建经5740秒后失败：SentencePiece sdist确实
包含1668个Abseil文件，但CMake仍尝试clone tag 20260526.0。`build-hermes.py`
现以精确源代码块校验并跳过该在线FetchContent，使用已锁定sdist中的完整
Abseil子目录。脚本AST检查通过，固定归档内替换锚点恰好匹配一次；最新正式
音频组合重试handle76988已启动。尚待构建成功；功能验证延后。

Oniguruma正式构建15963因PATH缺Python失败，补入python-minimal后已进入
作者autogen；配置生成器遗漏configure产物，且Emscripten默认缓存原先指向
不可写/home。构建helper将缓存固定到构建树，校验configure缺失时由已锁定
Autoconf补生成；重试启动，日志
`/tmp/hermes-shiki-oniguruma-autoconf-source-build.log`。

新增固定源码包 `oniguruma-source-for-hermes-shiki` 与正式
`oniguruma-wasm-for-hermes-shiki` 配方，分别固定vscode-oniguruma1.7.0
与精确子模块commit08d36110…；哈希已认证，固定channel闭包解析通过。
正式源码构建15963已启动，日志
`/tmp/hermes-shiki-oniguruma-source-build.log`；当前Guix先构建其源码
Emscripten依赖闭包。构建脚本使用作者autogen、
emconfigure/emmake、上游build.sh的Emscripten参数、remove-print整理，
安装WASM、双方许可和来源/hash证据。配方固定channel闭包解析已启动，
日志 `/tmp/hermes-shiki-oniguruma-formal-evaluation.log`；源码WASM实际
构建和接入Hermes bundler仍待完成。功能验证延后。

Shiki4.3.1官方源归档已获取并记录SHA256
91624dab25d5745e76c413df7c8f643ad0a7d100905272a59752665c4fffe9ec。
作者engine-oniguruma明确使用vscode-oniguruma1.7.0；该官方源SHA256
0e472a9d670d3301024435c04c09870bce2779c22a099185c2988d99b1cea190。
确认WASM来自vscode-oniguruma/release/onig.wasm，作者Rollup插件仅将
源码构建WASM编码入wasm-inlined入口；对应C/C++构建脚本与Oniguruma
子模块元数据已核对，固定release Git树已取得，后续锁准确子模块提交。
这仅是源码发现，未声称引擎或前端已补齐；功能验证延后。

两个归档审核器现识别JS/MJS/CJS中的quoted base64 WebAssembly v1载荷。
Hermes locker将此归档归入源码替换需求；通用Node归档审计记录其实际
JS资源路径，组装器因此要求完整源码provider。对两份已认证Shiki
归档静态回归检查实际通过，每份准确识别一个内嵌WASM；脚本语法解析
通过。原有来源锁仍需在源码provider完成后更新，未声称已替换载荷。
React最新47392本轮原handle确认运行，功能验证继续延后。

H4实际归档静态审计确认@shikijs/engine-oniguruma 4.3.1和3.23.0均有
wasm-inlined.mjs内base64 WASM，现有只检查.wasm/文件头的来源审核未
覆盖这种载荷。已核对归档固定hash，解码验证WASM头并保存payload hash，
证据 `planning/hermes-shiki-inline-wasm-audit.json`。这些前端原生资源
明确仍须源码替换，不能将现有Web静态构建认定为全源码完整交付。
本轮47392/2024/25919/49843/14482/69441原handle全部确认活跃。
功能验证继续延后。

Hooks类型认证44460实际exit0（368包），44条peer绑定通过，生成361项
固定origins并接入最新正式配方；认证缓存导入54810实际exit0。
旧手动release8363实际exit1，已完成大部分runtime/RSC/scheduler/jest
编译，最后Hooks阶段因@tsconfig/strictest缺失失败；新图已包含该输入。
最新正式重试启动，日志
`/tmp/hermes-react-release-hooks-types-formal-source-build.log`；保留完整
类型任务、双锁、作者源码和安装资源，尚待实际成功。功能验证延后。

Hooks固定源码缓存导入38499实际exit0；最新双锁正式构建69441启动，
日志 `/tmp/hermes-react-release-dual-lock-formal-source-build.log`。
继续核对Hooks tsconfig发现明确types=estree-jsx,node及root typeRoots，
新增作者devDependencies全部@types根，不删除作者类型构建要求。
扩展清单已生成，认证启动，日志
`/tmp/hermes-react-release-hooks-types-archive-audit.log`。仍需将扩展类型
图接入最新正式配方；旧8363/14482/49843本轮原handle确认运行。
功能验证继续延后。

React正式配方已接入Hooks根来源锁及独立Compiler来源锁、准确peer审计
与源码Rollup4/esbuild/source-map providers。Compiler图组装复用已成功
正式Compiler配方的原始闭包，不替换作者源码prebuild；release helper
接入源码workspace和独立模块路径，并避免将构建模块缓存复制为源码。
最新双锁正式配方解析启动，日志
`/tmp/hermes-react-release-dual-lock-evaluation.log`，仍需实际正式构建。
功能验证继续延后。

最新Hooks根图组装94810实际exit0（359 Linux位置），独立Compiler模块
142位置已接入新的完整release stage。新版14482启动，原因是新增作者
渠道所需依赖输入，不因旧构建观察超时重启；旧8363/49843仍确认活跃。
新版日志 `/tmp/hermes-react-hooks-compiler-source-release-build.log`。
生成356项正式Hooks根来源锁 `hermes-react-release-hooks-node-lock.scm`；
最新双锁组合的正式Guix配方接入仍待完成。功能验证延后。

Hooks认证94470实际exit0（363归档），准确peer元数据审计44绑定通过。
Compiler独立config来源图已使用正式Rollup4 provider重新组装，保留其
原compiler锁及peer审计。release helper新增独立 --compiler-modules
参数，校验作者compiler锁和无install scripts证据后接入compiler源码
目录模块环境，不替换作者prebuild或源编译。最新完整组合仍待运行；
正式React运行snapshot仍为旧360图。功能验证继续延后。

扩展全图解析再次拒绝 compiler 的 fbt selector，因为其依赖归独立
compiler/yarn.lock管理，不能硬塞根锁或随意替换版本。改为分别维护
根发布/Hooks图与既有Compiler来源图，保留源码编译所需两套作者锁。
Hooks根图已实际生成，归档认证启动，日志
`/tmp/hermes-react-release-hooks-archive-audit.log`；Compiler源码模块布局
仍待接入release stage。原8363确认运行，尚无完整发布成功。
功能验证延后。

React作者完整渠道包含eslint-plugin-react-hooks的TypeScript构建，并通过
prebuild直接引用compiler源码。新增TS/TSX及静态import扫描；扩展图初次
解析发现compiler测试React版本不在根yarn.lock，不能将其作为发布输入。
扫描器现排除明确测试源码并识别作者packages/*工作区导入，避免把源码
React误作registry预编译包；扩展图尚需重新生成和认证，现有运行构建
未改变。手动release8363本轮确认活跃，已推进RSC parcel任务；功能验证延后。

新增 `map-next-react-source-providers.py`，按既有Next准确别名要求映射
canary/experimental源码发布目录，逐项核对manifest版本、安装证据和
全部包文件hash，生成实际包identity provider图。已核对作者copy_vendor_react
保留JSON/JS/CJS/maps/LICENSE及其原始别名重写行为，不替换该任务。
helper语法解析通过，实际映射仍待完整React发布安装成功。
手动release8363本轮原handle确认活跃。功能验证继续延后。

本轮原handle49843/8363/2024/25919全部确认运行；正式React在server
入口，手动React在RSC webpack edge入口，音频在grpcio源码编译，Codex
重试在锁定Rust依赖编译。没有观察到新的终止结果，未重启这些构建。
React staging helper排除规则改为只作用源码根的构建输出，保留作者
子目录中同名源码目录；Python语法解析通过。当前已运行的正式snapshot
仍使用旧helper，后续最终交付须使用最新配方实际构建记录。功能验证延后。

React正式Guix构建49843已启动并确认运行，356 Linux模块组装成功，
进入react.development.js编译；日志
`/tmp/hermes-react-release-formal-source-build.log`。手动完整release8363
本轮原handle确认活跃，已推进RSC webpack/server任务，仍无整体成功。
Next16.0.8隔离stage39973实际exit0，匹配SWC及完全相同来源锁的错误码
插件接入；证据 `planning/hermes-next-1608-source-native-stage-artifacts.json`。
两个Next版本尚待完整framework构建，不以stage接入认定完成。
功能验证继续延后。

新增 `react-release-for-hermes-next` 正式Guix配方，固定React源码、353
registry origins及Rollup/Closure源码providers；完整peer布局、作者全
渠道编译及完整发布安装进入配方。helper支持store独立metadata脚本，
并排除build阶段位于source内部的stage/modules，避免递归复制。
正式配方闭包解析已启动，日志 `/tmp/hermes-react-release-formal-evaluation.log`。
实际正式构建仍待启动并成功，不以定义代替交付；功能验证延后。

新增 React 完整release安装helper，要求作者全渠道构建完成标记，核对
canary/experimental/semver三个渠道的React、React DOM、scheduler及两种
RSC包准确版本、CJS源码编译产物和许可，复制整个build资源目录并记录
全部文件hash，不只挑选Next眼前使用的入口。实际安装尚待8363完成；
本轮原handle确认活跃，ReactDOM内部prod/profiling等任务仍在编译。
功能验证继续延后。

React短名称图认证34220实际exit0，44条完整peer绑定通过；组装11549
实际exit0（356 Linux/glibc位置）。作者完整release构建8363已启动，
本轮原handle确认运行，react开发/生产、内部渠道、server/jsx及react-dom
部分产物已实际生成，仍待全部渠道成功；日志
`/tmp/hermes-react-babel-short-source-release-build.log`。
生成正式 `hermes-react-release-node-lock.scm`，353固定源码origins，
Rollup/Closure源码providers及已明确的Java构建路径另行输入；已启动
哈希复核缓存导入，日志 `/tmp/hermes-react-release-source-import.log`。
正式React包定义与安装仍待完成，未执行目标功能验证。

React认证56603实际exit0（359归档），完整peer审计44绑定通过，最新
组装97414实际exit0（355 Linux位置）。发布75581实际exit1，已越过
@babel插件加载，失败于短名称 syntax-trailing-function-commas 的
babel-plugin前缀解析。扫描器现仅在作者manifest明确声明对应包时
纳入短名称plugin/preset，最新图49根360包；新增认证34220启动，日志
`/tmp/hermes-react-babel-short-name-archive-audit.log`。旧peer证据不代替
最新360包图，需要重新核对和组装；功能验证延后。

Next16.1.1源码隔离stage31909实际exit0，匹配SWC及源码WASI错误码插件
接入作者路径；核对源码Cargo.lock/manifest/lib.rs、原发布WASM身份、
source plugin锁、WASM/ELF头与产物hash，证据
`planning/hermes-next-1611-source-native-stage-artifacts.json`。
目录 `/tmp/under-sea-next-1611-source-native-stage`，仍待完整framework
源码构建。插件原始来源三项hash与16.0.8完全一致，可复用于对应链。
React新归档56603本轮原handle确认运行，尚无认证完成输出。功能验证延后。

Codex11195实际exit1：V8源编译之后，rusty_v8 bindings使用继承的
LIBCLANG_PATH/Clang15，无法解析当前bundled libc++（要求Clang21+）。
host build阶段现明确固定到已有matching Clang23/lib，不改变V8来源
或功能范围。正式SDK/完整CLI/host组合重试25919启动，日志
`/tmp/codex-sdk-v8-libclang23-source-build.log`。
Next插件1784随后实际exit0，正式输出
`bnc8sxw22rl0i96f6fswc8xr84r59mmz-next-error-code-plugin-for-hermes-16.1.1`，
原始WASI目标、release和LTO保留；尚需Next消费者接入。
React Babel认证56603、音频2024本轮原handle确认活跃。
功能验证继续延后。

Babel配置字符串扫描已加入来源清单生成器，React工具图现为48根、359
锁定包。沙箱内新增归档下载代理不可达，改为授权联网、独立缓存及
输出文件继续认证，handle56603，日志
`/tmp/hermes-react-babel-complete-archive-audit.log`。此前29条peer结果只
覆盖旧归档清单，不能证明最新图完整；审计器已增加缺失归档直接失败
的检查，待新归档认证完成后重新生成全部peer证据。功能验证延后。

最新 React 来源图组装73283实际exit0，327 Linux/glibc位置，目录
`/tmp/under-sea-react-complete-java-build-node-modules`。新增完整作者release
构建helper，固定source lock和源码元数据，保留所有渠道任务。
首次2248因helper找不到PATH中的python失败，改为sys.executable；19803
进入作者构建但缺少Yarn workspace源码链接。helper按原manifest的
packages/*建立隔离源码链接，拒绝与registry包冲突，重试10436已启动，
日志 `/tmp/hermes-react-complete-workspace-source-release-build.log`。10436
随后实际exit1：已进入react.development.js的Babel编译，缺少字符串配置
引用的 @babel/plugin-proposal-class-properties，需扩展配置依赖扫描。
尚无React完整release成功产物；功能验证继续延后。

React Java 构建路径源码 providers 已登记，首次组装40626实际exit0，
322 Linux/glibc位置，目录 `/tmp/under-sea-react-java-build-node-modules`。
保留 Closure 原始 Node API，准确 Java launcher 与完整 Rollup3 provider；
可选 Linux native accelerator 仅在作者明确调用 Java 的这条构建路径
登记替代条件，其独立源码交付仍未完成。继续审查作者release入口发现
未声明fs-extra根；按 scripts/release/package.json 的 ^4.0.2 与原锁
新增精确selector，完整来源图与peer证据已重新生成。首个组装目录属于
旧图，不用作最新完整工具链。功能验证继续延后。

Next 错误码插件22103实际exit1，完整锁定依赖编译已完成，最终源码
六处 `rcstr!` 宏在独立锁定的 SWC 中不存在。核对 swc_ecma_ast 9.0.0
的 Atom/IdentName From<&str> 实现后，新增源码 SHA256 守卫的修正脚本，
仅将六处字符串构造改为类型推断的 `.into()`，保留所有错误码转换逻辑。
正式重试1784已启动，日志 `/tmp/hermes-next-error-plugin-swc-string-build.log`。
音频2024、Codex11195本轮原handle仍活跃。React closure-plugin 作者源码
确认直接实例化 Java Compiler API；可选 native provider 仍独立登记，
不以 Java 接口接入替代其源码交付。功能验证继续延后。

React 根构建图 peer 审计实际发现 TypeScript 与 Babel core 未明确纳入
工具根。按作者 manifest 和原始 yarn.lock 新增两个根，完整图现为34根、
326认证归档；清单 `planning/hermes-react-build-complete-node-inventory.json`
及对应 archives。审计器增加直接消费者的唯一、满足范围的 peer 选择，
用于 update-browserslist-db 的 browserslist 父依赖；多候选仍拒绝猜测。
实际元数据审计exit0，验证29条peer绑定，证据为同前缀
`peer-bindings.json` 与 `peer-audit.json`。五个native载荷仍须逐项处理，
React完整provider组装及正式构建尚未完成；功能验证继续延后。

Closure 父 Node API `closure-node-for-hermes-react` 正式构建45093实际
exit0；保留作者接口及依赖/optional metadata，默认 Java 路径固定到
源码 provider，并安装对应 Java provider 的模块链接。普通 JS 依赖仍
须由 React 消费者来源图接入，可选 Linux 原生加速器也仍待单独补齐。
日志 `/tmp/hermes-react-closure-node-formal-build.log`。
修正 WASI sysroot74478实际exit0，输出
`mfv3cws8zm30svjda0svxcb0ckyd7hsy-rust-sysroot-wasip1-for-hermes-next-1.93.0`。
已启动使用最新 sysroot 的 Next 错误处理插件构建22103，保留原始
LTO；日志 `/tmp/hermes-next-error-plugin-corrected-wasi-build.log`。
音频2024、Codex11195本轮原handle确认仍运行。功能验证继续延后。

新增正式 `closure-java-node-for-hermes-react` Guix 包，固定 npm 包版本
20230206.0.0 及 SHA256，使用源码 Closure 20230206 的完整运行时闭包。
构建脚本丢弃 registry 中的二进制 compiler.jar，保留作者 Node 接口，
生成仅含 manifest 的确定性 launcher jar。正式构建 handle 51234 实际
exit0，日志 `/tmp/hermes-react-closure-java-node-formal-build.log`。
父 google-closure-compiler Node API 的固定 Java 路径和 React 最终工具链
仍待接入；本次没有执行 Java/Node 目标功能验证。

Rollup3构建76474实际exit1因source origin下载故障，112认证registry归档及
同hash官方源已导入store，原source output身份保留。正式重试启动，日志
`/tmp/hermes-rollup3-cached-formal-source-build.log`。
新增 Closure Java Node provider helper，保留作者index/manifest/docs/license，
registry compiler.jar替换成确定性classless launcher jar，Main-Class和
完整Class-Path引用已源码构建Closure/JVM库。实际helper exit0，manifest
折行重组与全部固定资源路径元数据核对通过，证据
`planning/hermes-react-closure-java-node-artifacts.json`。未运行Java/Node
目标功能，父Node API固定Java路径与正式Guix配方继续待接入。
React主图Java审计原缓存选择不当导致重复下载，已改用实际既有cache
独立重审输出 `hermes-react-build-node-java-cached-archives.json`，不覆盖
仍活跃的原审计输出。功能验证继续延后。


本轮音频2024原handle确认活跃。完整Rollup3.29.5正式Guix配方已加入
并启动，日志 `/tmp/hermes-rollup3-full-formal-source-build.log`，尚待产物。
核对Closure Node接口发现其默认Java调用使用-jar，而源码Closure输出为
完整classpath wrapper；接入须提供保留作者Node API的Java launcher jar
及固定Java路径，不能直接放入无Main-Class的compiler jar。归档审计器
新增.jar/.class载荷识别，React主图重新认证启动，日志
`/tmp/hermes-react-build-node-java-audit.log`，后续用源码Java产物替换registry jar。
功能验证继续延后。


Rollup3 bootstrap8995实际exit0，正式输出
`wx2qjk8c7gz6ck1sn41ysyz9gkclvxcz-rollup3-bootstrap-for-hermes-react-3.29.2`。
新增完整 `rollup3-for-hermes-react` Guix配方，112固定origins、准确bootstrap
及源码esbuild，保留全部CJS/ESM/CLI/types/browser发布构建及许可安装；
正式构建启动，日志 `/tmp/hermes-rollup3-full-formal-source-build.log`。
音频2024本轮原handle实际确认活跃。React整体仍待构建，功能验证延后。


新增完整Rollup3发布安装helper，实际23456 exit0，重新运行原始全部
发布任务并检查Node/browser接口、类型、资源，安装完整provider。
证据见 `planning/hermes-react-rollup3-full-install-artifacts.json`。官方
3.29.5 tag内browser manifest仍标3.29.4，按作者源码保留，不冒称其
manifest身份已为3.29.5。生成112正式固定origin，并新增准确3.29.2
bootstrap Guix配方，正式构建启动，日志
`/tmp/hermes-rollup3-bootstrap-formal-build.log`。完整3.29.5 Guix配方仍待
接入。音频shell修正重试已启动，日志
`/tmp/hermes-audio-sentencepiece-shell-source-build.log`。功能验证延后。


sentencepiece问题进一步核对固定sdist后修正判断：build_bundled.sh实际
存在，ENOENT由其/bin/sh解释器在Guix沙箱不存在造成。归档已确认包含
完整sentencepiece/src/CMakeLists.txt。build helper仅将该脚本shebang改为
固定可用shell，并要求完整bundled core，避免触发联网clone分支；仍使用
原始版本源码与构建选项。正式音频组合需按修正后的helper重新构建。


Rollup3.29.5浏览器补全图35根/138 npm位置，归档24441实际exit0，组装
116 Linux位置成功。完整作者发布构建14475实际exit0，CJS/ESM/CLI/类型
及两个browser产物已生成，所有hash见
`planning/hermes-react-rollup-3295-release-artifacts.json`。仍需正式Guix
安装与React工具链接入，未执行生成产物的功能测试。
Codex11195本轮原handle确认活跃；audio35598实际exit1，已越过SciPy、
scikit-learn及openWakeWord，sentencepiece0.2.2构建缺少build_bundled.sh。
下一步核对该版本源布局并补齐准确构建输入，不用不匹配系统版本替代。


缓存导入95个hash认证源码实际exit0，失败@types/node归档获得相同Guix
store path。正式重试6372实际exit0，Rollup4.34.9输出sp939g...，React
Compiler输出7m0qxl...，完整固定源码Guix组件已交付，React/Next接入仍待完成。
esbuild0.18.20正式44886实际exit0，Node API输出4yk98...、Go/platformq6kak...。

Rollup3.29.5准确源码providers组装114 Linux位置成功，完整author build41987
实际exit1：Node CJS/ESM已生成，浏览器入口缺少hash.js根依赖。新增明确
--include-browser扫描作者browser/src，引入完整浏览器依赖清单，peer
元数据审计通过，归档认证启动，日志
`/tmp/hermes-react-rollup-3295-browser-archive-audit.log`。未关闭browser任务
或warning gate，完整release仍待成功，功能验证延后。


Closure22298实际exit0，正式grafted输出
`xz50slbrvyiw02i9a1x1ylqd654m0ivw-closure-compiler-for-hermes-react-20230206`，
完整Java、协议和typed AST及runtime资源源码构建交付；仍需React工具链接入。
Rollup3.29.5首次组合因@esbuild/linux-x64@0.18.20缺少源码provider失败，
后续CLI未成功启动。官方esbuild0.18.20源码已下载exit0并核对其x/sys
仍为c0bba94，与现有固定输入吻合。新增Go/platform和完整Node API正式
配方，构建启动，日志 `/tmp/hermes-rollup3-esbuild-source-build.log`。
尚未完成Rollup3完整release，功能验证保持延后。


Closure1695实际exit1，但完整Java编译和typed AST生成已越过；安装时旧版
runtime_type_check.js引用失败，该文件在20230206源中不存在。helper按版本
保留旧版资源要求，新版安装全部其实际JS与polyfills资源；正式重试启动，
日志 `/tmp/hermes-react-closure-runtime-resources-build.log`。不是删除新版
现有组件，完整产物仍待该构建成功，功能验证延后。


Rollup3.29.2 bootstrap 自身 runtime 图17根/36 npm位置已认证，2个peer
范围通过，实际组装35 Linux位置。helper严格允许已审计3.29.2分支，无
native/parseAst，保留上游三个API和CLI及类型声明。四入口实际编译exit0，
并从自身lock核对inlined import-only源码，完整hash见
`planning/hermes-react-rollup-3292-bootstrap-artifacts.json`。仍需将该准确
bootstrap接入3.29.5 authored full build，未执行目标功能验证。


Closure67225实际exit1：新版作者将版本字段移至独立
CommandLineRunnerVersion.template，而非旧CommandLineRunner内联token。
helper按20230206生成对应Java类，保留作者引号，旧版本逻辑不变；正式
重试启动，日志 `/tmp/hermes-react-closure-version-template-build.log`。
Rollup3.29.5归档认证50611实际exit0（113 Linux archives），锁bootstrap为
准确3.29.2，已下载对应官方源码35859实际exit0，后续源码编译接入。
功能验证未开始。


Gson JDK11正式3662实际exit0，完整模块声明保留。Closure67225原handle
本轮确认仍活跃。Rollup3.29.5官方源完整安全解包后，按其 authored config、
build-plugins、src/cli与声明包生成 34 根/136 npm 安装位置；14个 peer
semver元数据约束全部通过，证据前缀 `hermes-react-rollup-3295-`。
归档认证已启动，日志 `/tmp/hermes-react-rollup-3295-archive-audit.log`。
该版本只有三个Node API入口，无4.x parseAst/native，不沿用错误布局；
实际JS构建与完整release仍待完成，目标功能验证保持延后。


jspecify JDK11正式产物已成功（zd3ki4...）。Gson82067实际exit1，完整
module-info同样需JDK11，已保留模块声明重试，日志
`/tmp/hermes-react-gson-jdk11-source-build.log`。protobuf49421实际handle仍活跃。
Closure20230206作者协议清单和typedast.bzl参数核对与现有完整helper一致，
helper增加准确compiler-version参数，默认旧版本保留。新增正式
`closure-compiler-for-hermes-react`，匹配新Gson/protobuf/注解，并复用准确
Guava/AutoValue源产物；构建启动，日志 `/tmp/hermes-react-closure-source-build.log`。
编译中的typed AST生成属于作者构建资源生成，未进行功能验证。


注解组合8131实际exit1：error-prone2.15.0已成功，jspecify默认JDK无法
编译完整module-info.java。保留模块源码，改用JDK11正式重试。新增准确
protobuf3.21.12的源码protoc/C++及Java运行时配方，同一source/protoc生成
完整well-known protocols，组合构建启动，日志
`/tmp/hermes-react-protobuf-jspecify-source-build.log`。
Gson2.9.1官方源码已下载并固定hash，新增完整Java配方及作者版本模板生成，
构建启动，日志 `/tmp/hermes-react-gson-source-build.log`。Closure总包仍待
构建和接入；所有目标功能验证继续延后。


Closure 固定 bazel-common zip 已实际下载并验证作者 SHA256 bcb5de...，
完整 Maven 声明见 `planning/hermes-react-closure-common-dependencies.json`。
Guava31.0.1/failureaccess1.0.1/AutoValue1.6 与已有输入一致；Gson2.9.1、
protobuf3.21.12、jspecify0.2.0/error-prone2.15.0仍须新源码输入。
后两者 Maven sources 归档已检查无.class，并新增正式匹配 Guix 包，
构建启动，日志 `/tmp/hermes-react-java-annotations-source-build.log`。
未宣称 Closure 整体完成；正式 Compiler49036与Rollup21294原handle仍活跃。


Closure20230206 使用 WORKSPACE.bazel，而非最初查找的 pom.xml/WORKSPACE。
已从认证源码归档读取准确文件并登记作者 Maven 声明和 protobuf3.21.12，
见 `planning/hermes-react-closure-20230206-dependencies.json`；依赖输入、
测试/运行分类与源码 Java providers仍待落实，不沿用旧版依赖后称匹配。


本轮原handle确认正式 Compiler49036与Rollup21294仍在运行。审计 React
主构建准确需要 Rollup3.29.5、Closure20230206，与 Compiler 私有环境不同。
两个官方源码归档已实际下载 exit0，版本/build metadata 与 SHA256见
`planning/hermes-react-root-tool-sources.json`。下一步按对应作者输入补齐
工具链，不用已有4.x Rollup或20220502 Closure冒充。此阶段未执行目标功能。


新增 `patch-react-source-metadata.py`，限定已审计的源脚本 SHA256，只将
归档中不可用的 git 查询替换为匹配 canary 的固定 commit52684925/date20251110，
保留全部双通道编译、版本替换和命令选项。对独立源码副本实际处理 exit0，
原/后脚本 hash 与范围见 `planning/hermes-react-release-metadata-patch.json`。
此为构建前源码转换，未执行 React 产物功能；完整 React 构建仍待开始。


新增正式 `react-compiler-for-hermes-next` Guix 配方，固定 React commit 与
完整来源 hash，135 registry origins，源码 Rollup/esbuild/source-map WASM
providers，4 个 semver peer 证据，以及 authored tsup/tsconfig 与安装
helper。正式构建启动，日志 `/tmp/hermes-react-compiler-formal-source-build.log`，
源归档已由 Guix 验证并下载，最终编译产物尚待完成。
Rollup21294、Codex11195、audio35598本轮原 handle 实际确认仍活跃。
React rollup 脚本读取 Git 元数据的两处都位于 build-all-release-channels.js，
后续只替换这段元数据读取为固定 archive 对应 commit/date，保留双通道任务。
未执行 Compiler 或任何新目标功能验证。


正式 Rollup bootstrap68657实际 exit0，Guix 输出
`zwymv03ns94s1didzlywc832fm4vcc59-rollup-bootstrap-for-hermes-react-4.34.8`。
新增 `rollup-node-for-hermes-react-compiler`，95 固定 registry origins、
source bootstrap、匹配双 native、源码 esbuild API，完整 authored Node
编译与安装 helper 正式接入；构建启动，日志
`/tmp/hermes-rollup-node-formal-source-build.log`，未宣称最终产物完成。

React Compiler 生成正式 registry origins；首次176项包含非 Linux 原生
归档，生成器补按已认证 os/cpu/libc 过滤，当前135固定源输入，保留所需
Linux/glibc provider。新增 `build-react-compiler-source.py` 验证 lock/layout，
保留上游配置、构建全部 entry 并安装许可资源；实际 helper 构建成功，日志
`/tmp/hermes-react-compiler-helper-build.log`。Guix Compiler 配方仍待接入。
WASI74478与旧 error-plugin45927原handle本轮确认活跃，功能验证延后。


新增正式 `rollup-bootstrap-for-hermes-react` Guix 配方，来源为准确4.34.8
源码与 native，ESM 内联依赖使用固定 origins 与 store 归档路径；正式
构建已启动，日志 `/tmp/hermes-rollup-bootstrap-formal-source-build.log`。
尚不以启动构建宣称产物完成，最终 authored Node Guix 配方继续待接入。


React Compiler 补齐 authored @tsconfig/strictest，13 根/185 Yarn 包归档
认证和 4 个 peer 审计实际成功，组装 142 个 Linux/glibc 位置。保留
上游 tsup.config.ts 与 tsconfig.json 后，实际 CJS 编译 exit0，生成
3,731,601 字节 dist/index.js。已安装源码 manifest、README 和 MIT license，
证据见 `planning/hermes-react-compiler-source-artifacts.json`；未执行生成的
Compiler 功能。正式 Guix Compiler 配方与 React 发布通道接入仍待完成。

开始将已成功的 Rollup Node pipeline 变成正式固定输入：生成
`hermes-react-rollup-node-lock.scm`，并为 bootstrap helper 增加 store 归档
路径参数，保留原 integrity/hash 检查，避免正式沙箱依赖 /tmp 审计缓存。
React 双通道源码任务需要准确 commit/date，后续使用固定源码元数据参数，
不能伪造 Git 仓库或使用错误版本字符串。功能验证仍延后统一进行。


React Compiler 按实际 src/index.ts 闭包生成 12 根/184 Yarn 包清单并认证归档，
证据前缀 `hermes-react-compiler-entry-`。新增 metadata-only semver Yarn peer
审计，实际核对 4 个绑定；组装器按 lock/清单/归档/bindings 哈希及每条
约束证据接入，不放宽原有默认范围检查。source-map 0.8.0-beta.0 接入已有
源码 WASM provider。归档审计补记录作者 os/cpu/libc，组装时使用这些声明
排除 macOS fsevents，保留 Linux 原生依赖。最终实际组装成功 141 个
Linux/glibc 位置，位于 `/tmp/under-sea-react-compiler-platform-modules`。

实际启动上游 tsup 编译，exit1，配置 extends 所需包缺失；日志
`/tmp/hermes-react-compiler-entry-source-build.log`。下一步补齐作者 tsconfig
所声明的配置依赖并重试，不删除 extends 或削弱构建配置。目标功能验证
未开始，完整 React/Next 链仍待完成。


Rollup 4.34.9 authored Node release 本轮实际 exit0，完整生成 CJS、ESM、CLI、
四个公开 API 的类型声明及 sourcemaps。新增 `build-rollup-source-node.py`，
验证源码版本、npm lock、认证模块布局、准确 native metadata 与 Cargo.lock，
保留上游编译和类型检查；SOURCE_DATE_EPOCH 固定，按原逻辑允许归档 Git
提交元数据为 unknown。最终 helper 实际 exit0，输出
`/tmp/under-sea-rollup-4349-locked-node-provider`，已接入源构建 native。
所有安装文件哈希见 `planning/hermes-react-rollup-node-release-artifacts.json`。
这是 React Compiler 所需的 authored Node provider；正式 Guix JS 配方、
browser/WASM release 和 React/Next 整体仍待完成，未执行目标功能测试。
WASI74478通过原 handle 实际确认仍活跃。


类型依赖认证实际 exit0，100 个 Linux archives。补入 tslib 与运行依赖中的
@types/estree 根链接后，32 根/143 锁定位置、16 个 peer 审计及 100 个
Linux 安装位置全部成功，证据前缀 `hermes-react-rollup-all-types-`。
实际编译越过类型检查，随后 picocolors 的 CommonJS export 转换失败；
原因是依赖真实路径位于源码外，不匹配上游 `node_modules/**` include。
保留原插件配置，将完整认证模块图直接组装到源码内 node_modules，exit0，
重试构建已启动，日志 `/tmp/hermes-rollup-4349-local-layout-build.log`。
本轮实际原 handle 确认音频35598与Codex11195仍在运行，功能验证未开始。


bootstrap 内联 import-only 的 locate-character/is-reference 作者源码，逐项
核对 4.34.8 lock integrity、归档 SHA256 与实际源文件字节，五个入口实际
编译成功。重试 authored Node release 后，原 ESM 加载问题已越过，出现
bootstrap 缺少声明；按上游 copy-types 逻辑加入四份源码声明与 types
exports，重新编译及 97 个 Linux 位置组装实际 exit0。证据见
`planning/hermes-react-rollup-bootstrap-typed-artifacts.json`。

后续编译实际 exit1，发现缺少 authored `@types/yargs-parser`。清单器现
补入上游声明的 @types 根依赖；新版锁清单见
`planning/hermes-react-rollup-typed-node-inventory.json`，归档认证启动，日志
`/tmp/hermes-react-rollup-typed-archives.log`。未放宽 TypeScript 检查，未
用假声明或 registry 编译产物替代；正式 release 尚未成功，功能验证延后。


Rollup 正式构建输入扩展至源码 src/cli 中声明的直接依赖，新增逐文件引用
证据；`hermes-react-rollup-release-node-inventory.json` 实际生成 27 个根依赖、
140 个锁定位置。归档认证实际 exit0；semver 元数据审计 16 个 peer 绑定
全部通过。源码 providers 接入后组装实际 exit0，得到 97 个 Linux/glibc
安装位置，位于 `/tmp/under-sea-rollup-release-modules`。没有执行 install 脚本。

实际启动 authored Node release 编译，exit1：私有 CJS bootstrap 的外部
`locate-character` 只有 ESM export，不能由 require 加载。日志见
`/tmp/hermes-rollup-4349-authored-node-build.log`。下一步须调整 bootstrap
的源码打包方式并保留匹配依赖身份，不能复制 registry 的已编译 Rollup。
两份 lock 对比还发现 Rollup/esbuild/vite/license 插件等版本不同，不能
把整个 4.34.9 环境声明为 4.34.8 的相同依赖闭包。WASI 和 error-plugin
构建通过原 handle 确认仍活跃；未提前进行功能验证。


新增 `esbuild-node-for-hermes-react-compiler`，保留完整官方源码，执行上游
`scripts/esbuild.js --neutral`，使用匹配的源码构建 Go 编译器生成 Node API、
installer、shim 和类型声明。直接源码编译实际 exit0；正式固定 channel
Guix 构建日志见 `/tmp/hermes-react-esbuild-node-source-build.log`。
正式构建实际 exit0，grafted 产物为 `d5w5bjmpj0i8b2dlki5j665chikh50r0`；
六项安装文件的哈希见 `planning/hermes-react-esbuild-node-artifacts.json`。
未执行 installer，也未开展目标功能验证。

Rollup 4.34.8 匹配原生产物已交付，使用五个 authored TS 入口的 bootstrap
helper 实际编译并接入该 ELF，exit0。完整安装布局及哈希见
`planning/hermes-react-rollup-bootstrap-composed-artifacts.json`。
此为私有构建 bootstrap，仍须完成其外部依赖闭包和 authored release，
不能替代最终 Rollup、React 或 Next 构建完成。


用source-built esbuild实际编译Rollup4.34.8全部五个bootstrap authored TS
入口，exit0，安装前JS产物hash见
`planning/hermes-react-rollup-bootstrap-entries-artifacts.json`；未执行outputs。
native接入和authored release仍待完成。esbuild平台Go程序已有产物，但Node
JS API也须从其TS入口生成，后续补齐该provider；初次猜scripts/node.ts路径
失败，不以未找到文件宣称源码不可得。六项重型编译本轮实际handle确认活跃。

新增build-rollup-source-bootstrap.py，将完整authored库、loadConfigFile、
getLogFilter、parseAst及CLI五个TS入口从源码编译为私有构建bootstrap，
要求准确4.34.8源码/native metadata和ELF，保留本地binding发现路径与许可证。
仅bootstrap明确CJS布局，最终包仍须执行authored release并安装原始API资源。
helper尚未实际消费pending native产物，不算交付完整Rollup。六项构建
64816/35598/74478/45927/49776/11195本轮实际handle确认活跃，功能验证延后。

完整官方Rollup4.34.8源码解包后，使用已源码构建esbuild0.25.0编译authored
src/node-entry.ts（保留所有exports与外部package引用），实际exit0，bootstrap
JS及SHA256见 `planning/hermes-react-rollup-bootstrap-js-artifacts.json`。
未复制registry已编译JS，也未运行bootstrap或调用其功能；仍须接入准确
4.34.8 native/provider与锁定依赖，并执行完整authored release构建。
64816、35598、74478、45927、49776、11195本轮实际handle确认活跃。

Rollup4.34.9 native71239实际exit0，输出0hdswk...，静态ELF、版本metadata、
Cargo.lock与binary SHA256见 `planning/hermes-react-rollup-native-artifacts.json`。
配方参数化source/version/crates并新增准确4.34.8 bootstrap；首次解析exit1
因增加version参数时多留一个括号，已修正。新正式构建启动，日志
`/tmp/hermes-react-rollup-bootstrap-native-fixed-build.log`。4.34.9已成功证据
对应先前配方，参数化后的派生版本尚待后续消费构建，不能混淆身份。
35598、74478、45927、49776、11195本轮实际handle仍活跃，功能验证延后。

Hermes audio41985实际exit1：SciPy1.18.0完整wheel已源码编译成功，后续
scikit-learn Meson执行sklearn/_build_utils/version.py失败。核对固定sdist
原始shebang为/usr/bin/env python3，沙箱无/usr/bin/env；build helper仅改
该版本提取脚本为当前匹配Python绝对路径，并保留实际version解析逻辑。
修正版完整audio正式构建已启动，日志
`/tmp/hermes-audio-scikit-shebang-source-build.log`，tests?保持false。
Rollup bootstrap源锁87259实际exit0（194 crates），独立native配方尚待加入。
71239、74478、45927、49776、11195本轮实际handle仍活跃，未提前功能验证。

Rollup bootstrap4.34.8下载12830实际exit0，两个官方源码rust目录121文件
比较显示Cargo.lock/bindings_napi manifest/parse_ast manifest有差异，不能
直接使用4.34.9 native identity；证据
`planning/hermes-react-rollup-bootstrap-source-comparison.json`。
独立4.34.8 native源锁认证已启动，日志
`/tmp/hermes-react-rollup-bootstrap-source-lock.log`，相同registry cache复用。
组装器新增npm锁格式，要求相同锁hash的peer审计并核对覆盖每个实际peer边，
保留已有pnpm/Yarn默认。尚需source providers完成后实际消费，六项重型
编译本轮实际handle确认活跃，功能验证延后。

六项构建71239/74478/45927/49776/41985/11195本轮均通过实际handle确认活跃。
下载锁定Rollup bootstrap4.34.8源码12830启动，保持与4.34.9构建锁匹配。
新增audit-npm-peer-ranges.cjs，使用已认证源码semver7.7.2作为元数据工具
核对npm实际peer选中版本及约束，不加载目标框架。原Rollup工具图没有
semver，首次寻找输入失败后改用既有Next认证归档，并重新核对archive hash。
审计结果见 `planning/hermes-react-rollup-js-peer-audit.json`；source bootstrap、
JS产物和整体框架仍待交付，功能验证保持延后。

Rollup JS归档认证52986实际exit0：72 Linux archives、3含native/WASM。
原生27525实际exit1，psm/cc-rs无法找到默认cc；Guix环境应明确gcc。
配方新增CC=gcc、CXX=g++及Cargo target linker=gcc，不改源码版本、依赖
或LTO。修正版正式构建已启动，日志
`/tmp/hermes-react-rollup-native-gcc-source-build.log`。74478、45927、49776、
41985、11195本轮实际handle仍活跃，功能验证保持延后。

新增inventory-rollup-npm.py按authored npm lock v3实际安装位置解析 nearest
dependency/optional/peer边，保留identity路径、peer原始约束及准确SRI；
实际exit0，13 roots/114 npm locations，证据
`planning/hermes-react-rollup-js-node-inventory.json`。归档认证器保留npm锁
hash字段，正式认证已启动，日志 `/tmp/hermes-react-rollup-js-node-archive-audit.log`。
peer范围审计、源码bootstrap和provider接入仍待完成，不用npm install重锁。
74478、27525、45927、49776、41985、11195本轮实际handle确认活跃。

WASI std session71203实际exit1：Rust1.93 bootstrap要求wasi-root/lib/
wasm32-wasip1/libc.a，而已核对channel libc使用wasm32-wasi布局。此前
只验证旧布局存在不足以保证Rust消费成功。configure helper新增构建目录
隔离sysroot视图，保留include和各lib固定来源，并为相同preview-one库提供
wasip1目录alias；不修改store、不换target、不用预编译Rust std。
修正版正式构建已启动，日志
`/tmp/hermes-next-wasi-target-layout-source-build.log`。旧45927 plugin消费者
本轮实际仍活跃，等待其准确终止再启动新输入版本。Rollup27525、Hermes
49776/41985、Codex11195本轮亦实际活跃；功能验证继续延后。

独立Compiler归档认证42488实际exit0，183 Linux archives，45含native/WASM；
短网络超时已由有限原重试恢复，最终SRI认证不放宽。Rollup原生27525及五项
重型构建本轮实际handle仍活跃。审计Rollup JS authored config/build plugins
并按自身npm package-lock v3记录准确工具versions/SRI，证据
`planning/hermes-react-rollup-js-build-audit.json`。其build:js锁定Rollup4.34.8
bootstrap，registry已编译JS不能充当源码结果；后续须源码bootstrap和完整
npm闭包，不能仅有Rust binding就称完整Rollup。功能验证保持延后。

Rollup源锁25997实际exit0，194 registry源码完成认证，生成
hermes-react-rollup-lock.scm。新增hermes-react-rollup.scm正式独立provider，
chdir准确rust workspace、offline/locked Cargo构建bindings_napi，保留原始
profile.release的LTO/strip，安装匹配4.34.9 platform metadata与许可证。
正式构建已启动，日志 `/tmp/hermes-react-rollup-native-source-build.log`，
显式固定channel/cores1/silent7200；仍待实际编译结果，JS源码构建另行完成。
42488及五项重型编译本轮实际handle确认活跃，功能验证延后。

Rollup4.34.9下载45004实际exit0，完整安全解包；原生入口为rust/bindings_napi
cdylib，authored build:napi明确cargo-cwd rust。首次锁定实际exit1因误用
根Cargo.lock，已改精确rust/Cargo.lock路径，新锁定session25997启动，日志
`/tmp/hermes-react-rollup-source-lock-fixed.log`。source archive与Cargo.lock
哈希及原生脚本见 `planning/hermes-react-rollup-source-audit.json`。
尚无Rollup native产物；后续保持原始locked源码编译并提供matching provider。
42488和五项重型编译本轮均通过实际handle确认活跃，功能验证延后。

esbuild0.25.0正式构建12991实际exit0，输出1qa1nxb...；仅静态核对ELF头、
源码平台provider准确name/version及binary SHA256，证据
`planning/hermes-react-compiler-esbuild-artifacts.json`，未运行程序功能。
Rollup4.34.9官方源码下载45004启动；native锁生成工具新增明确rollup
component/version参数，保留其他组件默认范围，准备认证其Cargo闭包。
独立Compiler认证42488和五项重型编译本轮实际handle仍活跃，整体未完成。

扩展根工具归档认证11281实际exit0：438 Linux archives，48含原生/WASM。
esbuild0.25.0官方源码96905下载exit0，go.mod核对仍需原始x/sys
c0bba94af5f8，与已有source recipe准确一致。新增hermes-react-tools.scm
精确版本provider，固定archive SHA256并保留平台metadata源码snippet；
正式Guix构建已启动，日志 `/tmp/hermes-react-compiler-esbuild-source-build.log`，
使用固定channel/cores1/max-silent7200。独立42488及五项重型编译本轮
实际handle确认活跃；尚无新esbuild最终产物，未运行功能用例。

独立旧认证21811实际exit1，准确原因为旧wrap-ansi-cjs错误，修正版42488
已启动，日志 `/tmp/hermes-react-compiler-private-alias-audit.log`；扩展11281
本轮实际handle仍活跃。准确Compiler锁需esbuild0.25.0和Rollup4.34.9，
不同于已有Next esbuild0.25.9，不能跨版本替换。新增
`planning/hermes-react-compiler-native-requirements.json` 保留这些工具及各
平台原始SRI/依赖；Linux对应Go程序和Rust binding仍需源码构建，外平台
明确不纳入Linux。五项重型编译本轮实际确认活跃，功能验证延后。

扩展工具认证38744实际exit1，准确失败为wrap-ansi-cjs@7.0.0 404：Yarn npm
alias被误当registry真实名字。inventory生成器已从npm:约束取真实包名，
保留snapshot/edge声明别名和原始version/SRI；同时修正现有两个Compiler
inventory的wrap-ansi、strip-ansi、string-width三项真实身份。原版本与认证
要求不变。扩展认证重试已启动，日志
`/tmp/hermes-react-compiler-build-node-alias-audit.log`。独立21811仍实际活跃，
其已加载旧清单，等待准确终止再决定重试，不因观察时间重复启动。
五项重型编译本轮实际handle确认运行，未执行功能验证。

Yarn inventory 新增安全 archive 相对 lock/manifest/附加manifest参数，保持
ncc默认不变。React Compiler 独立环境实际exit0，13 roots/185 packages，
使用compiler/yarn.lock、compiler/package.json及本地插件声明；证据
`planning/hermes-react-compiler-private-node-inventory.json`。这与根React
Rollup环境分别维护，不混用Babel版本。独立缓存归档认证已启动，日志
`/tmp/hermes-react-compiler-private-archive-audit.log`。扩展根工具440图旧认证
38744本轮仍活跃但日志出现404，尚待准确退出/失败输入核对，不能宣称成功。
五项实际重型编译本轮确认仍活跃，功能验证保持延后。

基础React build归档认证69005实际exit0：303 Linux archives，4含原生/WASM。
扩展工具图440归档认证已启动，日志
`/tmp/hermes-react-compiler-build-node-archive-audit.log`。Compiler源码导入
审计发现原扫描跨字符串和生成代码示例误计候选，已收紧字面包路径并保留
非字面候选待审计；实际重新生成129文件/10外部包名，覆盖范围仍为静态审计。
Compiler拥有独立compiler/yarn.lock和自身resolutions，不能用根工具图的
Babel版本冒充Compiler准确环境，后续须按其独立锁与workspace声明解析。
五项重型编译本轮实际handle确认继续运行，未执行功能验证。

新增 `inventory-react-compiler-source.py` 从 authored src/index.ts 跟踪字面
import/export/require相对源码边，记录每个源文件hash与外部引用出处及三层
manifest声明/resolutions。首次扫描误读注释中的from示例，移除注释同时保留
quoted字符串后实际exit0：129源文件、19外部名字，证据
`planning/hermes-react-compiler-source-imports.json`。这是源码闭包审计，
不执行TS或import；动态引用、type-only分类、peer及Yarn解析仍需后续。
69005和五项重型编译本轮均通过实际handle确认活跃，功能验证延后。

React本地Compiler authored tsup.config.ts已核对：src/index.ts→dist/index.js，
CJS/Node/es2015，bundle=true，@babel/types为external。新增inventory
build-root参数只接受根manifest明确声明的工具，生成包含tsup、TypeScript、
Babel的独立清单 `planning/hermes-react-compiler-build-node-inventory.json`。
fs-extra采用同源码compiler/package.json明确^4.0.2的原始root Yarn selector，
不是任意从多版本候选挑选。Compiler自身源码引用/共同peer/local依赖仍需
完整审计；该工具清单不证明Compiler已构建或闭包已穷尽。
69005归档认证及五项重型编译本轮均通过实际handle确认仍活跃，未因日志
静默重启，也未提前执行功能验证。

扩展既有 Yarn v1 inventory 工具支持明确 source-label/scan-prefix/scan-file，
保留 ncc 默认行为；React authored scripts/rollup、scripts/babel 与 shared
host-config引用扫描实际 exit0，32 build roots/303 exact Yarn packages，
清单 `planning/hermes-react-build-node-inventory.json`。全部保留原始 Yarn
selectors、SRI 和精确依赖链；动态引用、peer与本地Compiler仍须后续审计。
启动归档认证，日志 `/tmp/hermes-react-build-node-archive-audit.log`，尚待完成。
五项重型构建本轮实际handle确认活跃，没有功能验证。

React源码下载59674实际exit0；安全解包完整归档，SHA256及源码入口审计见
`planning/hermes-next-react-source-audit.json`。主React task归档认证66494
实际exit0：2016 Linux archives，23含原生/WASM。authored build-all-release-
channels构建stable/experimental且用git提交/date生成准确版本；tarball
配方须显式传递已认证提交/发行日期，不能伪造Git仓库身份。prebuild通过
Yarn link接入同仓库React Compiler，后续须锁定其源码依赖及本地布局；
根Yarn v1/112 devDependency候选还需按实际构建引用收敛并认证。
尚无React构建产物，未调用download-build脚本或功能用例。五项实际重型
session本轮确认仍活跃，整体计划保持未完成。

React扩展16.0.8归档审计36292实际exit0：1761 Linux archives，16含原生/WASM。
主扩展归档认证66494启动，日志 `/tmp/hermes-next-react-task-archive-audit.log`。
源码下载59674本轮经实际handle确认仍活跃，尚未解包半成品。
新增 `planning/hermes-next-react-source-build-requirements.json` 登记准确的
新增root aliases/snapshots以及canary/experimental React、DOM、scheduler、
RSC webpack/turbopack源码交付和资源布局要求。认证发行归档不能代替这些
已编译JS的源码重建，最终graph/框架仍待完成；功能验证保持延后。

主 React task inventory session94877 实际 exit 0，9 workspaces/2111
snapshots；16.0.8为8/1829。新增归档认证session36292已启动，日志
`/tmp/hermes-next-1608-react-task-archive-audit.log`，复用原认证cache。
读取 npm 原始 react19.3.0-canary-52684925-20251110 元数据，gitHead准确为
52684925368a41a0c9fbfca9016cdcbb72fc9d1e；原响应保存
`/tmp/under-sea-react-canary-metadata.json`。已启动该精确提交官方源码归档
下载，不将发行包cjs文件冒充源码构建结果；React构建配方与依赖仍待审计。
49776、71203、45927、41985、11195本轮实际handle确认活跃。

ncc session3954 实际 exit 1，已通过 lru-cache、Babel/browserslist 与 OG
任务，下一失败为 copy_vendor_react 动态引用 scheduler-builtin。静态引用
清单遗漏 authored 模板字符串；inventory-next-node.py 增加严格核对
channel=builtin/experimental-builtin 和 packageSuffix 空/-experimental 两条
分支，保留原始 root lock 的精确 alias，不猜版本。16.0.8与主图分别生成
独立 react-task inventory，旧构建图/锁保持不变。React vendor 源码构建
仍须单独审计，不能直接复制发布的已编译 cjs 就称全部源码构建完成。
五项实际重型 session 本轮确认活跃；功能验证延后。

用已有源码构建 ncc 重建认证的 lru-cache7.18.3，实际 exit 0；与原始
Next16.0.8 bundle 只差两处 webpack 模块编号78/649（定义及引用），除此
逐字节相同，证据见 `planning/hermes-next-lru-source-rebuild-comparison.json`。
新增 stage-next-source-lru.py 固定 archive SHA256及准确版本，仅允许已比较
的16.0.8，接入 authored ncc 直接引用，不执行库功能或任意选择版本。
可写registry及lru已接入后，新完整 ncc 编译 session3954 启动，日志
`/tmp/hermes-next-1608-ncc-writable-source-build.log`。尚需实际完整成功退出
及全部资源检查；正式framework配方还需固定此源码输入并调用这些步骤。
五项重型构建本轮实际handle确认继续运行，功能验证延后。

lru-cache 已选传递版本5.1.1与原始 Next 编译资源结构明显不同（原资源含
AbortController/fetch/ttl 路径而非 Yallist），因此未将5.1.1冒充直接输入。
下载原始完整 pnpm lock 已固定的7.18.3源码候选，实际 SHA512 SRI 完全匹配；
包身份、archive SHA256及共同源码字符串证据见
`planning/hermes-next-lru-source-candidate.json`。目前仅为候选，仍须精确
源码重建比较才能接入，未执行运行功能检查或改变包依赖锁。
五项重型构建本轮均通过实际 handle 确认仍活跃。

17050 实际 exit 1，schema-utils2/3 错误已消失，剩余 lru-cache 直接引用
和 Babel/browserslist 写只读输入。等待其终止后实际启动可写 registry staging
session 26978，最终实际 exit 0，日志 `/tmp/hermes-next-1608-writable-registry-stage.log`；
链接重定位记录见 `planning/hermes-next-1608-writable-registry-layout.json`。
仅复制到 task 消费端隔离树，不修改 store 来源。原始完整 pnpm lock 中
lru-cache 有多个版本，而当前所选 task 闭包只有传递版本5.1.1，不能以该
唯一已选产物推断上游未声明直接引用的版本；后续需核对 hoisting/源码身份。
未添加任意 lru-cache alias，尚未重启 ncc。五项实际重型 handle 本轮
确认继续活跃，功能验证保持延后。

55416 实际 exit 1，除旧 schema metadata 错误外还有 lru-cache metadata
别名和 Babel parser/browserslist 写只读 store 失败。修正后的 schema plugin
两处查找与真实名称逻辑已实际写入隔离树，新 ncc session 17050 启动，
日志 `/tmp/hermes-next-1608-ncc-metadata-fixed-build.log`，尚待退出核实。
新增 `stage-next-writable-registry.py` 为 authored 会修改的 registry 构建输入
提供消费端可写副本并重定位 exact dependency 链接，源码 providers 保持外部。
尚未在运行中的同一源码树应用，待现有编译终止后接入并处理 lru 别名。
此前单独设置 packageJsonName 不足以修改 lookup，已补充 scoped lookup
及真实 manifest name 保留；不能把上轮首个方案记作构建成功。
五项重型构建本轮通过实际 session 确认活跃；未执行功能验证。

Next ncc session 15456 实际 exit 1：schema-utils2/3 的源入口通过锁定别名
找到，但生成 manifest 按 schema-utils 真名读取，隔离图无该未声明 alias。
新增 `patch-next-source-task-aliases.py`，使用 authored ncc 已支持的
packageJsonName 参数分别读取 schema-utils2/3 元数据，保持真实 packageName
及 bundleName，不添加任意版本的 schema-utils。两处精确锚点及插件参数
支持均核对后，在隔离树应用并启动新 ncc 编译，日志
`/tmp/hermes-next-1608-ncc-schema-alias-build.log`；仍需整体完成证据。
49776、71203、45927、41985、11195 本轮实际 handle 确认活跃。

Next 16.0.8 SWC session 14904 实际 exit 0，输出
`/gnu/store/pq7bbnxcnn5dspp3i9cd07lvmcyvwq2i-next-swc-for-hermes-analyzer-bootstrap-16.0.8`。
开始隔离树 authored taskr ncc 编译，发现 taskr 吞掉 esnext 加载错误后
打印异常却返回 0，故两次短退出不能算成功。源码核对其在自身包位置动态
require @taskr/esnext；将消费端已锁定 node_modules 加入构建专用 NODE_PATH，
并禁用 Node24 自动 ESM 检测，保持原 authored 转译方式。新编译 session
15456 已启动，日志 `/tmp/hermes-next-1608-ncc-consumer-resolution-build.log`，
必须结合日志和完整产物判断成功，不能只依据 CLI 返回码。
49776、71203、45927、41985、11195 本轮实际确认仍活跃，功能验证延后。

Next 16.0.8 module/nomodule polyfill 按原始 workspace build 参数编译，
7776、71643 均实际 exit 0。新增 `build-next-source-polyfills.py` 核对两套
workspace 身份和 authored build 完整参数，使用锁定 microbundle 入口；
实际 helper 构建 96177 exit 0，产物 SHA256 见
`planning/hermes-next-1608-polyfill-artifacts.json`。
依赖锁保持固定，未按 baseline-browser-mapping 的提示更新依赖；未执行
浏览器或产物功能测试。此为隔离源码编译证据，正式 Guix framework 配方
仍需调用 helper 并交付完整框架。六项重型构建本轮实际 handle 确认活跃。

完整 Next 16.0.8 task 模块图 session 54235 实际 exit 0，输出 fbj9k28...。
在全新隔离源码树实际运行 consumer staging，session 1492 exit 0，
成功接入 8 个 workspace 及根目录共 9 个依赖目录，未修改 store providers，
未执行生成的 Node/原生工具入口。消费布局证据与 SHA256 见
`planning/hermes-next-1608-consumer-layout-artifacts.json`。
这证明 helper 可以消费真实模块产物；Next framework 编译、polyfill 构建、
匹配 SWC/error-code WASM、analyzer UI 及最终 dashboard 仍待完成。
核对 authored types 使用完整 tsc 声明生成参数，error-code 检查为根目录
node packages/next/check-error-codes.js；后续配方必须保留其实际检查语义。
49776、71203、45927、41985、11195、14904 本轮实际确认仍活跃。

新增 `scripts/stage-next-source-native.py`，为后续框架配方接入匹配版本的
源码 SWC 和 error-code WASM。核对 SWC 包身份、ELF 头，以及插件源码、
manifest、lock 和原始待替换载荷哈希；源码插件须有 WASM 头和匹配 lock。
按 authored native 路径复制并登记产物哈希，不执行 binding/plugin。
helper 语法解析通过，但尚未由实际框架构建消费，不能记作框架已交付。
49776、54235、71203、45927、41985、11195、14904 本轮经实际 handle
确认仍活跃，继续等待匹配原生构建产物；功能验证延后。

Rspack 1.6.0 构建 session 49890 实际 exit 0，输出 axpxa9pk...，
原生 .node 路径与 SHA256 记录于 `planning/hermes-next-1608-rspack-artifacts.json`。
核对两版 Next 的 copy_vercel_og 任务正文一致，兼容性证据见
`planning/hermes-next-og-task-compatibility.json`；OG 安装 helper 允许准确的
16.0.8/16.1.1 两个版本，记录消费版本。16.1.1 另有 analyzer UI 任务，
仍须实际交付，未删去或绕过。最初比较包含相邻 analyzer 函数导致不一致，
缩到正确函数边界后证明 OG 任务相同；没有据错误比较修改功能。
其他八个实际构建 handle 本轮仍活跃，未运行功能验证。

本轮核实基础 Next 16.1.1 模块构建 session 22375 实际 exit 0，
输出 `/gnu/store/78dfkfvx57x7b60hr6ysa83znl9n6dc4-next-source-build-modules-16.1.1`。
安装布局及其 SHA256 记录于 `planning/hermes-next-source-modules-artifacts.json`。
这只证明 plain 模块图和相应源码 provider 组合已构建，完整 task roots、
analyzer、框架与 dashboard 仍待交付。没有运行 Node/浏览器功能测试。
TUI 工作目录修正版 derivation session 86788 实际 exit 0；正式组合构建
session 49776 已启动，日志 `/tmp/hermes-audio-interfaces-cwd-build.log`。
40648、54235、71203、45927、41985、11195、49890、14904 本轮均通过
实际 session 确认仍活跃，保持原构建，不因等待重复启动。

核对 authored TUI gatewayClient.ts：模块来源使用HERMES_PYTHON_SRC_ROOT，
子进程cwd默认HERMES_CWD或该root。组合安装后的root为只读store/site-packages，
会影响terminal/文件操作；TUI启动器明确将未配置的HERMES_CWD设为启动时PWD，
保留用户配置，模块发现仍指向匹配private Python。新derivation解析已启动，
日志 `/tmp/hermes-audio-interfaces-cwd-derivation.log`，旧40648快照保持运行。
尚需实际最终组合安装布局确认，未启动TUI/gateway或运行用户命令。
本轮9项重型构建均通过实际handle确认活跃。

本轮为已核实构建等待：40648/54235/71203/45927/22375/41985/11195/
49890/14904均通过实际session再次确认仍活跃。Rspack1.6.0已推进到
node_binding及后续插件，1.6.7已推进到各插件；尚无最终成功或失败exit。
不重启这些编译，不以日志停留在依赖OG成功行就宣称整个模块组合完成。
音频、WASI、Codex及界面组合继续沿用现有handle，功能验证保持延后。

共同音频界面组合接入已成功的hermes-linux-skill-tools：CLI/Python/ACP
入口用固定shell包装原始runtime程序，TUI/dashboard亦显式加入同一tools
目录，保留用户PATH供额外专用客户端发现。原始audio store入口不修改，
组合manifest登记skill-tools路径。正式新组合构建启动，日志
`/tmp/hermes-audio-interfaces-skill-tools-build.log`；实际组合产物仍等待
音频/界面依赖完成，不能把PATH定义当功能验证或全部skills完整。
74995/54235/71203/45927/22375/41985/11195/49890/14904本轮通过
实际handle确认仍活跃，未运行任何新功能用例。

技能工具集合50155实际exit 0，default-graft输出wn8agd...，16个入口均
存在并指向固定store程序，路径及文件哈希记录
`planning/hermes-linux-skill-tools-artifacts.json`。包括先前错误的Docker
客户端以及uv均已通过静态安装检查，未运行程序。最终Hermes PATH接入、
H14专用工具与动态调用收敛仍待完成，不能将常见工具集合成功当作H14全部完成。

技能工具集合82907实际exit 1：固定docker包输出只含dockerd，不含客户端。
已核对源码定义与实际store/bin，改为准确docker-cli包，而非删去Docker候选。
新正式组装50155启动，日志 `/tmp/hermes-linux-skill-tools-client-build.log`。
此前convert至paplay等顺序处理的入口已通过文件存在性检查；uv与最终整个
集合尚需新build确认，所有程序均未实际运行。README新增共同音频界面组合
和可选技能工具的固定channel构建命令，明确当前构建/接入及服务条件边界。
74995/54235/71203/45927/22375/41985/11195/49890/14904本轮实际
handle确认仍活跃，功能验证继续延后。

新增 `hermes-audio-interfaces.scm`：TUI与dashboard启动器实际固定到同一
hermes-agent-audio私有Python运行时，保留全部runtime入口及资源引用。
初步继承GNU配方的derivation79008解析成功，但会重复编译整套依赖，
已改为直接引用独立源码组件输出的trivial组合包；正式组合构建已启动，
日志 `/tmp/hermes-audio-interfaces-source-combination-build.log`。
这仍需完整音频产物成功后才能交付，不冒充包含desktop/browser/全部skills
的最终完整Hermes，也不运行界面或功能检查。82907/54235/71203/45927/
22375/41985/11195/49890/14904本轮实际handle确认仍活跃。

H14新增可选 `hermes-linux-skill-tools`，通过固定channel的源码包定义
提供16项已识别常见Linux CLI引用（图像/音视频、Node/npm、PDF/办公文档、
网络诊断、音频会话和容器客户端），附store资源manifest与daemon/device
条件说明。首次derivation 87265因trivial-build-system不接受
substitutable?关键字实际exit 1，已移除无效参数；lsof按GNU配方默认/bin
布局登记，最终文件存在性仍待构建检查，iproute输出/sbin由固定源码配方
核对。正式组装已启动，日志
`/tmp/hermes-linux-skill-tools-build.log`，完整产物仍待确认。
这是可选工具引用集合，不代表H14动态调用已穷尽，也不代表专用gws/brv/
ollama/openviking/buzz/raft、服务条件或最终Hermes入口已接入。
原有8项编译handle本轮实际确认活跃，未执行功能用例。

发现 Hermes GNU 配方未显式设置 tests?，保留的安装后 smoke-check 会在
编译结束调用CLI/import脚本，违反本轮统一延后功能验证的安排。已在共同
工厂明确 #:tests? #f，保留检查代码供后续显式启用。13486仍在编译阶段，
本轮确认后通过其精确shell日志路径和PPid核实本任务客户端，只对该客户端
发SIGINT，未修改store快照或中断其他构建。新的音频正式构建启动，日志
`/tmp/hermes-audio-deferred-validation-build.log`，保留全部组件及原有构建参数。
此为遵守验证边界的主动停止，不能记为源码错误或此前功能验证已通过。

消费端 staging helper 补充 CLI 类型处理：metadata bin=null 视为无入口，
实际 ELF source-provider 程序直接执行，非Node shebang保留其原始入口，
Node工具继续使用固定Node及原始JS路径。避免把源码原生工具交给Node解析；
语法检查通过，实际消费端安装/构建仍需正式模块产物确认。本轮54235/
71203/45927/22375/13486/11195/49890/14904均通过实际handle确认仍活跃，
音频已推进到PyAV源码扩展编译，WASI推进到Rust编译器bootstrap；未执行功能用例。

新增消费端 staging helper `stage-hermes-next-modules.py`：核对原始 pnpm
lock hash，将模块图的workspace依赖复制到可写的authored源码目录，重定位
workspace链接以消费本次编译输出；registry/provider路径保持store来源。
按声明生成固定Node/完整entrypoint的private .bin，并拒绝冲突或路径逃逸，
无需npm安装脚本。该helper尚需实际模块产物与framework配方调用证明；
不将新增脚本本身记为框架已编译。54235日志已推进到源码OG依赖成功构建，
整体模块包exit仍待确认。全部已列构建handles本轮实际确认仍活跃，功能验证延后。

扩展任务输入归档认证：主图23912实际exit 0（2008 Linux archives，23
native/WASM），16.0.8旧55915因TLS错误实际exit 1，有限重试4828实际
exit 0（1753 archives，16 native/WASM）。Next16.0.8任务图新增1736
固定origins并实际认证导入成功，47243 exit 0，store路径记录见
`planning/hermes-next-1608-task-node-source-imports.json`。
正式 next-1608-task-source-build-modules 包接入准确 root aliases和next
workspace alias，以及源码OG 0.7.2、Satori0.15.2、Yoga0.3.3、resvg2.4.0
providers，不复制发布WASM。正式构建54235已启动，日志
`/tmp/hermes-next-1608-task-modules-build.log`。产物及framework消费仍待确认；
主图还必须接入source-built Next16.0.8和SWC供analyzer使用，不能以modules
或来源锁替代完整framework/dashboard交付。功能验证继续延后。

16.0.8 task roots 清单首次生成因临时 PYTHONPATH 拼写错误失败，修正后
实际 exit 0，8 workspaces/1821 snapshots；归档认证 session 55915 已启动。
主 task roots 认证 30710 实际 exit 1 于 curl TLS error 35，未生成成功证据。
归档认证器新增有限的 curl --retry-all-errors，仍要求原始 SRI 和 SHA256
认证；重新启动日志 `/tmp/hermes-next-task-node-archive-audit-retry.log`。
WASI sysroot 日志本轮已推进至 Rust 标准库依赖编译，尚未确认最终产物。

任务引用审计确认 Next authored 构建还需要根 manifest 的 OG/Satori、
resolve-from、execa、Babel parser、is-animated、react-is-builtin 和
webpack-bundle-analyzer，以及 next 自身 workspace alias；仅扫描
packages/next 声明不能当作所有 ncc task 的完整闭包。inventory-next-node.py
新增显式 include-task-roots，通过 authored task/bundle 源码中的静态引用
选择根锁 identities，记录每项引用文件，保持旧默认与活动快照不变。
组装器新增原始 root workspace alias 支持。新的主框架/analyzer 清单为
9 workspaces/2103 snapshots，独立16.0.8清单亦已生成，分别见
`planning/hermes-next-task-node-inventory.json` 和
`planning/hermes-next-1608-task-node-inventory.json`。
两份原始锁归档认证已启动，日志 `/tmp/hermes-next-task-node-archive-audit.log`
与 `/tmp/hermes-next-1608-task-node-archive-audit.log`；动态引用和最终任务
运行仍需实际源码构建收敛，未以静态扫描证明 framework 已构建。
22375/82301/14904/13486/11195/49890/71203/45927/52300 本轮实际
session 均确认活跃；所有功能验证延后。

Next 16.0.8 主 workspace 图新增1705个固定 JS origins并全部实际导入
store，session 6840 exit 0，记录 `planning/hermes-next-1608-node-source-imports.json`。
`hermes-next-node.scm` 改为共用参数化工厂，新增准确版本的
next-1608-source-build-modules，保留独立原始 inventory/archive 和
Rspack 1.6.0 provider；正式 default-graft 构建 session 52300 已启动，
日志 `/tmp/hermes-next-1608-modules-source-build.log`，产物仍待确认。
任务脚本的 bundles/_ 经核对只是合成 Node module resolution 基点，
并不存在独立 bundles workspace；尝试的额外扫描选项已撤回，未生成虚构锁。
源码框架、ncc 内嵌 bundle 重建及 analyzer UI 仍需后续实际构建交付。
71203/45927 本轮实际 session 确认活跃，功能验证继续延后。

Next 16.0.8 的 Rspack 1.6.0 matching binding 新增正式配方，复用明确
参数化的 Rspack 工厂及精确版本的来源锁，主 1.6.7 输入和 features 保持不变。
原始 1.6.0 constructor 及 plugin/info-level features 已核对；正式源码构建
session 49890 已进入 Cargo，日志 `/tmp/hermes-next-1608-rspack-source-build.log`。

错误码 WASM 新增 `hermes-next-wasi.scm`、`hermes-next-error-plugin.scm`。
WASI sysroot 复用固定 channel 的 Rust 1.93 std 源码构建方法，用准确
wasm32-wasip1/wasi-root 配置；插件使用独立 authored lock、源码 WASI libc
与匹配标准库，保留上游 strip/LTO release 设置，不调用 rustup。
首个 sysroot 38331 实际 exit 1 于 inherited native-inputs 格式，修正后
正式 session 71203 启动，日志 `/tmp/hermes-next-wasi-sysroot-source-build-fixed.log`。
插件 derivation 19437 解析通过，正式完整构建已启动，日志
`/tmp/hermes-next-error-plugin-source-build.log`。产物和最终 Next 消费仍待
实际构建确认，不能仅凭包定义称为插件已源码重建；未跑功能用例。

插件来源锁 46822 和 Rspack 1.6.0 来源锁 76584 均实际 exit 0，
分别生成 `next-error-plugin-lock.scm`（242 registry sources）与
`hermes-next-1608-rspack-lock.scm`（610 registry sources及审查的 Git）。
已逐文件校验生成去重 store 导入脚本，696 个固定 origins 正式导入
实际 exit 0，store 路径存在性记录见
`planning/hermes-next-plugin-rspack-source-imports.json`，日志
`/tmp/hermes-next-plugin-rspack-source-import.log`。来源锁成功不等于
WASI 插件或 Rspack binding 已编译，下一步仍需配方和实际源码产物。

Next 16.0.8 JS 来源共享-cache 认证 session 62605 实际 exit 0：1718 个
Linux archives，13 个 native/WASM 载荷。此前重试 16672 已实际 exit 1
于 curl TLS 错误，不再作为活跃任务。该锁要求 Rspack 1.6.0，不能复用
主 Next 16.1.1 的 1.6.7 binding。官方 v1.6.0 源码下载 62976 实际 exit 0，
manifest/归档/锁身份记录于 `planning/hermes-next-1608-rspack-source.json`；
来源锁生成器新增准确 rspack-version 参数，默认仍 1.6.7，独立 1.6.0
锁生成 session 76584 已启动，日志 `/tmp/hermes-next-1608-rspack-source-lock.log`。

源码审计发现框架编译插件 `next_error_code_swc_plugin.wasm` 亦为预编译
输入，不能复制它或禁用插件后宣称源码构建完整。16.1.1/16.0.8 的独立
插件 Cargo.lock 相同，242 registry sources、无 Git，target 为 wasm32-wasip1，
实际插件源文件及发布载荷哈希分别记录于
`planning/hermes-next-error-plugin-source-audit.json`。Next 锁生成器新增
安全的独立 lock-relative 参数，并与原始归档核对该 lock/manifest；
认证 session 46822 已启动，日志 `/tmp/hermes-next-error-plugin-source-lock.log`。
匹配 Rust WASI sysroot、插件正式源码构建和框架消费仍需完成。
22375/82301/14904/13486/11195 本轮实际 session 均确认活跃，未执行功能验证。

Rspack 28803 实际 exit 1：Rust 1.95 拒绝 DependencyWrapper 构造器中
把借用 trait-object 隐式转换为 static object 指针。源码调用点来自模块图/
factory 持有的 Box<dyn Dependency>；新增 `patch-hermes-rspack.py` 将构造器
参数的对象边界显式标为 `&(dyn Dependency + 'static)`，不延长引用借用、
不使用 unchecked transmute、不改变所有权。调用链是否全部满足该边界仍需
实际编译证明。新的正式完整模块闭包构建已启动，日志
`/tmp/hermes-next-source-modules-lifetime-build.log`。82301 使用旧快照，
保持其运行且不修改 store 输入；不能以新补丁宣称旧快照已修复。

Next 16.1.1 authored 主构建图新增正式 `hermes-next-node.scm` 和
1711 个固定 JS origins（`hermes-next-node-lock.scm`），全部缓存再次校验
并导入 store 成功，记录 `planning/hermes-next-node-source-imports.json`。
包定义 derivation 42534 实际 exit 0，正式 default-graft 组装已启动，日志
`/tmp/hermes-next-source-modules-build.log`，最终产物仍待确认。该图包含八个
authored workspaces，源码 SWC/Rspack/esbuild/ncc/source-map 和按消费锁
组合的 Sharp；未将模块布局宣称为已构建框架或已完成 analyzer/dashboard。
Playwright 1.48.0 原始源码的 Windows dependency scanner 只在 win32/x64
分支使用；Linux build input 仅移除认证归档中的 `package/bin/PrintDeps.exe`，
全部 Linux 实现保留，精确归档哈希/路径/原因见
`planning/hermes-next-build-source-removals.json`。16.0.8 来源认证重试、
其 SWC、完整音频、Rspack 和 Codex 构建均有待后续实际结果确认。

Next 16.0.8 JS 归档认证 86684 实际 exit 1，curl 下载锁定的
@webassemblyjs/helper-wasm-bytecode 1.13.2 时出现 TLS 错误（exit 35）。
该过程已经终止；复用已认证缓存重新启动下载，日志
`/tmp/hermes-next-1608-node-archive-audit-retry.log`，尚不能记为全部认证通过。
14904 的绑定构建和 13486 的音频构建本轮均再次确认活跃。

本轮实际推进：Sharp provider 复制保留只读目录权限，导致依赖目录创建失败。
组装器改为只给新复制的包根目录增加 owner write，并排除 provider 根部旧
node_modules，按消费端原始锁重建依赖链接；store provider 与实现文件保持
不变。重新组装实际 exit 0，六个 Linux/glibc snapshots 的布局及源码文件
哈希见 `planning/hermes-next-sharp-runtime-layout.json`；仅安装布局检查，
未加载 binding 或处理图片，最终 Next 消费接入仍待完成。

独立 SWC 1.11.24 session 5923 实际 exit 0，正式输出 illwz6...，安装文件
哈希见 `planning/hermes-next-swc-core-artifacts.json`。Next 16.0.8 来源锁
65503 实际 exit 0；958 个固定 origins 已认证导入 store（含源码、955 registry
和两个 Git 来源），见 `planning/hermes-next-1608-native-source-imports.json`。
官方 annotated tag 解引用提交 817ee56... 已核对；SWC 配方改为共用工厂，
主版本的来源和参数保持原样，另定义 analyzer-bootstrap 16.0.8 匹配绑定。
正式构建 session 14904 已进入 Cargo 编译，日志
`/tmp/hermes-next-1608-swc-source-build.log`。该版本的 JS 原始锁归档认证
session 86684 已启动，日志 `/tmp/hermes-next-1608-node-archive-audit.log`。

完整音频 session 63015 实际 exit 1，NumPy 和多项 Rust Python 依赖已通过
编译，但 SciPy 1.18.0 的 authored Meson 默认需要 Pythran >=0.18.1。
已补入固定 channel 的源码 python-pythran 0.18.1 commit，不禁用 Pythran
内核；新正式构建 session 13486，日志 `/tmp/hermes-audio-pythran-source-build.log`。
Rspack 28803、Codex 11195 本轮实际 session 确認仍活跃；所有功能验证延后。

更正 Sharp 0.34.4 运行闭包记录：已生成原始锁子图、源码 provider 组合支持
和 optional 预编译替代清单，但实际组装因复制后的 node_modules 路径问题
报 FileNotFoundError；尚未生成 runtime-layout 成功记录，不能标记已接入。
后续须修复独立复制布局的依赖目录，再接入 @img/colour、detect-libc、semver
的准确锁身份。原始 lib/sharp.js 首选本地 src/build/Release binding；
两项 optional @img 预编译 binding/libvips 的替代依据见
`planning/hermes-next-sharp-optional-replacements.json`，仍需实际布局检查。
不得修改 store provider 或上游加载/CPU 检查代码，required 依赖不能省略。
Sharp/libvips 独立源码构建成功仍有效；运行闭包和完整 Next 图尚未完成。
本项未 import Sharp 或处理图片；历史 session 状态不代表本次重新确认。

ncc 正式构建 45765 实际 exit 0，default graft 输出 rlblxf...，218 个
安装资源逐文件哈希见 `planning/hermes-ncc-source-artifacts.json`，尚需 Next
消费端接入。Next 16.0.8 官方归档 32842 实际下载成功；安全展开时拒绝顶层
test fixture 的绝对符号链接，另建仅排除顶层 test 的构建视图，原始归档保持
完整且固定哈希。源码/锁身份见 `planning/hermes-next-1608-source.json`。
其955 registry sources、2 Git sources 的认证 65503 仍实际运行，版本源码
scanner 改为读取真实 Next manifest，另生成该版本独立 JS/workspace 清单，
不冒充 Next 16.1.1 来源或更改主目标版本。28803/5923/63015/11195 本轮均
实际确认活跃，功能验证继续延后。

ncc 192 source origins 导入 session 40202 实际 exit 0，全部 store 路径确认
存在，记录 `planning/hermes-ncc-source-imports.json`；正式 ncc 45765 已推进到
authored CLI/API 源码编译，尚未确认最终 exit。Next 原生来源锁生成器新增
显式独立模块名，保持旧默认，用于 analyzer 锁要求的 Next/SWC 16.0.8 来源；
该官方源码下载已启动。后续须区分构建期 bootstrap 工具与完整发行交付，
最终 Next 16.1.1 的 bundle-analyzer UI 不能因源码构建环而删除。
28803/5923/63015/11195 本轮 session 均确认活跃，功能验证继续延后。

ncc peer 源码重编译 session 45999 实际 exit 0，原始 CLI/API/loaders/V8
caches/types/源码 WASM 已生成，但不是正式 Guix 交付。新增192个固定 JS
origins 与独立 build-modules 配方，来源 cache 认证导入启动 session 40202。
新增 `hermes-ncc.scm`、`build-hermes-ncc.py`，保留 authored 自举构建，并把
所有发出的资源安全安装；先前布局的额外 package metadata 等不能遗漏。
正式完整构建已启动，日志 `/tmp/hermes-ncc-full-authored-guix-build.log`，实际
store 产物待确认。28803/5923/63015/11195 本轮 session 均实际确认活跃；
功能验证继续延后。

Codex 超时保留目录与 rusty_v8 build.rs 核对显示 V8 Ninja .status() 继承
stdout，但 Cargo 默认缓存 build-script 标准输出；旧日志停在 Compiling v8
不能证明内部 Ninja 停止。host 正式 Cargo 构建新增 -vv 透传真实编译进度，
保留 --max-silent-time=7200、现有全部特性及来源输入，未添加无意义心跳。
新的完整 SDK/host/CLI 构建已启动，日志
`/tmp/codex-sdk-v8-visible-progress-build.log`；是否仍有实际停滞待新日志确认。
ncc peer 重编译 45999、Rspack 28803、SWC 5923、音频 63015 本轮均实际
确认活跃，功能验证继续延后。

Codex SDK/complete 构建 session 26293 已实际 exit 1：code-mode host 连续
静默 7200 秒触发 daemon 超时，保留目录 drv-7；不是源码编译错误证据。
根因阶段与资源诊断待处理，不能继续写成构建活跃或把 timeout 取消当完成。
ncc Yarn peer 已依据认证 metadata 与 Webpack/入口上下文固定 Acorn 8.7.0、
Webpack 5.62.1、TypeScript 4.6.2、AJV 6.12.6，清单
`planning/hermes-ncc-peer-bindings.json`；组装器严格核对名称、精确身份及支持的
peer range，必需 peer 缺失直接拒绝。193 模块新布局实际组装成功，完整 authored
构建重新启动，日志 `/tmp/hermes-next-ncc-authored-peer-build.log`。28803/5923/
63015 本轮 session 仍实际确认活跃，功能验证继续延后。

source-map 0.7.3 session 5388 实际 exit 0，完整源码 JS/API/声明/UMD 与源码
WASM 输出 26602iv...。ncc 清单扫描补 require.resolve，20 个 roots、仍为
193 archives，新增认证实际通过。Yarn 193 模块布局已实际组装；首次 authored
build.js exit 1 于 acorn-import-assertions 缺少 acorn peer，不能把普通 Yarn
dependencies 图当成完整 peer 环境。归档认证器新增已认证 package 的 peer
声明/optional 元数据记录，重新收集；须按原始声明与调用上下文接入，不用任意
全局版本掩盖缺口。构建日志 `/tmp/hermes-next-ncc-authored-source-build.log`。
本轮未跑功能用例，ncc 正式构建仍待完成。

ncc 来源审计 session 42485 实际 exit 0：193 Linux archives 认证通过，
唯一 native/WASM 为 source-map 0.7.3，发布 mappings.wasm 48693 bytes、SHA256
be2dc7da... 与先前 0.7.4/0.8beta 发布载荷完全相同；发布 WASM 不安装。
准确 0.7.3 原始 gitHead 源码已取得并锁哈希，新增正式 provider 配方，实际
源码构建 session 5388 启动，日志 `/tmp/hermes-ncc-source-map-073-source-build.log`。
身份及审计见 `planning/hermes-ncc-native-audit.json`。模块组装器新增显式
Yarn v1 模式，以 authored lock/认证清单哈希核对、optional 边和明确 root alias
组装，保留 pnpm 默认流程；语法解析通过，完整 ncc 组装/构建仍待完成。

源码 store 导入 47582 实际 exit 0，1056 个路径逐项确认存在，记录
`planning/hermes-next-native-source-imports.json`，不算绑定构建完成。
ncc 未声明 imports 采用明确打包选择 resolve 1.20.0、rimraf 3.0.2（均来自
原始 Yarn selectors，非声称原始 Yarn hoist 已证实）；候选仍保留审计记录。
清单扩展到 19 build roots/193 packages。归档认证器支持原始旧 Yarn SHA1
以及 SHA512，记录使用算法，最终 Guix 输入仍固定 SHA256；ncc 完整来源归档
认证/native 审计已启动，日志 `/tmp/hermes-next-ncc-source-archive-audit.log`。
ncc source-map 0.7.3 与已有 0.7.4 不同，准确 JS/WASM provider 仍待补齐。

新增 ncc authored src/build.js 静态 imports 与 Yarn v1 来源清单生成器。
上游 build.js 从 src 自举并生成 CLI、API、loaders、声明、许可证、V8 cache
和 mappings.wasm，不能仅替换发布 WASM 就声称工具已源码重建。发现原始
package 未直接声明 resolve/rimraf 两项 imports，清单单列锁中的候选 selectors，
须确认其实际 hoist 身份后补入；未擅自选择版本或把候选删除当成闭包完成。
动态 imports/assets 仍需审计，记录 `planning/hermes-next-ncc-node-inventory.json`。
47582/28803/5923/63015/26293 本轮 session 均确认活跃，功能验证延后。

SWC/Rspack 来源导入生成器新增严格固定-origin 格式核对、原始 cache SHA256
校验和 Guix daemon 导入前再校验；实际认证 1056 个去重输入并启动导入 session
47582，日志 `/tmp/hermes-next-native-verified-source-import.log`。初次扫描拒绝
含 '+' 的合法 crate 文件名，已修正字符范围；初次没有导入输入。活动构建未重启。
ncc 0.34.0 原始官方 gitHead 源码下载 session 98305 实际 exit 0，package
声明、来源 SHA256、构建脚本与锁文件记录于
`planning/hermes-next-ncc-source-audit.json`，源码重建及 source-map WASM 接入待完成。
28803/5923/63015/26293 本轮均通过实际 session 确认活跃，功能验证延后。

Rspack 来源锁 session 68129 实际 exit 0，633 registry sources 与已审查 Git
输入均固定。新增 `hermes-next-rspack.scm`，原始 Cargo.lock 保持不变，独立
Git vendor 接入，正式源码绑定构建已启动，日志
`/tmp/hermes-next-rspack-binding-source-build.log`。核对原始发行脚本保留
plugin/info-level；使用固定 Guix Rust 1.95 开启不稳定语言特性，标准库使用
Guix 源码产物而非上游附加的体积优化 std 重建，属于明确编译变体，不宣称
匹配上游 nightly-2025-11-13 编译器。实际兼容性及绑定产物仍待编译确认。
SWC 5923、音频 63015、Codex 26293 本轮 session 仍确认活跃，功能验证延后。

原生绑定 session 80192 实际 exit 0：oxide 4.1.13 输出 bm8pl9... 与
Lightning CSS 1.30.1 输出 sm2mbp...，正式安装哈希见
`planning/hermes-next-analyzer-native-artifacts.json`。原生 vendor 准备脚本新增
可选 Git TSV：核对原始 lock source/name/version，以独立目录源和 Cargo source
replacement 保留原始 Git 身份，不改 registry checksums 或重新解析版本。
simd-adler32 的独立来源布局已通过 cargo metadata --offline --locked 检查，
锁文件保持不变，证据 `planning/hermes-rspack-git-vendor-metadata.json`；
这仅证明 Cargo 来源解析，不代表 Rspack 已编译或功能验证通过。

SWC binding 来源锁 39659 实际 exit 0（662 sources）；根 library 锁 33500
亦 exit 0，作用范围分别保留。新增 `hermes-next-swc-core.scm`，在原始
bindings workspace 以默认插件特性源码构建 binding_core_node，正式 session
5923 已启动，日志 `/tmp/hermes-next-swc-core-binding-source-build.log`。
Rspack simd-adler32 Git 源码下载实际成功，核对 0.3.7 与固定提交归档身份，
哈希见 `planning/hermes-rspack-git-source.json`；来源锁生成器仅接受该已审查
Git 身份与内容哈希，其他未审查 Git 仍拒绝。Rspack 633 registry sources 加
此 Git 输入认证启动 session 68129，日志 `/tmp/hermes-next-rspack-source-lock.log`。
正式 Rspack Git vendor 接入与绑定构建仍待完成，功能验证延后。

深入核对 SWC Cargo workspace 发现 Node binding 不在根 workspace，而使用
`bindings/Cargo.lock`，实际为 662 registry sources（无 Git），默认特性
swc_v1/plugin 必须保留。来源锁脚本已改为读取绑定的原始锁，新认证 session
39659 已启动，日志 `/tmp/hermes-next-swc-binding-source-lock.log`；此前根目录
634 sources 33500 仅属于根 library workspace，不能替代绑定来源证据，保留
独立缓存/输出不修改其活动快照。审计 JSON 已补准确绑定 lock 哈希与构建目标。
80192/63015/26293 本轮 session 仍实际确认活跃，功能验证继续延后。

SWC/Rspack 两项源码下载均实际 exit 0；归档哈希、Cargo.lock 哈希和版本
manifest 已核对并登记 `planning/hermes-next-swc-rspack-source-audit.json`。
SWC 1.11.24 原始锁为 634 registry crates、无 Git 依赖；已启动固定来源锁
生成，日志 `/tmp/hermes-next-swc-core-source-lock.log`。Rspack 1.6.7 官方 tag
源码 binding manifest 与发布版本一致，原始锁为 633 registry crates 加
simd-adler32 Git 固定提交 b279034d9eb554c3e5e0af523db044f08d8297ba，需源码
锁与构建接入，不能忽略该输入。来源扫描不等于原生绑定已编译或功能已验证。

已记录 Sharp 0.34.4 正式 graft 输出的安装文件大小/SHA256，更新
`planning/hermes-next-image-sources.json`。Next standalone SWC 1.11.24 官方
registry 指向 Git commit d7932596f2b1c99d04b9a8911d69458ed149ae59；Rspack binding
1.6.7 无 registry gitHead，来源提交仍需官方 tag/manifest 核对，不能推定。
发布元数据身份见 `planning/hermes-next-swc-rspack-release-identities.json`，
两项官方源码下载已启动，Rust 来源锁和正式构建尚待完成。80192/63015/26293
本轮 session 均确认仍活跃，功能验证延后。

Sharp/libvips 89689 与原生锁 17858 均实际 exit 0：匹配 Sharp 0.34.4 产物
rg1xzp...、libvips 8.17.2 成功，246 个原生 registry crates 已认证并生成固定锁。
新增 `hermes-next-analyzer-native.scm` 两个准确版本绑定配方，正式构建启动，
日志 `/tmp/hermes-next-analyzer-native-source-build.log`。组件成功仍不替代最终
Next/source JS 运行闭包接入，功能验证继续延后。

Next esbuild 0.25.9 session 75940 实际 exit 0，源码二进制与同版本
@esbuild/linux-x64 provider 已安装；输出 di1bjsx...，逐文件哈希见
`planning/hermes-next-esbuild-artifacts.json`，尚未接入完整 Next 运行闭包。
原生来源锁脚本新增显式 Lightning CSS 版本参数，保留旧默认；已取得官方
oxide/Tailwind 4.1.13 和 Lightning CSS 1.30.1 tag 源码，并启动原始 Cargo.lock
依赖认证 session 17858，日志 `/tmp/hermes-next-analyzer-native-source-lock.log`。
准确版本正式原生配方及构建待后续，未用其他版本代替。Sharp/libvips 89689、
音频 63015、Codex 26293 本轮 session 均实际确认活跃；功能验证延后。

Next+bundle-analyzer 扩展来源审计 session 86653 实际 exit 0：1974 个 Linux
归档认证通过，20 个含原生/WASM，见
`planning/hermes-next-with-analyzer-native-audit.json`。新增准确版本缺口为
Next/SWC 16.0.8、oxide 4.1.13、Lightning CSS 1.30.1 和旧 Next 内嵌渲染
WASM；不以 dashboard 其他版本 providers 冒充。Sharp 原生构建的现有
node-addon-api 8.9.0 满足源码声明 ^8.5.0，libvips/Sharp 89689 仍实际构建中。
已取得 esbuild 0.25.9 原始源码，确认 x/sys 与 Satori 工具原始提交一致；新增
匹配源码配方并启动正式构建，日志 `/tmp/hermes-next-esbuild-matching-source-build.log`。
所有接口运行验证仍延后，Next 最终组合仍未完成。

新增 `hermes-next-image.scm`：Sharp 0.34.4 使用已认证原始 C++/JS 源码，
libvips 固定官方 8.17.2 tag 与完整归档 SHA256；继承已有完整原生编译流程，
替换实际库输入并修正平台 metadata 到准确版本，不使用预编译 @img 载荷。
正式源码构建 session 89689 已启动，日志
`/tmp/hermes-next-sharp-matching-source-build.log`，来源记录
`planning/hermes-next-image-sources.json`。实际编译、JS 依赖闭包和 Next 接入
仍待交付，功能验证延后。

Next 首批来源审计 session 69084 实际 exit 0：1724 个 Linux 归档认证通过，
13 个含原生/WASM，逐项记录于 `planning/hermes-next-build-native-audit.json`。
源码 provider 新缺口包括 Sharp 0.34.4/libvips 8.17.2、esbuild 0.25.9、SWC
1.11.24、Rspack 1.6.7 和 ncc 0.34.0 内嵌 source-map WASM；现有其他版本
不可冒充。musl 平台载荷单列，Playwright 1.48 的 Windows PrintDeps.exe 需核对
平台调用后准确处理；不凭扫描结果删除 Linux 功能。两个 source-map 版本已有
匹配源码 provider，接入待完成。包含 bundle-analyzer 的扩展审计已启动，日志
`/tmp/hermes-next-with-analyzer-source-audit.log`，复用认证缓存，功能验证延后。

ci-info 来源身份修正版 session 64541 实际 exit 0，输出 7h9akad...，最新
安装哈希已更新至 `planning/hermes-next-ci-info-source.json`，保留此前输出用于
追溯。这完成 Git provider 的来源元数据交付，Next 全闭包集成仍未完成。

Next 模块组装器新增显式 authored workspace source 输入，核对同一 pnpm lock，
复制选定 workspace 并建立其准确 registry/workspace/optional 依赖链接；同时
支持 alias root 与清单中的结构化依赖边。Git tarball provider 要求安装来源身份
JSON，URL 必须与 lock 一致，元数据版本与来源声明一致，不能用 registry 版本
冒充 Git 输入。ci-info 配方已加入该身份元数据并启动重建 session 64541。
组装器语法解析通过，但 Next 全闭包实际组装仍等待来源审计/native providers，
没有运行 JavaScript 或功能用例。69084/63015/26293 本轮 session 均确认活跃。

音频 session 79074 已确认 exit 1：推进到 NumPy 2.4.3 时，新增 gfortran 输入
通过 CPLUS_INCLUDE_PATH 引入重复的标准 C++ fenv.h，include_next 无法得到 C
声明。构建脚本只过滤 gfortran 的额外 include/c++ 路径，保留 Fortran 编译器、
库及其他头，使用原生 GCC 驱动自己的标准 C++ 头；未移除 NumPy/SciPy 数值功能。
完整音频新构建 session 63015 已启动，日志
`/tmp/hermes-audio-fortran-header-isolation-build.log`，实际组合结果待确认。

Next 非 registry ci-info 已按原始 lock 固定提交 f43f6a1cefff47fb361c88cf4b943fdbcaafe540
取得源码，确认 MIT、无检测出的原生载荷，并记录内容哈希；上游 lock 未提供
integrity，认证边界如实注明。新增 `hermes-next-build-tools.scm`，固定 channel
实际构建 session 55346 exit 0，输出 fm4vkax...；保留原始 index.js、vendors.json、
元数据和许可，没有运行环境检测。完整来源及产物哈希见
`planning/hermes-next-ci-info-source.json`。Next 模块组装接入仍待完成。
来源归档审计 69084、音频 79074、Codex 26293 本轮通过 session 确认仍活跃。

Next 1795 snapshots 的固定 registry 来源认证/原生载荷审计已启动 session
69084，日志 `/tmp/hermes-next-build-node-source-audit.log`；不执行 install scripts，
非 registry ci-info 单列待认证，不能用缺失 integrity 的归档绕过来源检查。
进一步核对 taskfile 发现 next_compile 还复制 apps/bundle-analyzer/dist，而该
workspace 构建锁依赖 Next 16.0.8，不能仅用 Next 包声明闭包声称覆盖全部资源。
扫描器新增额外 asset importer，扩展清单
`planning/hermes-next-with-analyzer-node-inventory.json`；正式构建还需处理分析器
静态资源及其匹配 bootstrap 构建链，未删除分析器功能。音频 79074 和 Codex
26293 本轮 session 仍确认活跃，功能验证延后。

Next 原始 pnpm 9 来源闭包扫描已实际完成：8 个关联 workspace、1795 个
peer snapshots，包含 1 个固定提交的 ci-info 非 registry 来源，见
`planning/hermes-next-build-node-inventory.json`。新增生成脚本保留别名、workspace
路径与 optional 条件；测试/Storybook 候选仍需按 task 分类，不能把此清单当成
已源码构建全部依赖。OG 安装脚本新增原始字体 OFL/版权资源，已在独立元数据
目录实际组装；安装哈希见 `planning/hermes-next-og-layout-artifacts.json`。
没有执行 JavaScript、启动 Next 或跑功能验证，正式配方仍待完成。

新增 `scripts/install-next-source-og.py`，按固定 Next 16.1.1 原始
copy_vercel_og 任务布局安装源码 OG bundles、WASM、字体及嵌套声明，保留
edge-light/import/node/default 与 package.json exports；记录 provider 身份与
逐文件哈希。脚本拒绝版本不符及覆盖既有 OG，供独立构建源码树接入，语法解析
通过。尚未接入正式 Next 配方或构建静态导出，不据此称 Next 已完整源码构建。

最新完整 OG 构建 session 56884 已确认实际 exit 0：匹配 Emscripten 系统库、
Yoga 0.3.3（WASM/asm.js）、Satori 0.15.2 和 Vercel OG 0.7.2 均源码构建成功。
三项正式输出的逐文件大小、SHA256 和资源符号链接见
`planning/hermes-og-rendering-artifacts.json`；原始日志
`/tmp/hermes-vercel-og-emscripten-compat-headers-build.log`。
下一步为 Next 内嵌 OG 接入、dashboard 静态导出及 agent-browser CLI 组合；
独立渲染链成功不替代这些交付，功能验证仍延后。音频 79074、Codex 26293
本轮均通过实际 session 确认仍在运行，未重启或修改其构建快照。

H14/H16 新增静态来源审计脚本，实际扫描固定 Hermes skills/plugins 下 688 个
文本/Python 文件，登记逐文件 SHA256、2587 条依赖/凭据/安装说明/import/外部
调用证据，以及 85 个不能静态解析的动态调用。清单
`planning/hermes-skill-plugin-external-inventory.json`；未导入代码、执行安装命令
或运行技能。候选 imports 包括本地模块和可选依赖，不能全部当成缺包；须继续
逐项分类来源包、外部服务、平台条件和用户资源，动态调用仍待审计，不称 H14 已完成。

OG session 91697 实际 exit 1 于 Yoga 的 emmalloc 系统库：libc 已源码编译
1004 个输入，但目标 musl malloc.h 先于 Emscripten compat/malloc.h 导致 mallinfo
类型不完整。恢复原始 target include 顺序（libc++、fakesdl、compat、musl），
保留 mallinfo/emmalloc 功能，未改用其他 allocator；新完整 OG 构建启动，日志
`/tmp/hermes-vercel-og-emscripten-compat-headers-build.log`。旧 Satori 62141、
音频 79074 和 Codex 26293 本轮仍确认活跃，功能验收延后。

Acorn 与 Closure 的正式安装资源逐文件大小/SHA256、Closure jar 类库存与
typed-AST/externs/polyfills 生成资源已记录于
`planning/hermes-emscripten-js-java-artifacts.json`。这补齐独立工具产物证据，
不替代 Yoga 最终编译与功能验收。最新 Satori/OG、音频和 Codex 四个任务本轮
通过 session 62141/91697/79074/26293 确认活跃；Yoga 正在源码生成 libc 系统库。

已审计的 655 个 Satori 归档再次核对 SHA256，并通过固定 channel 的
add-to-store flat-hash API 以配方同名导入；session 36975 实际 exit 0。
全部源 store path 存在，身份见 `planning/hermes-satori-source-imports.json`，
日志 `/tmp/hermes-satori-verified-source-import.log`。来源锁生成器新增可复用
`--import-script`，同时在生成阶段和 daemon 导入阶段验证缓存，避免重复下载。
初次导入使用了该 channel 未导出的 file-sha256，已改正确 file-hash*，初次未导入。
缓存导入不算 Satori 编译成功；Satori/OG、音频和 Codex 正式构建本轮仍确认活跃。

新增 `hermes-vercel-og.scm` 与 OG 编译脚本：从固定官方归档认证恢复六份
TypeScript，仅复制源码、发布声明、许可和原始静态字体；Node/Edge bundles
由源码 esbuild 重编译，绑定源码 Satori/resvg/Yoga，WASM 从 providers 安装，
排除发布编译 JS/WASM。字体固定 OFL 及版权，渲染 provider 身份进入安装元数据。
正式构建启动 session 91697，日志 `/tmp/hermes-vercel-og-full-source-build.log`，
等待同版本 Satori/Yoga 完成。Next bundle 接入和完整功能验证仍未完成。

音频 session 96438 实际 exit 1 于 SciPy 1.18.0 缺少 Fortran compiler；Narwhals
uv_build 后端已通过，完整流水线继续推进。factory 对含 SciPy 的 source list
补入固定 channel gfortran native input，保留源码数值内核及共享 NumPy/BLAS；
新完整音频构建启动，日志 `/tmp/hermes-audio-scipy-fortran-build.log`。
旧 Yoga session 59588 亦实际 exit 1 于旧 Binaryen 快照；新 Satori/Yoga 62141 与
Codex SDK 26293 本轮仍确认活跃。功能验证延后。

Yoga 的目标头修正使自身 C++ 编译推进到 embind 系统库生成；session 12649
实际 exit 1，因为上游内部库编译清除 EMCC_CFLAGS，继而无法找到 bind.h。
专用 LLVM 工具目录改为 Clang shell 入口，按 EM_CACHE/匹配默认缓存固定目标
musl/libc++ include，保留 Clang builtin headers，使内部库和应用使用同一源码
sysroot。完整新构建已启动 session 62141，日志
`/tmp/hermes-satori-yoga-clang-target-wrapper-build.log`。
OG 默认字体从已认证发布资源核对为 Noto Sans Regular 2.007，保留原始字形，
TTF 名称表含 Google 2015–2021 版权和 OFL URL；官方 Noto OFL 文本固定至仓库
提交，资源身份/许可来源见 `planning/hermes-vercel-og-font-source.json`。
此字体按静态数据资源登记，程序 JS/WASM 仍分别源码重建，尚未安装到最终 OG。

Satori/Yoga session 82267 与旧 81864 均实际 exit 1；清除环境 include 后，
Guix Clang 的内置绝对 glibc include 仍造成 wasm32 编译请求宿主 stubs-32.h。
Yoga 源构建显式使用 -nostdlibinc 保留 Clang builtins，并指定私有源码 sysroot 的
musl/libc++ include，防止宿主标准头回流；未删 Yoga 算法或降低功能。
新完整构建启动，日志 `/tmp/hermes-satori-yoga-target-headers-build.log`。

修正版 Binaryen 111 与 Emscripten 3.1.31 正式构建均成功；Yoga session 41142
实际 exit 1 于宿主 GCC 的 cstdint/bits/c++config.h 被误用于 wasm32 编译，
不是 Yoga 功能缺失。构建脚本清除 native GNU 环境的 CPATH/C_INCLUDE_PATH/
CPLUS_INCLUDE_PATH/OBJC_INCLUDE_PATH/LIBRARY_PATH，仅使用 Emscripten 源码
sysroot；启动完整 Satori/Yoga 新快照构建，日志
`/tmp/hermes-satori-yoga-private-sysroot-build.log`。原 session 81864 使用旧
快照，结果另行确认，不修改正在运行的构建目录。

新增正式 `hermes-satori.scm`：独立 build-modules 配方组装固定 655 归档和四个
完整源码 providers，检查 peer/必需依赖，不依赖临时 npm 缓存；Satori 本体使用
原始 TypeScript 与 tsup 配置生成 default/WASM、ESM/CJS、声明和资源，保留源构建
依赖闭包。实际完整构建已启动 session 81864，日志
`/tmp/hermes-satori-full-source-build.log`，等待 Yoga 及固定来源输入。
最终 Next 发布 runtime 图与 OG bundle 接入仍待完成，不以此配方定义代替构建成功。

source-map 修正版双版本 session 12688 实际 exit 0：0.7.4 输出 dx4csl1...、
0.8beta 输出 bhw8vg8...，完整 store 身份、安装资源及哈希见
`planning/hermes-source-map-provider-artifacts.json`，功能仍未验证。
新增 Satori Guix 来源锁生成器，实际生成 655 个准确 registry origins，四个
原生/WASM 包由独立源码 provider 代替。组装器新增 identity/store-path TSV 输入，
正式模式要求每个所需归档都有固定输入，不回退至审计时的临时下载目录。
旧 Emscripten session 30793 实际 exit 1 于旧 Binaryen；修正版 Yoga 41142、
旧 Yoga 59588、音频 96438、Codex SDK 26293 本轮仍确认运行。

source-map 双版本首次构建 session 54200 实际 exit 1：0.7.4 编译成功，
0.8beta 缺少 Node url external；进一步核对发现浏览器构建应遵循原始 package
browser 映射。改为 browser 平台并固定 Satori 锁中的 WHATWG URL 7.1.0 与四个
纯 JS 传递依赖，保留原始 Node 源码和类型，不用替换为简化 URL 实现。
修正版双版本构建已启动 session 12688，日志
`/tmp/hermes-source-map-browser-url-providers-build.log`；旧 0.7.4 产物不代表
修正版浏览器接口已交付。新增 Satori 构建脚本，沿用 authored tsup/plugin/dts
配置执行 default/WASM 两种 ESM/CJS 构建，固定同版本 esbuild，输出元数据记录
真实发布版本；最终发布 runtime 3.2.0 依赖图仍须另行接入，不混淆源构建 3.0.0 图。

Satori 的 React Native peer 输入已登记为仅用于构建/声明的源码输入，保留全部
JavaScript/类型文件，准确移除审计发现的十二个 Hermes SDK 二进制文件；清单
`planning/hermes-satori-build-source-removals.json` 固定归档 SHA256 和逐文件路径。
组装器仅允许有明确理由、匹配归档身份且已审计的 native 文件移除，其他原生/WASM
仍须完整源码 provider。此输入不作为可运行 React Native 包交付，不能宣称其
Hermes engine 已补齐；Satori 运行 API 范围不变。脚本语法检查通过，完整组装
仍等待 Yoga/source-map providers。现有六个构建本轮均确认活跃。

source-map 0.7.4 官方源码已取得；两份经 SHA512 核对的发布 mappings.wasm
均为 48693 bytes，SHA256 均为 be2dc7da3885e55013c8da58d7ba356705d932459db94ada37d5de2fa8733cfe，
JS 消费端要求的 export 名称集合相同，支持复用匹配源码实现，尚未声称功能通过。
新增 `hermes-source-map.scm` 两个分别固定 Git 来源的完整 provider，安装 authored
Node API、类型声明和源码生成 UMD，排除原始预编译 WASM 后接入已源码构建的
source-map-mappings 0.5.0。正式双版本构建启动 session 54200，日志
`/tmp/hermes-source-map-full-providers-build.log`；组合接入与功能验收仍待后续。

Satori 的 esbuild 0.18.10 最新正式源码构建 session 52964 实际 exit 0，
日志 `/tmp/hermes-satori-esbuild-source-build.log`，平台 provider 随编译程序安装；
此独立工具成功不替代 Satori/OG 的实际源码构建。

Satori 来源归档审计 session 99983 实际 exit 0：659 个 Linux 归档核对通过，
5 个含原生/WASM：React Native 0.72.4 的 Hermes SDK、source-map 0.7.4/0.8beta、
esbuild Linux x64 0.18.10、Yoga 0.3.3。完整身份见
`planning/hermes-satori-native-audit.json`。原始 Satori tailwind handler 明确使用
twrnc/create，React Native peer 并非直接运行时后端；保留准确 peer 身份，继续
收敛声明构建所需源文件与 SDK 二进制的处理，不能把包含预编译 SDK 的归档
未经处置作为纯源码输入。两个 source-map 版本的匹配 WASM ABI 仍须分别核对。

Satori 的 tsup 7.1.0 锁定 esbuild 0.18.10，现有 0.28.1 不能冒充同版本
Node API 配套二进制。新增 `hermes-satori-tools.scm`，固定官方 esbuild 0.18.10
与 go.mod 准确 x/sys c0bba94 源码归档，编译程序并安装同版本
@esbuild/linux-x64 provider，移除 npm 平台目录而非使用发布二进制。
实际构建启动 session 52964，日志 `/tmp/hermes-satori-esbuild-source-build.log`。
Satori 归档审计 99983、修正版 Yoga 41142、旧快照 Emscripten/Yoga 30793/59588、
音频 96438 和 Codex SDK 26293 本轮均确认仍运行；功能验证延后。

新增 Satori pnpm 6 来源清单脚本，实际锁定 681 个准确 peer snapshots，
包括全部原始 runtime 和 tsup/TypeScript/twrnc/plugin/类型声明构建依赖，
没有混入 lint/测试专用 root。清单 `planning/hermes-satori-node-inventory.json`；
原始源码 lock 的 css-to-react-native 为 3.0.0，而 Next 的已发布 runtime lock
为 3.2.0，须登记并分别匹配源构建与最终组合，不隐式声称两个 lock 相同。
来源归档完整性与 native payload 审计已启动，日志
`/tmp/hermes-satori-node-source-audit.log`，不运行安装脚本或功能用例。
模块组装脚本新增原始 pnpm 6 支持，未改 Next pnpm 9 的 peer 布局。

Satori 0.15.2 官方 gitHead b54f510807b7f5b8503e02509a83dc3ede06d317 的
原始源码已取得，归档 SHA256、八份构建/许可文件身份登记于
`planning/hermes-satori-source.json`。源码 package version 保持
0.0.0-development，发布身份由官方 registry gitHead 确认，不冒充其他源码版本。
上游 default 依赖 Yoga asm.js，WASM variant 支持外部初始化，须保留两种
ESM/CJS API；源构建还需自身 lock 的 twrnc 与 tsup transforms，不能只装
发布 runtime dependencies 就称构建闭包完整。实际源码构建与 OG 接入仍待继续。

Binaryen 111 首次正式构建实际 exit 1：GCC 14 报 src/wat-lexer.h 的
uint64_t 未定义，原始头依赖了旧编译器间接包含 cstdint。配方新增明确
`#include <cstdint>`，不改 lexer/optimizer 功能；启动修正版完整 Yoga 构建，
session 41142，日志 `/tmp/hermes-yoga-binaryen-cstdint-build.log`。此前
Emscripten/Yoga session 30793/59588 本轮仍确认运行，使用旧快照，不修改其
正在运行的源目录；它们的最终结果须单独确认，不能以修正版状态覆盖。
音频 96438 与 Codex SDK 26293 均仍活跃，功能验证延后。

@vercel/og 0.7.2 官方 registry 元数据固定 gitHead d1f4fe122ac807ded5be441b7911aab31856b61d，
对应 vercel/og codeload 归档实际 HTTP 404。官方发布包含完整 sourcesContent；
新增恢复脚本核对 SHA512，逐字提取六个 first-party TypeScript 源文件，检查
Node/Edge 共有源码一致，并保留发布类型声明和许可，不复制编译 JS 或 WASM。
实际恢复成功，身份见 `planning/hermes-vercel-og-source-recovery.json`。
匹配 satori 0.15.2、源码 resvg/Yoga providers、默认 Noto 字体资源许可及
Node/Edge bundles 的重新编译与 Next 接入仍待完成；不能称为已构建完整 OG。

新增 `assemble-agent-browser-node.py`：核对原始 pnpm lock 与两份来源清单
的身份，按准确 peer snapshots 组装独立模块目录；平台外和 musl optional
依赖明确排除，必需依赖缺失即报错。原生/WASM 包必须提供同名同版本的完整
源码 provider，不能解压发布二进制后继续构建；store provider 必须自带完整闭包，
不向 store 写依赖链接，不执行 npm install scripts。脚本语法检查通过，
实际全闭包组装尚待 Next provider 及其重建的 @vercel/og bundle。
Next 原始 taskfile 的 @vercel/og 拷贝路径已核对：必须重建匹配的 JS glue/bundle，
不能仅替换 resvg/yoga WASM。五个已启动构建本轮均通过 session 确认活跃。

新增 `hermes-yoga.scm` 和 `build-hermes-yoga.py`，固定 yoga-wasm-web 0.3.3
提交 964bd6b 与 Yoga C++ 子模块 c09405d 的原始归档及 SHA256，沿用上游
Makefile 完整 WASM/asm.js、LTO、Closure 优化参数；构建私有 C/C++ 系统库缓存。
四个 authored 模块入口以源码 esbuild 打包，保留 index/asm/node/browser API、
WASM、类型声明和两项目许可，安装为 Node provider。正式构建已启动，session
59588，日志 `/tmp/hermes-yoga-full-source-build.log`，等待对应 Emscripten/Binaryen
输入；尚未证明 Yoga 产物成功，更未接入 Next bundle 或执行功能用例。

新增 `emscripten-for-hermes-yoga` 源码工具链配方与安装脚本，固定 3.1.31
原始源码、LLVM 17、Binaryen 111、Acorn 和 Closure providers，安装原始
Python/JS 编译器、bindings 与 C/C++ 系统库源码。配置使用固定工具路径，
EM_CACHE 可指定消费者的私有可写构建目录；Yoga 消费构建中须实际编译系统库。
此变体未提供可选 HTML minifier、wasm2c 或需要下载的 ports，不能宣称完整
通用 Emscripten 工具链。实际构建启动，session 30793，日志
`/tmp/hermes-emscripten-yoga-toolchain-build.log`。LLVM 工具目录追加源码引用的
llvm-dwp、llvm-dwarfdump、llvm-strip，最新目录构建结果另见
`/tmp/hermes-llvm-17-complete-tool-directory-build.log`。Yoga WASM/asm.js 仍待构建。

已确认固定 channel 提供匹配 LLVM/Clang/LLD 17.0.6，新增
`llvm-for-hermes-emscripten` 工具目录包，为 Emscripten 的单一 LLVM_ROOT
提供 clang/clang++、llvm-ar/ranlib/nm/objcopy/readobj、wasm-ld/ld.lld，
保留各源定义包的运行闭包并在组装时检查工具存在。实际构建启动，session 2993，
日志 `/tmp/hermes-llvm-17-tool-directory-build.log`；依赖可能由 Guix substitute
取得，不能记录为本机重新编译 LLVM。Binaryen session 4372、音频 96438、
Codex SDK 26293 本轮均确认活跃。Emscripten 与 Yoga 尚未完成。

Acorn 8.7.1 修正 shebang 判断后的正式构建成功，输出
`/gnu/store/qxdrif8n2g7am2994i2nn7gkcc9rxk98-acorn-for-hermes-emscripten-8.7.1`，
日志 `/tmp/hermes-emscripten-acorn-shebang-build.log`。安装 parser 的 UMD/ESM、
原始类型声明和 CLI；Guix Node 工具链变体最低 Node 16，未宣称历史 Node 0.4 兼容。
新增 Binaryen 111 源码配方，固定官方归档 SHA256
`c518b1146713bc2406dd09a1a1b18f31a283f8ac1fe200efa38834dbd95a1997`，
保留全部生产工具、库和默认完整 DWARF，关闭测试目标及编译警告升级为错误。
实际构建已启动，session 4372，日志 `/tmp/hermes-binaryen-111-source-build.log`；
LLVM 17/Emscripten 系统库及 Yoga 接入继续待办，未开展功能验证。

Hermes integrations 和 dashboard 最新正式构建均成功，默认 graft 后输出分别为
`/gnu/store/cq6k4xwgqkjf5cf279kyysmc2xycgdz6-hermes-agent-integrations-0.21.5` 和
`/gnu/store/b6wsy2fph5givz74rakg951ygxppv7mk-hermes-dashboard-0.21.5`，日志
`/tmp/hermes-dashboard-olm-cmake-policy-build.log`。python-olm 的 CMake 修正
已通过完整组合构建；前端动态资源、完整音频后端和最终界面组合仍需继续接入。
音频 session 96438 与 Codex SDK session 26293 本轮确认仍在运行。
Acorn 的安装检查已允许 Guix 改写后的精确 Node shebang，重新启动正式构建；
首次命令遗漏 time-machine 的 `--` 分隔符，未执行构建，已更正。
所有新增组件的功能验证继续延后。

Closure Compiler v20220502 的正式源码构建已成功，日志
`/tmp/hermes-closure-compiler-seven-protos-build.log`，输出
`/gnu/store/zqxyaymwj1vb4fg0mh1mxxdxf4qsvqh4-closure-compiler-for-hermes-browser-20220502`。
构建包含七份 protocol 的 Java 生成、AutoValue 处理器、typed-AST 运行资源、
externs，以及 compiler/linter/instrumentation reporter 入口；Emscripten/Yoga 接入
仍未完成。Acorn 配方已定义，首次构建在安装阶段因 Guix 已改写源文件 shebang
而失败，须修正精确路径判断后重建，不能标为已有正式产物。
Emscripten 3.1.31 源码要求 LLVM 17 和 Binaryen 111（接受 112）；计划采用
111，版本匹配工具链、系统库和 Yoga 两种目标仍为待办。上述构建不代表功能验证。

匹配 Ant 1.10.11 正式源码构建实际 exit 0，产物及 jar hashes
已登记。Next SWC 16.1.1 最新 tracked-API 修正构建也实际 exit 0，
输出 /gnu/store/f2bvzl35i3zvvc1b6msigv1xblgv6zhg-next-swc-for-hermes-browser-16.1.1；
NAPI binding、package metadata 和 source identity 的大小及哈希
见 planning/hermes-next-native-artifacts.json。保留完整 release
features；尚未接入 Next dashboard，也未开展功能用例。
音频组合旧构建实际 exit 1 于 Narwhals 2.24.0 缺少 uv_build
backend，而非音频引擎裁剪。Narwhals 声明 >=0.11,<0.12；
加入固定 channel python-uv-build 0.11.25 的源码定义后端与其
Guix uv 依赖作为条件 native input，已启动新音频构建
/tmp/hermes-audio-uv-build-backend-build.log。原 dashboard 和
Codex SDK 本轮仍通过 session handle 确认活跃。

AutoValue 1.6 完整处理器正式 Guix 构建实际 exit 0，输出
/gnu/store/k2anp9dr7bvrdkzl1wn3gs8imlq0ppa1-java-auto-value-processor-for-hermes-closure-1.6。
全部五个 processors、Memoize extension 的六项服务注册、五个
源码模板及 NOTICE 均接入 jar；服务文件依据原始 @AutoService
注解生成，不使用预编译 bootstrap processor。依赖的 Guava
23.5-jre、AutoCommon 0.10、AutoService annotations 1.0-rc4、
ErrorProne annotations 2.0.18、J2ObjC annotations 1.1、Animal
Sniffer annotations 1.14 均已源码构建成功，产物身份登记于
Java artifacts 清单。AutoService 注解专用 jar 的编译禁用自动
processor discovery，避免 source archive 的服务描述尝试加载尚
未编译的独立处理器；不影响 AutoValue 的全部服务注册。

旧 Checker qualifier 初次源码构建实际失败于框架内部依赖。
重新审计确认 Guava 23.5 的准确 JRE 范围有 560 个 Java 源文件，
checkerframework 引用数为零；先前 1111 的计数包含 Android 副本。
该 Maven 声明依赖未用于 JRE 编译，已从此构建链移除，无任何
Guava 源码或注解被删改。JSR305 显式从无法取得 source archive 的
1.3.9 更新至源码构建的 3.0.2，版本调整已登记；整体源码编译
成功，不代表功能验证。Closure 编译须隔离 AutoValue 的旧 Guava
processor path 与 Closure 的 Guava 31.0.1 runtime classpath。
匹配 Ant 1.10.11 的原始源码已取得并定义源构建配方，沿用 Guix
source bootstrap 与 optional binary jar 删除；实际构建已启动
/tmp/hermes-closure-ant-source-build.log。Closure 本体、typed-AST
资源生成和 Emscripten/Yoga 接入仍待继续。

Closure 的 Protobuf 3.19.3 generator/C++ 库和完整 Java runtime
正式构建均实际 exit 0；Java jar 包含十二个原始 protocol 资源。
Guava 31.0.1-jre、failureaccess 1.0.1，以及源码编译的 JSR305
3.0.2、Checker qualifier 3.12.0、J2ObjC annotations 1.3、ErrorProne
annotations 2.7.1/2.3.2 均已正式构建成功；Guava 保留原始注解
及其元数据，没有用移除注解代替补依赖。累计十二个 Java jars 和
匹配 protoc 的产物 hash、布局及日志见 Java artifacts 清单。
注解 sources.jar 已核对仅含源码、没有 class/native binary。
AutoValue 1.6 的 processor 还需要 AutoCommon、AutoService 和
Guava 23.5-jre；相关源码已取得，但旧 JSR305 1.3.9 sources.jar
实际 HTTP 404，仍需查原始源码 provenance 或登记明确的源码依赖
兼容选择。旧 Checker 2.0.0 的 sources.jar 是完整仓库源码布局，
需依据其官方 checker-qual-jar target 构建，不能直接编译整个检查器。

新版 resvg 含完整 CJS/ESM/IIFE wrapper 的正式构建实际 exit 0，
输出 /gnu/store/d7g45vky3hwsg0whp27q2wl1279baf3s-resvg-wasm-for-hermes-browser-2.4.0。
六个安装资源的身份见 planning/hermes-resvg-wrapper-artifacts.json；
Next bundle 接入仍待完成。python-olm 修正的独立配置检查实际
exit 0，日志 /tmp/hermes-python-olm-cmake-policy-configure-with-make.log；
首个检查环境缺少 make，已补齐后确认配置成功，不能用此代替
完整 Python binding/dashboard 构建。功能验证均保持延后。

新增 hermes-java-tools 源码模块：RE2/J 1.3、AutoValue 1.6
annotations、Gson 2.7、JavaPoet 1.9.0 四个正式 Guix 构建均实际
exit 0，安装 jar 的 hash、class 数量、store output 和日志见
planning/hermes-closure-java-artifacts.json。七个固定源码归档及
manifest 身份见 planning/hermes-closure-java-sources.json。
Closure 的实际 protobuf_java target 对应 bazel-common 固定的
Protobuf 3.19.3 源码，不能以另一个 Maven import 的 3.7.0 代替。
已定义匹配的 protoc/C++ 库和 Java runtime 配方，前者正在编译，
后者等待同版本生成器；Java 源码及十二个 protocol 资源由原始
源码生成、编译和安装。AutoValue processor、Guava 等剩余输入、
Closure 本体、Emscripten 和 Yoga 仍待补全；未开展功能验证。

旧 resvg 正式构建实际 exit 0，输出
/gnu/store/mlqj41prfadkz2zbc2v4fr5nva2rxlvy-resvg-wasm-for-hermes-browser-2.4.0，
但该快照没有最新高层 JS wrapper。已启动新版实际构建，日志
/tmp/hermes-resvg-wasm-wrapper-guix-build.log，结果仍待确认。
dashboard 旧构建实际 exit 1 于 python-olm 3.2.16 的 bundled
libolm 请求 CMake 3.4 策略，而当前 CMake 不再支持该策略版本。
build-hermes.py 对精确上游调用添加 CMAKE_POLICY_VERSION_MINIMUM=3.5，
保留原始 bundled libolm 和 static binding；脚本语法检查通过，
新 dashboard 构建已启动 /tmp/hermes-dashboard-olm-cmake-policy-build.log。
音频、Codex SDK、Next SWC 及以上新任务本轮均通过 session handle
确认仍运行，最终组合成功尚未证明。

Closure 固定 bazel-common 82a7dd0f4cd8593fdaa40d65a1fa820b14ff3493
源码已取得，明确 Guava 31.0.1-jre、failureaccess 1.0.1、AutoValue
1.6、ErrorProne annotations 2.3.2、JSR305 3.0.1；版本和来源哈希
已登记。固定 channel args4j 2.33 与上游一致，其他源码配方需匹配。
已启动取得缺少的 RE2/J 1.3 与 AutoValue 1.6 原始源码；Maven
binary hashes 仅作发布 provenance，不作为源码构建输入。
原 resvg/音频/SDK/dashboard/Next 五个任务本轮确认仍活跃。

正式 wasm-bindgen CLI Guix 构建实际 exit 0，全部三个安装程序
的 store output 和 SHA256 已记录于 CLI source 清单，日志
/tmp/hermes-wasm-bindgen-cli-guix-build.log。未运行 test runner
或功能测试。旧 resvg 快照继续构建，含 wrapper 的新版仍待实际构建。
Closure BUILD/WORKSPACE 已核对运行所需 args4j、Gson、Guava/
failureaccess、protobuf、RE2/J、AutoValue、ErrorProne/JSR305 和 Ant；
固定 channel 已有其中若干源码配方，版本匹配和源码生成步骤待继续。

Acorn 8.7.1 精确提交与 Closure Compiler v20220502 原始源码归档
均取得成功，归档 root、Acorn version 和官方构建 manifests 已核对，
SHA256 与输入状态写入 WASM toolchain 清单。Acorn 上游构建使用
Rollup/Buble 生成 UMD/ESM 及 CLI；Closure 使用 Bazel WORKSPACE，
Java/annotation/protobuf 等来源闭包仍须审计后源码构建。没有使用
预编译 JAR，工具链配方及 Yoga 实际产物仍未完成。
原六个正式组件/组合构建本轮均确认活跃。

resvg 最新含 wrapper 的 derivation 检查实际 exit 0，
/gnu/store/nv9hr0dgm8bn3qa11y125kk644hiagrl-resvg-wasm-for-hermes-browser-2.4.0.drv。
旧 resvg 快照及正式 CLI、音频/SDK/dashboard/Next 本轮均确认仍活跃。
开始取得 Yoga/Emscripten 使用的 Closure Compiler v20220502 原始
Java 源码，并查询 Acorn 8.7.1 的官方发布 provenance。对应工具链
来源锁、原生/Java 构建与 Yoga 实际 WASM 编译仍待完成，不用 npm
预编译 JAR 或 emsdk 二进制作为补全。

resvg 最新配方接入原始 wasm-binding.ts，使用源码 esbuild 对匹配
新 Web glue 生成 CJS/ESM/IIFE wrappers，连同源码 WASM、原始
package metadata/type declarations 安装为 @resvg/resvg-wasm provider。
独立源码 wrapper 的 ESM 编译实际成功，最新版 derivation 检查
已启动；原活跃 resvg 构建快照未包含该新增步骤，未原地修改。
最新版整体构建及 Next bundle 资源接入待继续，未运行 SVG 功能用例。

resvg 固定归档独立 vendor 的 locked metadata 检查已实际 exit 0。
新增 resvg-wasm-for-hermes-browser 正式配方，固定 119 registry 与
六个 Git packages，复用私有 indexed WASM sysroot，源码编译后用
匹配 CLI 生成 Web/Node glue。实际 Guix 构建已启动
/tmp/hermes-resvg-wasm-guix-build.log，等待正式 CLI 输入完成。
高层 resvg JS wrapper 和 Next 编译 bundle 仍须另行接入，不以
原始 glue 安装代替完整浏览器交付。其他五个原任务本轮确认活跃。

新增 prepare-resvg-wasm.py，从固定 Cargo.lock、119 registry 归档
和精确 resvg Git 归档独立重建 vendor，检查六个 Git package 的原始/
normalized manifest 身份；不需要临时 Git cache。独立准备实际成功，
locked offline metadata 检查已启动，正式 resvg Guix 配方待接入。
正式 CLI 和音频/SDK/dashboard/Next 本轮均确认仍运行。

wasm-bindgen CLI 独立源码编译实际 exit 0，全部三个程序身份已
记录于 CLI 清单。用该匹配生成器处理源码 resvg_js.wasm 的 Web
glue 构建实际 exit 0，JavaScript/WASM/类型文件的 hash 与大小
已记录；未实例化引擎或运行 SVG 功能用例。
保留 resvg Git packages 的 Cargo-normalized manifests 及原始
归档 manifest 身份，以便正式配方独立重建 vendor。正式 CLI
Guix 构建仍运行，resvg 正式配方及 Next 资源接入仍待完成。

固定归档独立重建的 CLI vendor locked metadata 检查实际 exit 0，
不依赖临时 Git cache。新增 hermes-wasm-tools 模块的
wasm-bindgen-cli-for-hermes-browser 0.2.129 正式配方，接入 scope、
registry/Tokio vendor 和 mio replacement 准备脚本，离线编译并
安装全部三个 CLI 程序。实际 Guix 构建已启动
/tmp/hermes-wasm-bindgen-cli-guix-build.log，结果待确认。
原 CLI 预编译及音频/SDK/dashboard/Next 本轮均确认仍运行。

新增 prepare-wasm-bindgen-vendor.py，从 scoped lock 和已校验归档
重建 279 registry 及精确 Tokio Git directory source，核对原始和
Cargo-normalized manifest 的 SHA256；不需要临时 Cargo Git cache。
独立准备实际成功，再接入固定 mio source replacement，离线 locked
metadata 检查已启动。正式 Guix CLI 配方及实际完整构建仍待完成；
运行中 CLI 源码编译和四个原组合任务本轮确认仍活跃，未原地修改。

保留 cargo vendor 为 Tokio 生成的 normalized Cargo.toml 于
planning/wasm-bindgen-cli-tokio-Cargo.toml；原 Cargo Git checkout
manifest 与精确 Git 归档逐字一致，版本/包名及两个 manifest 哈希
已登记。用于正式离线配方从固定归档重建 Git directory source，
不是复制二进制或更换 Tokio 来源；完整准备脚本仍待接入。
CLI 编译及四个原组合任务本轮均确认仍运行。

显式 mio source replacement 的 CLI 编译本轮确认仍活跃，已进入
registry Rust crate 编译，不再停止于 Git 来源发现。新增
prepare-wasm-bindgen-mio.py，严格检查 archive SHA256、精确提交
根目录与 package identity，生成 Cargo file checksums 并追加原
Git URL/tag 的 directory replacement。独立脚本准备实际成功，
未修改活跃编译副本；来源身份已登记。正式 CLI Guix 配方接入及
最终构建仍待继续，其余音频/SDK/dashboard/Next 任务均确认活跃。

已将固定 mio 0788dbb67883cb6191503af999471def54e3fb77 归档
解包为独立 directory source，生成 file checksums、package=null，
按原 Git URL/tag 提供显式 source replacement，未删除 unused patch。
新 CLI 离线编译已启动 /tmp/hermes-wasm-bindgen-cli-fixed-mio-build.log，
结果及正式准备脚本收录待继续。其余四个组合构建本轮确认仍活跃。

复制 Git cache 后的 CLI 重试也已 exit 101 于相同 unused mio 来源
发现；临时 cache 复制未解决问题。下一步需从已固定的 mio 归档
提供明确 source replacement 或 path 接入，保留完整来源身份，不能
继续重复同一缓存方案。此阻碍只影响 CLI 来源发现，其他包构建仍活跃。

新增 scope-wasm-bindgen-cli.py，将临时 CLI workspace 收录为显式
准备步骤：检查版本、三个 bins、默认 rustls-tls feature 和 scoped
lock 身份为完整认证 lock 的子集，只改 workspace members，写入
固定 scoped lock。脚本语法检查通过，正式配方接入仍待完成。

CLI 首次离线编译已 exit 101 于未缓存 patch.unused 的 mio Git
来源，尚未编译运行程序。scoped Cargo.lock 明确记录该未使用 patch；
完整来源已核验过精确 mio 提交，原私有 Cargo cache 也有 checkout。
将其 Git cache 复制到独立 offline-home，保留上游 patch 后继续
离线编译 /tmp/hermes-wasm-bindgen-cli-unused-patch-build.log。
正式配方仍须从固定归档复现这种来源发现，不把临时缓存当最终交付。
音频/SDK/dashboard/Next 本轮再次确认仍运行。

独立 wasm-bindgen CLI workspace 来源解析及 cargo vendor 均实际
exit 0，279 registry 来源和一个精确 tokio Git 来源；身份/版本/
checksum 对比证明它们全部为已核验完整 workspace 锁的子集，没有
新增或改变外部来源。仓库保留 scoped Cargo.lock 和 metadata。
三个 CLI binaries 与默认功能保留，实际离线 release 编译已启动
/tmp/hermes-wasm-bindgen-cli-native-build.log。正式包、resvg glue
及最终 Next 接入仍待继续；音频/SDK/dashboard/Next 本轮确认仍运行。

wasm-bindgen CLI 全部 412 registry/4 Git 来源已实际校验并生成锁。
cargo vendor 任务实际 exit 101：原始完整 workspace 开发示例同时
依赖 registry 与 Git 的 libc 0.2.190，Cargo 不允许同版本双来源
vendor。保留原完整锁和源码，在独立 cli-source 副本将 workspace
members 限为 crates/cli，保留三个 CLI bins、默认功能、path 依赖
和 Git patches，启动相应来源解析
/tmp/hermes-wasm-bindgen-cli-scoped-lock.log；未裁掉运行目标。
原四个实际包组合构建本轮确认活跃。

V8 原生 outer-link-group 任务实际 exit 0，日志
/tmp/codex-v8-native-link-group-preflight.log 结束于 librusty_v8.a 生成。
这证明原生引擎预编译成功，不代替正式 code-mode host 或 Codex 完整
组合构建；SDK 输入构建本轮仍活跃。
Next 最新任务已 exit 1 于 include_dir_macros 0.7.3 的旧 nightly
tracked_env/tracked_path/track_path API。按 Rust 官方 proc_macro::tracked
接口迁移，保留环境与文件依赖追踪；独立 proc-macro metadata 编译
已确认 Rust 1.95 接受新 API。新增 patch-next-vendor.py，在来源校验
后补丁 src/lib.rs 并更新 vendor file checksum，保留原始来源 hash。
补丁纳入 patched-source identity，构建脚本语法检查通过。新版正式
构建已启动 /tmp/hermes-next-swc-tracked-api-build.log，结果待确认。
音频/dashboard/SDK 任务和 CLI 来源校验本轮均确认仍运行。

resvg 离线 release WASM 预编译实际 exit 0，日志
/tmp/hermes-resvg-wasm-native-build.log。原始 resvg_js.wasm 的 header、
大小与 SHA256 已记录于 resvg source 清单；它尚未经过 wasm-bindgen
处理，不能直接替换 Next 内嵌 wasm 或视为可用资源交付。
新增 lock-wasm-bindgen-cli.py，核对归档身份、原始 manifests、仓库
Cargo.lock 和精确 Git 列表，按 checksum 取得 412 registry 及 4 Git
来源并生成 Guix origins。脚本语法检查通过，实际任务已启动
/tmp/hermes-wasm-bindgen-cli-source-inputs.log。正式 CLI、glue 和
resvg Guix 包安装仍待完成；其余五个构建任务本轮确认仍运行。

wasm-bindgen 原始完整 workspace 的来源解析实际 exit 0，仓库保留
planning/wasm-bindgen-cli-Cargo.lock，registry 数量、精确 Git 来源与
锁 SHA256 已登记于 CLI source 清单。未删除 examples 或 Git patches，
CLI 来源归档校验、离线编译和实际 resvg glue 生成仍待完成。

wasm-bindgen 0.2.129 原始源码版本和 SHA256 已核对，记录于
planning/hermes-wasm-bindgen-cli-source.json。独立原始 workspace
Cargo 来源解析已启动 /tmp/hermes-wasm-bindgen-cli-lock.log，包含
上游 Git patch 和 examples 开发来源，实际 CLI 输入闭包仍需审计。
该活跃来源副本未原地修改；CLI 仅需的开发范围可另建审计副本收敛，
但不能删去其运行目标或实际依赖。resvg 预编译已进入 usvg 和
wasm-bindgen-macro-support 编译，尚未成功；其余五个任务本轮确认活跃。

resvg cargo vendor 实际 exit 0，registry 与 Git 来源均以离线 config
接入；已启动实际 release WASM 预编译
/tmp/hermes-resvg-wasm-native-build.log，复用已补索引的独立 Rust 1.93
WASM sysroot。匹配 wasm-bindgen 0.2.129 源码下载也已完成，但其
归档无 Cargo.lock，CLI 依赖闭包仍需另行固定。引擎和 glue 未交付。

resvg 来源锁实际 exit 0，119 registry archives 全部通过 Cargo
checksum，精确 zimond/resvg 6201182cc109d45eb3596e81dede60783592db90
归档已锁为 Guix origin。已将核验归档放入独立 Cargo cache，并启动
cargo vendor --offline --locked，日志 /tmp/hermes-resvg-wasm-vendor.log，
以 Cargo 标准 vendor 保留 Git 工作区 metadata，不在线重新解析。
锁中 wasm-bindgen 为 0.2.129，已启动取得对应 CLI 源码；固定 channel
提供的 0.2.120 不能直接代替匹配 glue 生成器。WASM 编译、CLI 来源闭包
与 Next 接入仍待完成。音频最新版、SDK、V8、dashboard 和 Next 原
任务本轮均确认仍运行。

完整音频旧任务已 exit 1：sounddevice 0.5.5 源码实际位于
src/sounddevice.py，构建脚本误查根目录。已按实际来源修正路径并
确认 PortAudio discovery 锚点，最新音频组合重建已启动
/tmp/hermes-audio-sounddevice-source-layout-build.log，结果待确认。
新增 lock-resvg-wasm.py，核对原始源码 manifests/build.rs 与已登记
Cargo.lock，拒绝额外 Git/path 来源，按 119 个 Cargo checksum 取得
registry 来源并锁定 zimond/resvg 精确提交。来源任务已启动
/tmp/hermes-resvg-wasm-source-inputs.log；源码编译及匹配 glue 仍待完成。
其余四个原构建任务本轮确认仍运行。

source-map WASM 最新正式 Guix 构建实际 exit 0，产物
/gnu/store/ilmqgln991kx63d7inw48lia5z7ggsr3-source-map-wasm-for-hermes-browser-0.5.0。
安装 mappings.wasm 312052 bytes，WASM header、来源哈希和许可安装
已检查，记录于 WASM 清单；未加载或调用 WASM，JavaScript ABI 和
Next dashboard 最终接入仍待完成。
resvg 发布归档没有 Cargo.lock，已在独立副本启动构建外依赖解析，
日志 /tmp/hermes-resvg-wasm-lock-build.log，并查询 zimond/resvg
6201182c 对应完整提交。匹配 wasm-bindgen CLI/glue 和所有源码输入
仍须锁定，不能直接使用发布归档里的 wasm/index_bg.wasm。
其余五个原构建任务本轮确认仍运行。

source-map 正式旧构建已 exit 1 于相同归档索引缺失。独立私有
sysroot 副本先使目录和文件可写，再以 LLVM 23 llvm-ranlib 生成
所有 .rlib 索引；不改原 store。随后离线 release WASM 编译实际
exit 0，日志 /tmp/hermes-source-map-wasm-indexed-build.log。
正式配方已收录该索引步骤，最新 Guix 构建已启动
/tmp/hermes-source-map-wasm-indexed-guix-build.log，Binaryen 优化和
安装仍待确认；ABI/JavaScript 接入和功能未验证。

source-map WASM 独立预编译已实际 exit 101 于链接：固定 channel
WASM sysroot 的 .rlib 无 archive index，wasm-ld 提示需 ranlib。
后续需在独立可写 sysroot 副本中生成索引并固化为可复现构建步骤，
不修改原 store 输入。已启动的正式配方快照尚未包含此适配，不作为
最新版成功证据，仍须等待其终止或结果后再处理。

新增 hermes-browser-wasm 模块和 source-map-wasm-for-hermes-browser
正式 Guix 配方：锁定原始实现、10 个 crate、仓库 Cargo.lock 和 Rust
1.93/WASM sysroot，离线 release 编译并用 Binaryen 优化完整模块，
安装 share/source-map/mappings.wasm。保留 panic 代码，未采用上游
可选 snip 尺寸优化；不使用 npm WASM 载荷。实际构建已启动
/tmp/hermes-source-map-wasm-guix-build.log，独立预编译结果见后续记录。
最终构建及 JavaScript ABI/resource 接入未确认，不能视为已完成。

source-map WASM 来源锁实际 exit 0：10 个 registry crate 和本地 path
源码已固定，Cargo 之前的“11 packages”包含新增 path package，不能
将其当作 11 个 registry 来源。仓库保留 planning/source-map-wasm-Cargo.lock
和 source-map-wasm-lock.scm，锁 SHA256 为
d1618a0d68e5b10ea6577d06bc581b7c77967950aace5b5434be4328b53a50e3。
新增 prepare-source-map-wasm.py，实际完成 crate checksum 核对、vendor
和离线 Cargo config；已启动 Rust 1.93/WASM sysroot/lld-17 的离线
源码预编译 /tmp/hermes-source-map-wasm-native-build.log。最终 WASM
产物、后处理、JS ABI 与正式 Guix 配方接入仍待确认，不提前运行功能用例。
其余五个构建句柄本轮确认仍运行。

source-map WASM Cargo 解析实际 exit 0，固定 11 个兼容依赖，日志
/tmp/hermes-source-map-wasm-lock-ca-build.log。前轮因 Cargo 未自动发现
CA 文件已 exit 101，显式指定 Guix 环境 CA 后解决，未关闭 TLS 校验。
新增 lock-source-map-wasm.py，核对来源归档与原始 manifests、拒绝
未审计 Git/path 来源、按 Cargo SHA256 下载每个 crate，再保留仓库
Cargo.lock 并生成 Guix origins；实际来源锁任务已启动，日志
/tmp/hermes-source-map-wasm-source-inputs.log。此为依赖解析成功，
不代表 WASM 编译、优化或最终接入成功。

source-map-mappings 0.5.0 归档内部包含 Rust WASM API 和 build.py，
没有 Cargo.lock；主库要求 rand 0.4.1、vlq 0.5.1，WASM crate 以 path
依赖该源码。已在独立副本启动构建外 Cargo 来源解析，匹配 Rust 1.93，
日志 /tmp/hermes-source-map-wasm-lock-nss.log。前两轮因证书包模块
误写 tls/certs 已确认停止，查阅固定 channel 源码后改为 nss 并重启；
尚无成功锁或 WASM 产物证据。
嵌套来源 SHA256、构建入口和四个后处理工具已记录于 WASM 清单。
原五个重型任务本轮均确认仍运行，源码来源锁不替代实际组件构建。

source-map 发布对应的 lib/mappings.wasm 更新提交
4ade41fd99eaea69f3f3bef7e7857a29da02a9d4 明确命名
fitzgen/source-map-mappings 0.5.0；官方 tag 解析到
197660faf3dd1167c643797a5ed62cb687482c54，已启动下载精确 Rust 来源。
来源链已记录于 WASM 清单，构建与 ABI/glue 接入尚未完成。
Emscripten 来源要求 LLVM major 17、Acorn ^8.7.1、Closure Compiler
20220502.0.0 等依赖，已记录于工具链清单，Binaryen 兼容版本和
完整离线工具链配方待继续。本轮五个现有构建任务均确认仍运行。

Rust WASM sysroot 任务实际 exit 0，取得固定 channel 1.93.0 的 Guix
substitute /gnu/store/hf056yqnshwk5qxwklc8r5kr1fv8ld0m-rust-sysroot-for-wasm32-unknown-unknown-1.93.0，
不是本地编译成功记录；来源由固定 channel 配方定义，后续须用 Rust 1.93
匹配。Emscripten 3.1.31 来源下载完成，归档内部版本已核对，SHA256
与工具链状态已记录于 planning/hermes-browser-wasm-toolchain.json。
工具链配方及三个 WASM 实际源码产物仍待完成。

本轮音频、Codex SDK/V8、dashboard system-sodium 和最新 Next 正式
构建句柄均确认仍运行，未因观察超时重新启动。固定 channel 提供
rust-sysroot-for-wasm32-unknown-unknown 源码包，已启动实际构建，日志
/tmp/hermes-browser-rust-wasm-sysroot-build.log；最终 WASM 构建需使用
与此 sysroot 匹配的 Rust 版本，不能默认混用 Next 的 Rust 1.95。
Yoga 0.3.3 官方 CI 固定 Emscripten 3.1.31，已开始取得对应源码；
固定 channel 没有 Emscripten 工具链包，需要本仓库补齐配方、源码
sysroot、LLVM/Binaryen 与生成 JavaScript glue，不能使用 emsdk 下载二进制。
source-map-mappings 已开始查询官方源码历史，具体发布对应提交仍未确认。

Next 最新兼容预编译已 exit 101：显式 as_mut 后仍没有旧 nightly
downcast_mut_unchecked API；生命周期修订未再次报错。改用稳定
downcast_mut().expect，保留 TypeId 键对应类型的不变量，类型错误从
原来的未定义行为变为明确失败。补丁脚本锚点仍严格检查两处原源码。
旧正式 Next 构建也已确认 exit 1 于同样的原始 Rust 错误，现启动包含
稳定 downcast、生命周期及 metadata identity 修订的最新正式源码构建，
日志 /tmp/hermes-next-swc-stable-downcast-build.log，完整 release feature
保留，最终结果待确认。原预编译已停止，未重复启动同一快照。

dashboard 构建 /tmp/hermes-dashboard-config-shell-build.log 已确认 exit 1，
PyNaCl 1.6.2 内置 libsodium 来源缺 configure。私有 Python 构建改用
上游 SODIUM_INSTALL=system 模式，先检查 pkg-config libsodium；工厂按
选定 pynacl 增加源码 libsodium 输入，不依赖有无 Git 来源偶然获得该库。
最新重建已启动 /tmp/hermes-dashboard-system-sodium-build.log，结果待确认。

新增 patch-next-rust.py，对两处 downcast 明确选择底层 dyn Any，对
scoped FnOnce 的生命周期擦除使用显式 transmute。沿用上游 Scope 的
强制 drop/等待所有任务不变量，未去掉 Turbopack 或其他 release feature。
参考 Rust 官方迁移说明 https://github.com/rust-lang/rust/issues/141402。
准备脚本显式接收补丁文件并纳入 patched-source identity；三个 Python
构建脚本语法检查通过，最新版 derivation 检查及已终止副本的增量预编译
已启动。日志 /tmp/hermes-next-swc-rust-compat-preflight-build.log；独立
编译和正式新版完整产物仍待确认，旧正式任务未原地修改。
Yoga C++ 子模块 c09405d58c624fd26d5e0a7ed98bd10c5cc4c05b 源码已取得，
归档 SHA256 已记录于 WASM 来源清单，Emscripten 和实际 WASM 构建待继续。

Next SWC 原生预编译 /tmp/hermes-next-swc-gcc-preflight-build.log 已终止
exit 101：Rust 1.95 不再接受 turbo-tasks 的两个 downcast_mut_unchecked
调用和 scope.rs 的 trait-object 生命周期 raw cast。完整 feature 集合未删减；
需要对应源码适配或匹配工具链，未将此预编译视为成功。
其余音频、SDK、dashboard、V8 和正式 Next 构建句柄本轮均确认仍运行。

三个 Next WASM 对应源码归档均已取得并校验 package version，SHA256
及构建前置项已写入 planning/hermes-next-wasm-source-metadata.json。
Yoga 0.3.3 实际 tag 不带 v，固定提交为
964bd6b7c5f30f4d5cbb50ec7ea51afa429ce541；Git tree 已确定 Yoga 子模块
精确提交，归档仍待取得。resvg 需要 Rust wasm target、Git resvg 来源及
匹配 wasm-bindgen；source-map 归档只有预编译 mappings.wasm，官方
CONTRIBUTING 指向独立 source-map-mappings 源码，仍需追溯对应版本。
没有复制上述预编译 WASM，实际源码产物及生成 JavaScript glue 尚未交付。

Sharp 最新本地构建布局已实际构建成功，日志
/tmp/hermes-browser-sharp-local-layout-build.log，默认 graft 产物
/gnu/store/h4cpd8k66bphxd4ys9m6hgc4pryx7mgn-sharp-binding-for-hermes-browser-0.34.5。
该记录仅更新独立组件构建状态，浏览器 dashboard 的最终接入与功能验证仍未完成。

libvips 8.17.3 与旧布局 Sharp binding 均实际构建成功：
/gnu/store/0rwd43l51ar3ngaqjz1wgxm3fardw1cg-vips-for-hermes-browser-8.17.3，
/gnu/store/09lx6a5vllfdgm5yn1mln4j0b2pli1xz-sharp-binding-for-hermes-browser-0.34.5。
binding/许可证安装文件已检查，未加载 Node binding 或运行图像测试。
Sharp 最新本地构建布局 derivation 检查已通过，并启动重建
/tmp/hermes-browser-sharp-local-layout-build.log，旧布局不作为新版完成证据。
Next lock 指向 source-map 0.8.0-beta.0、resvg-wasm 2.4.0、yoga-wasm-web
0.3.3，已记录官方发布元数据到 planning/hermes-next-wasm-source-metadata.json，
对应源码与 WASM 构建仍待继续。

oxide 4.2.2 实际构建 exit 0，产物
/gnu/store/l9zw9qgh0sv79pj5fdjbi4a35760s097-tailwind-oxide-for-hermes-browser-4.2.2。
Sharp 上游 @img 入口会执行预编译包的 x64-v2 限制，源码 binding 不应
因此拒绝 generic x86_64。配方增加原 JavaScript lib/package metadata 与
src/build/Release/sharp-linux-x64.node 本地源码构建布局，供前端选择该
provider，使用上游已有本地加载路径，不改 CPU 检查或 JavaScript 行为。
正在运行 Sharp 旧快照未含新安装布局，最终新布局构建及接入仍待完成。

新增 sharp-binding-for-hermes-browser：锁定 Sharp 0.34.5 原始 C++ 来源，
使用满足 ^8.5.0 的已有锁定 node-addon-api 8.9.0，按 Linux binding.gyp
的七个源文件、C++17/异常及 NAPI 宏编译，链接源码 libvips 的 pkg-config
输入，安装 @img/sharp-linux-x64/sharp.node。默认 JavaScript 来源仍单独
锁定，不复制 npm libvips 或运行 install 脚本。固定 channel derivation
检查已启动，实际构建 /tmp/hermes-browser-sharp-build.log 已启动，最终
编译与 Node 包发现路径仍待确认。原有构建会话本轮均确认仍运行。

libvips 8.17.3 源码已取得，SHA256
c1180d13f33742685c513ac42c0556dd1ce9e2b79cdb248a807576e2d8b63b32。
新增 vips-for-hermes-browser，继承固定 channel vips 的 Meson 配方和输入，
替换精确版本来源，实际构建已启动 /tmp/hermes-browser-vips-build.log。
格式支持及源码适配需最终构建确认；Sharp 绑定仍待编译接入。

Sharp 0.34.5 的 package config 要求 libvips >=8.17.3，而固定 channel 的
vips 为 8.17.0。源码 binding.gyp 支持 use_global_libvips 与 SHARP_USE_GLOBAL_LIBVIPS，
因此需本仓库提供匹配 libvips 源码包，再编译 Sharp C++ binding，不能
复用 npm @img/sharp-libvips 的共享库。开始取得官方 v8.17.3 源码，配方及
匹配 binding 构建仍待完成；其他原会话本轮均确认仍运行。

oxide 4.2.2 来源锁实际完成，90 个 registry 来源已校验。新增独立
hermes-browser-native 模块的 tailwind-oxide-for-hermes-browser，复用导出的
native-binding 工厂；匹配版本实际构建已启动，日志
/tmp/hermes-browser-oxide-build.log。此前 locker 的根目录/tag 校验为锁定
任务启动后的修订，90 来源任务快照未含该检查；归档根目录先前已直接核对。
最终 binding 产物和 dashboard 接入仍待完成。

Tailwind oxide 4.2.2 官方源码已取得，SHA256
b8ff36e8115f56883638d593563418ee279be9f8304107add89f79d9cbf5b147。
现有 native locker 扩展显式 component/version/module 参数，保留默认旧定义，
增加 codeload 根目录与 tag 匹配检查；独立 browser 来源锁任务已启动，日志
/tmp/hermes-browser-oxide-source-lock.log。新匹配版本包及实际构建待继续，
不能直接用 4.3.3 绑定替换锁中的 4.2.2。其他原构建会话本轮均确认仍运行。

Next 固定元数据版本的 derivation 已检查通过。进一步将实际 rustc verbose
版本、完整 feature 集合、target 和 release profile 覆盖值纳入 patched-source
身份，并记录到 source-identity.json；配方用同一特性变量供准备和编译，
避免身份与实际构建分离。修改后脚本语法检查通过，最新 derivation 重查。
仍运行旧快照的预编译已至 swc_ecma_ast 等 crate，正式构建仍取得输入；
这些任务不含最新元数据修订，不作为最新版完成证据，未中止或原地修改。

官方 annotated tag v16.1.1 已解析到提交
3aa53984e9d6bc4b5860c76e90cccfd6780989af，身份记录于 Next inventory。
准备脚本现在用提交、补丁脚本、配置与锁定输入生成独立 patched-source
identity，替代 archive 缺 .git 的强制 vergen 仓库检查；保留 dirty=true，
安装 source-identity.json，不伪造 clean 仓库。配方设置与发行流程一致的
CI=1，上游 cache 判断因而仍能使用持久缓存及独立身份；没有删去缓存代码。
脚本语法检查通过，最新版 derivation 检查已启动，实际构建证据待取得。
仍运行的旧预编译和 Guix 快照未原地修改，不算含此修订的完成证据。

正式 Next SWC Guix 构建已启动，日志 /tmp/hermes-next-swc-guix-build.log，
--cores=1/--max-silent-time=7200，原生预编译及其他重型任务仍确认运行。
源码另发现 napi/build.rs 的 vergen fail_on_error 强制检查 Git worktree，
仅环境覆盖无法绕过源码归档缺 .git；正在解析官方 v16.1.1 annotated tag
精确提交，以固定元数据取代构建时仓库检查。打包补丁修改源码的 dirty
状态必须如实记录，不能生成假仓库或假 clean 状态；适配尚未接入。

新增 hermes-next-native.scm 的 next-swc-for-hermes-browser，使用固定官方
来源锁和离线准备脚本，保留 release plugin/image/tracing，安装匹配版本
@next/swc-linux-x64-gnu .node binding 和许可证。准备脚本 Git path 修改
明确跳过 registry vendor，避免 Guix work 位于源码树内时破坏已生成
checksum。固定 channel derivation 检查已启动；实际预编译继续 Rust
基础 crate 编译，最终原生 binding 尚未成功，正式配方实际构建仍待启动。
音频已导入六个原生分发并进入私有 Python 组合构建，仍不是组合成功证据。

Next 链接器修订编译已终止于缺默认 cc；加入完整 GCC toolchain，显式设置
CC/CXX 与 Cargo target gcc linker 后继续，日志
/tmp/hermes-next-swc-gcc-preflight-build.log。线程与 Linux linker 的精确锚点
修订已收录 prepare-next-native.py，以便后续 Guix 配方复现；不是功能删减。
旧 Codex host 快照 /tmp/codex-v8-profiler-copy-build.log 已实际 exit 1 于
V8 Ninja 阶段，该快照未含后来 outer rescan 修订；当前 SDK 输入及 V8 原生
任务仍运行，旧失败不能证明最新修订成败，详细失败位置正在核对。

Next 首次原生编译已实际 exit 101，Guix Rust sysroot 不带上游所请求的
self-contained linker。独立副本 Linux 配置改用 Guix GNU cc linker，关闭
该内置 linker 请求，保留功能特性及其他 nightly 参数后重新编译，日志
/tmp/hermes-next-swc-guix-linker-preflight-build.log。此为工具链路径适配，
最终动态库尚未成功；对应可复现准备脚本仍需收录该修订。

Next SWC 已启动实际源码预编译，日志
/tmp/hermes-next-swc-native-preflight-build.log，显式固定 channels 的 Rust
1.95/Cargo、Clang、NASM、CMake 等环境，保留完整 release 特性集合。
RUSTC_BOOTSTRAP=1 接受上游 nightly 参数，仅将前端线程 8 限为 2，Cargo
作业限 1；不去掉 plugin/image/Turbopack 功能。最终编译及工具链兼容仍
待结果，离线解析通过不代表原生引擎已成功构建。

Next 离线 metadata 首次续跑被上游 nightly rustc 选项拒绝；开启明确
RUSTC_BOOTSTRAP=1 后实际解析成功，registry 版本/checksum 检查通过。
这是 Rust 1.95 工具链接受配置并解析闭包的证据，不是 nightly 等价或
next-swc-napi 编译成功证据；上游功能特性和编译参数未删改，最终编译
仍需继续确认。日志 /tmp/hermes-next-native-offline-metadata-bootstrap.log。

TUI 原构建已实际 exit 0，产物
/gnu/store/ghs24kpf4ryi5xm2z2492q3f9ln9hwj9-hermes-node-tui-0.21.5。
entry.js、许可及 hermes-tui 启动脚本已检查，脚本指向匹配的 5r8gm91…
hermes-agent-interfaces private Python/site。该产物不含完整 audio runtime，
最新工厂后续变更和完整入口组合仍须构建，未运行 TUI 交互验证。
Next 离线准备已完成 vendor，但 metadata 失败于 PATH 缺独立 Cargo 输出；
确认终止后补路径继续原副本解析，日志
/tmp/hermes-next-native-offline-metadata.log，不重复准备全部来源。

Next 离线预备首轮在复制源码测试夹具时遇到悬空相对 symlink，尚未进入
vendor；试图复用部分复制目录又遇已存在 symlink，两个终止均已确认。
改用新的独立副本并保留 symlink，不修改或删除原来源和测试夹具，重新启动
预备，日志 /tmp/hermes-next-native-offline-prepare-current.log。此前预备
日志仅证明准备失败，不作为 Cargo 离线解析成功证据。

新增 prepare-next-native.py，按显式 TSV 再校验 registry 来源并生成 Cargo
vendor checksum，保留 Git 项目的原 workspace metadata，以锁定 Git 源码
的本地路径接入。离线 cargo metadata 后检查 registry 身份/版本/checksum
未新增或改变，不用在线重新解析。已对独立来源副本启动实际准备，日志
/tmp/hermes-next-native-offline-prepare.log；最终离线解析结果仍待确认。
TUI 原任务已通过 Python 后端并进入 prepare-node-sources/build 阶段，
不等于最终 TUI 安装成功；其余原会话本轮确认仍运行。

Next 原生来源锁任务已实际 exit 0，生成 next-native-lock.scm，955 registry
来源通过 Cargo checksum，四个 Git 精确提交归档已锁定。进一步核对
packages/next-swc/package.json：完整 release 构建实际选择
plugin,image-extended,tracing/release_max_level_trace；此前 workflow 的 plugin
只是调用参数，配方应保留 package script 的完整特性集合。离线 vendor/Git
接入、工具链适配及 next-swc-napi 真实编译仍待完成，不能以来源锁替代产物。

新增 lock-next-native.py 并启动 Next 原生来源锁定，日志
/tmp/hermes-next-native-source-lock.log。校验归档与 Cargo/pnpm/Next metadata
一致，按 Cargo checksum 取得 955 registry 来源，四个 Git 仓库对应五个包
身份以 lock 精确 40 位提交取得；输出独立 next-native-lock 模块，不覆盖
Codex 或 Hermes 来源锁。来源取得过程尚未完成，SWC 构建和 WASM 资源
原始来源仍待接入。音频/SDK/TUI/dashboard/V8/Codex host 原会话本轮
均确认仍运行，不因静默重新启动。

Next v16.1.1 官方源码已解包审查，原生目标 next-swc-napi 还包含 Turbopack，
上游 setup-nextjs-build.yml 使用 build-native --features plugin --release，
rust-toolchain.toml 固定 nightly-2025-10-27。Cargo lock 的 955 registry 与
5 Git 包身份登记于 planning/hermes-next-native-source.json；尚未源码锁定
全部输入，也未证明仓库工具链适配成功。Next 归档三个 WASM 明确为
source-map08 mappings、@vercel/og resvg/yoga，各自需匹配原始源码生成，
不能只替换 SWC 或以 JS 回退掩盖未补齐资源。全套前端产物仍待构建。

前端归档审计实际 exit 0：708 个 Linux 候选通过官方 pnpm SHA512 和
name/version 核对，11 个归档含原生/WASM 载荷，详见
planning/hermes-agent-browser-node-archives.json。其中还含 Linux musl
候选（有些包不声明 libc），后续实际安装须明确选择 gnu，不安装 musl。
Next 自身归档含三个载荷，不能只替换平台 SWC 就宣称资源闭包完整。
Next v16.1.1 官方源码已取得，SHA256
5fcfd21ec814275ea14923d215b24460a9c54e27161be80805dfa4d8148a0c7d，
源码构建目标/依赖审查待继续，尚未生成 dashboard 或浏览器产物。

agent-browser dashboard 锁的 Linux 原生候选已明确：Next SWC 16.1.1、
Tailwind oxide 4.2.2、Lightning CSS 1.32.0、Sharp 0.34.5/libvips 1.2.4。
Lightning CSS 与已有源码包版本相同；oxide 与 Hermes 4.3.3 不同，不能直接
替代。开始取得 Next v16.1.1 官方完整源码审查 SWC 构建；归档审计原会话
仍运行（缓存 643 文件不是完成证据）。所有原重型构建任务本轮确认仍运行，
音频依赖 Sherpa 已到约 45% 链接；原生候选仍待 payload 和来源闭包确认。

新增 fetch-agent-browser-node.py，对 dashboard 的 Linux/glibc/x64 npm
归档核对 pnpm SHA512、包 name/version，并扫描原生/WASM 文件魔数与扩展名，
记录 install/postinstall 但不执行；外国平台输入单列。首轮实际审计终止于
类型包非 package 顶层目录，已修正单根目录检查并重启，日志
/tmp/hermes-agent-browser-node-archive-audit-current.log。最终审计尚未完成，
不能将未发现载荷的部分归档概括为整个闭包纯源码。音频组合现编译 Sherpa，
其余 SDK/TUI/dashboard/V8/Codex host 原会话均确认仍运行。

新增 inventory-agent-browser-node.py，核对源码与归档 pnpm lock 一致，
从 packages/dashboard importer 的构建/运行依赖遍历精确 snapshots，保留
peer 身份、依赖边和 os/cpu/libc 条件，拒绝缺失 snapshot 和非 registry 来源。
实际生成 planning/hermes-agent-browser-node-inventory.json：753 snapshots、
753 唯一 name/version 归档，不包含独立 docs importer。归档下载与 SHA512
校验、原生/WASM 载荷审计、SWC 等源码替代及最终前端构建仍待完成。
音频、SDK、TUI、dashboard、V8、Codex host 原会话本轮确认仍运行。

agent-browser Rust 来源锁任务已实际 exit 0，生成 agent-browser-lock.scm，
331 个 registry 来源均通过 Cargo checksum。此项不涵盖 dashboard JS
来源及浏览器引擎，不代表 agent-browser 已构建。Next 配置要求 output=export，
原生程序静态嵌入整个 out；后续配方必须交付这部分完整产物。

agent-browser 来源 locker 已新增并启动，日志
/tmp/hermes-agent-browser-source-lock.log：先核对归档与 Cargo/pnpm/metadata
文件一致，再按 Cargo checksum 取得 331 个 registry 来源；仅复用专用缓存
中 hash 匹配的源码归档，不复用预编译产物。源码 RustEmbed 指向
packages/dashboard/out，dashboard 使用 Next 16.1.1，必须生成完整静态
资源后编译原生程序；不能用空目录或裁掉 dashboard 获得较小的 CLI。
该前端及其 SWC/原生依赖来源闭包、Chromium provider 和 Hermes 接入仍待完成。

H16 浏览器组件已开始来源固定：Hermes 源码的 npx spec 为
agent-browser@^0.26.0，取得官方 v0.26.0 源码归档并核对 CLI metadata，
SHA256 和 331 个 Cargo registry 身份（无 Git crate）登记于
planning/hermes-agent-browser-source.json。该版原生 Rust CLI 提供
AGENT_BROWSER_EXECUTABLE_PATH，配方需使用源码浏览器 provider 替换安装
下载；另审查 dashboard 嵌入和协议生成资源，避免裁掉发行功能。
来源锁、JS/浏览器资源及配方尚未完成，未启动浏览器功能测试。音频、SDK、
TUI、dashboard、V8、Codex host 原会话本轮均确认仍运行。

音频组合两处 Scheme 问题已修正：导入 guix utils，gexp 的带前缀变量用
显式表达式引用。最新实际构建 /tmp/hermes-audio-combination-current-build.log
已进入依赖取得阶段，使用固定 channel FFmpeg 8.1.1/PortAudio；原句柄
15931 确认仍运行。README 增加构建命令和源码不可得记录说明。SDK、TUI、
dashboard、V8、Codex host 原会话也确认仍运行，未另行重启。尚无音频
组合成功产物证据，PyAV 编译和共享 NumPy 接入仍待实际构建结果。

完整音频组合的可取得来源锁已实际生成 hermes-full-audio-lock.scm：235 Python
来源、1308 Rust crates、五个 provider，单独保留 pvporcupine 无源码记录。
新增 hermes-audio.scm 的 hermes-agent-audio，使用锁定运行时及五个 provider，
另接入源码 Pilk；PortAudio 固定库路径、FFmpeg 编译输入与程序 PATH 显式设置。
安装 source-unavailable-components.scm，描述保留 Porcupine 未完成边界。
首次 derivation 检查失败于缺 guix utils 导入，已修正并重查；实际组合产物
尚未完成，不能将来源锁或配方定义算作完整音频构建证据。

音频锁任务已完成 Python 来源解析并报告 235 Python 来源、1308 Rust crates，
原会话仍在取得 crate 来源，最终锁未生成。sounddevice 0.5.5 sdist 已按
inventory SHA256 核对，源码证实使用 ctypes.find_library 动态发现 PortAudio。
Hermes 工厂现在在选择 sounddevice 时显式加入 PortAudio，并传递确切 store
库路径；源码构建脚本以精确单锚点替换发现调用，拒绝路径缺失及来源不匹配。
脚本语法检查通过，最终音频配方实际编译证据仍待取得；没有执行设备功能验证。

完整音频来源锁任务 /tmp/hermes-full-audio-source-lock.log 的原会话本轮
确认仍运行，专用缓存已含 1404 个来源相关文件，尚未生成最终 Scheme 锁。
不把缓存数量记作完成证据。完整音频配方除五个已有 provider 和 Pilk 外，
还须显式接入 PortAudio（sounddevice 动态库发现）、FFmpeg 的库和工具路径
（PyAV 构建及音频转换），使用同一私有 NumPy；不能依赖宿主机 PATH 或库。
相关输入和发现路径修订待来源锁完成后接入，不提前运行设备/API 功能验证。

Hermes locker 增加显式 --record-unbuildable：只允许已核对精确锁版本与
归档哈希、且确认原生引擎无源码的审计项，生成来源锁时保留独立的
%hermes-source-unavailable-components 记录，其他依赖仍完整遍历并锁定。
默认模式继续拒绝把这种组合称为完整来源锁；完整音频计划中的 Porcupine
缺口没有删除。241 项 inventory 已用新模式重新生成，后续可推进可构建
音频组合，原生无源码项仍标为未完成，不使用预编译库代替。

ONNX 许可修订版已实际构建成功：主输出
/gnu/store/4rcprxar4mx6709pacf0yzcnvcb68gjf-onnxruntime-for-hermes-1.27.0，
Python 输出 /gnu/store/rrnvn3miy6ac0dgfa52avhjxfy28j898-onnxruntime-for-hermes-1.27.0-python。
两个输出的许可证安装文件已检查。以此最新 Python 输出重新执行六个原生
分发的私有环境接入，CTranslate2、FlatBuffers、ONNX、TFLite、Sherpa 和
Pilk 的精确元数据与 RECORD 导入均通过；产物与 METADATA 哈希登记于
planning/hermes-native-component-artifacts.json。未 import 或调用引擎，
共享 NumPy/完整音频运行时的构建和 ABI 接入仍待完成。
其余 SDK、dashboard、TUI、V8、Codex host 原会话确认仍运行。

SDK 预安装目录的消费者声明编译已实际通过：使用严格 NodeNext/noEmit，
skipLibCheck=false，消费 Codex、ThreadItem、ThreadOptions，未引用构建目录
的 MCP/Zod 类型。这证明当前预安装公开声明闭包可解析；此编译检查现加入
公开类型构建脚本，作为 Guix 构建产物检查，未运行 SDK 或任何 API。
最新版固定 channel derivation 检查通过，实际构建已启动，日志
/tmp/codex-sdk-public-closure-guix-build.log，等待共享 Codex 输入；旧任务未终止。
最新版实际 Guix 构建仍待完成；SDK、dashboard、TUI、V8、Codex host、
ONNX 原会话本轮均确认仍运行，不因输出静默重启。

SDK 公开类型闭包已接入安装脚本和 Guix 配方：源码编译 MCP types/AuthInfo 与
Zod v4，在 SDK 私有 node_modules 中安装声明、对应源码、映射及许可证，
仅暴露 types 条件入口，明确不提供或冒充 MCP runtime。实际源码编译及
预安装成功，安装到 /tmp/under-sea-codex-sdk-esm-types-output；最新配方
加入固定 MCP 官方源码 origin 和 build-public-type-closure 阶段。此前仍在
运行的 SDK Guix 任务是旧快照，最终当前配方实际构建及消费者类型编译待完成。
本轮原句柄确认 SDK、dashboard、TUI、V8、Codex host、ONNX 仍运行。

已取得官方 MCP SDK v1.26.0 完整源码，SHA256 与来源登记于
planning/codex-sdk-mcp-source.json。公开 types.ts 的闭包仅涉及 Zod v4
及自身 AuthInfo；Zod npm 归档包含 TypeScript 源码。实际从这些源码生成
声明成功，产物 /tmp/under-sea-codex-sdk-public-type-build-node，新增通用
scripts/build-codex-sdk-public-types.py。首轮缺 Node Error.captureStackTrace
类型，补入已锁定 Node/undici 类型后通过，未跳过库类型检查。此项仅证明
SDK 所需公开声明闭包源码可编译，不代表整个 MCP runtime 已编译；最终
SDK 安装、消费者声明编译检查及 Guix 配方接入仍待完成。

Dashboard 旧任务已确认 exit 1，失败于旧快照 uvloop configure helper 的
/bin/sh 回退；采用最新 CONFIG_SHELL/SHELL 和限核修订重新启动，日志
/tmp/hermes-dashboard-config-shell-build.log。仍运行的其他会话未重启。
SDK 安装声明检查发现上游依赖 tsup 合并声明，而当前逐文件声明含无扩展名
相对 import。构建脚本现在先将对应源码 import/export 路径显式补 .js，再
生成声明和匹配 map，以支持 NodeNext 的 ESM 解析；修改后的声明、JS 和安装
预构建实际成功，产物 /tmp/under-sea-codex-sdk-esm-types-output。消费者编译
及最终类型闭包仍待完成，不能据此称为所有 TypeScript 配置均已兼容。
此前已运行 SDK Guix 任务为旧快照，不含此修订，不作为最新版完成证据。

新增 under-sea/packages/codex-sdk.scm，固定五个编译/声明输入的来源和 SHA256，
构建脚本另核对官方 pnpm SHA512；配方以 codex-complete 为默认 CLI 输入。
固定 channel 的 derivation 检查已通过，实际默认 graft 构建已启动，日志
/tmp/codex-sdk-guix-build.log。公开 MCP 类型依赖当前只有元数据声明，最终
安装闭包仍未补齐；不得把配方解析成功或预构建成功记作 SDK 完成。

Codex SDK ESM、公开声明及 source map 实际编译成功，随后增加发行安装并再次
编译成功，产物 /tmp/under-sea-codex-sdk-install-output。安装包含版本 0.160.0、
上游 LICENSE、README 和匹配声明映射的源码；默认路径指向已源码构建的
audio/zsh CLI，保留调用方显式覆盖路径。公开声明的 MCP SDK 1.26.0 依赖
明确保留，尚需其最终类型闭包和 Guix SDK 配方；最终默认 CLI 还需接入
codex-complete，不能将此预构建视为完整发行完成。未执行 SDK/API 功能验证。
TUI、dashboard、V8 原生任务、Codex host 和 ONNX 修订的原会话均确认仍运行。

SDK 声明构建脚本现自行读取同一源码树的 pnpm-lock.yaml，解包前核对五个
编译器/类型依赖归档 SHA512，避免只依赖此前手工清单验证。修改后再次
实际声明编译成功，产物 /tmp/under-sea-codex-sdk-types-verified-build/types。
最终 SDK JS、CLI 默认路径和 Guix 配方仍未完成。TUI 最新 CONFIG_SHELL
修订、V8 重扫组任务及原 dashboard 构建均经句柄确认仍运行。

TUI 修正版任务已终止于 uvloop 内部 configure helper：首行解释器已正确
修补，但 Autoconf 的 SHELL=${CONFIG_SHELL-/bin/sh} 回退导致 config.sub
仍无法执行。build_env 现在为 uvloop 显式设置 CONFIG_SHELL/SHELL 为 Guix
sh；同时采用此前限核修订，已启动最新实际 TUI 构建，日志
/tmp/hermes-tui-config-shell-build.log。Dashboard 原任务仍运行其快照，未
重启；若也遇同样问题需待终止后采用修订。V8 外层 rescan 修订任务仍运行。

V8 原生检查已实际终止于 mksnapshot 链接，缺少 Rust core 标准库符号。
链接命令证明 Chromium 将 prebuilt Rust std archives 放在 ldflags 中，
位于消费它们的对象之前；GNU ld 原有组未覆盖这些归档。源码适配新增
Linux/use_lld=false 时的外层 rescan group，保留所有原编译/安全参数，
已应用到保留来源后恢复 Ninja，复用已编译对象。日志
/tmp/codex-v8-native-link-group-preflight.log；修正后链接结果尚待确认。
未终止仍在运行的 Codex host 快照，其最终也需此修订实际构建证据。

SDK 公开类型闭包补入 MCP SDK 1.26.0 和 Zod 3.25.76，npm 归档均按官方
pnpm lock SHA512 核对后记录。保留公开 MCP 引用重新执行 TypeScript
声明编译成功，日志 /tmp/under-sea-codex-sdk-types-mcp-build.log，产物在
/tmp/under-sea-codex-sdk-types-mcp-build/types。此证据仅涵盖 Codex SDK
声明生成，不代表 MCP 本身或最终 SDK JS/Guix 安装已源码构建完成，亦未
运行 SDK/API 功能测试。SDK 的源码 CLI 默认路径与最终配方仍待完成。

Codex SDK 声明准备开始：已按官方 pnpm SHA512 核对 TypeScript 5.9.2、
@types/node 20.19.18、undici-types 6.21.0 三个来源，清单
planning/codex-sdk-type-sources.json。新增声明生成脚本，保留上游严格
编译选项，仅编译发行 src 并生成 declaration/declarationMap。实际编译
失败于公开 items.ts 引用 @modelcontextprotocol/sdk/types.js，证明 MCP
SDK 属于公开声明闭包而非仅测试工具，需接入精确 1.26.0 及类型传递依赖。
日志 /tmp/under-sea-codex-sdk-types-build.log；SDK JS/声明/CLI 集成均未完成。

旧 219 项集成构建 /tmp/hermes-integrations-current-build.log 已实际终止，
最后失败仍是 uvloop configure 的 `#! /bin/sh` 未修补，调用旧 store 脚本
nyg4jj…，不含后来已修正的可选空白匹配。NumPy/grpcio 的局部成功不能
作为完整集成包成功证据。正在运行的 dashboard/TUI 已使用后续 shebang
修正，保留其句柄继续等待，不另外重启同样重型闭包。最新版限核补丁仍
需要最终定义构建确认，完整音频运行时仍待接入。

Hermes 旧 219 项集成任务已实际完成 grpcio 1.81.1 和 NumPy 2.4.3 源码 wheel，
随后进入 SQLAlchemy Cython 扩展编译；完整包安装尚未完成，旧快照不作为
最新工厂定义的完成证据。TUI、dashboard 与 V8 原生任务仍经原句柄确认
运行，未因为编译静默重新启动。共享 NumPy 的最终音频组合仍待接入。

最新 Web 配方实际构建成功，包含首页资源引用检查，输出
`/gnu/store/p1b11d0qwd3bbavc36sxxws9xwpibh0p-hermes-web-assets-0.21.5`。
TS/Vite、首页与本地引用检查、安装标准阶段均已通过，仍不代表 dashboard
后端组合或页面功能已验收。V8 原生任务当前 2223/2360；TUI、dashboard
依赖任务确认仍运行，没有按静默输出重新启动。

已启动最新 Web 定义实际重建，纳入首页本地资源引用检查，日志
/tmp/hermes-web-assets-reference-check-build.log。此前 dzn3h7… 的检查是
单独产物检查，不能替代此最新版脚本的构建证据。Hermes TUI、dashboard、
Codex host、V8 原生预编译检查和 ONNX 许可修订任务均按原句柄确认仍运行；
V8 已至 2204/2360。未重启这些任务，也未开展功能验证。

README 已补 dae 数据更新流程：固定 channels，官方精确提交、独立缓存，
源码与 Go 锁审查；DB-IP 年月 CSV、SHA256、来源许可、配方版本和署名
同步更新，再重建组合包。明确 store 数据不原地替换，引用包的服务随
后续配置更新采用新闭包。D1 的源码构建、安装布局、许可署名和更新说明
已有证据；地理规则及 D2 服务功能统一验证尚未开展。

GeoIP 与完整数据组合已实际构建成功：
`/gnu/store/07rcf2a863ga5j9kbz2ljgrdr7x371sy-dae-geoip-2026.10-fd96fba`、
`/gnu/store/h7gaminlq0grq1fnjldv3a4k4rj4h3lc-dae-geodata-2026.10`。
组合目录两个数据文件及 DB-IP 署名文档已直接检查；这证明安装产物存在，
不作为路由功能验证。README 与摘要更新构建状态。D1 尚需完成更新操作
说明和最终统一验收，D2 服务生命周期/内核权限验证仍延后。

dae 服务的 asset-directory 支持 file-append 数据包路径，环境变量改为在
生成的启动表达式中计算；原字符串目录配置继续可用。固定 channel 下
已实际构造使用 dae-geodata 的 Shepherd 服务配置，未激活系统或服务。
README 改用包引用示例，使数据来源进入系统闭包。GeoIP 当前已完成 CSV
转换并进入 Go 编译，组合包等待同一输入；最终产物和服务功能仍待确认。

新增 dae-geodata 组合包，明确将源码生成的 geoip.dat/geosite.dat 收集到
share/dae，保留许可和 DB-IP attribution 文档引用，安装前拒绝空数据。
实际组合构建已启动，日志 /tmp/under-sea-dae-geodata-build.log；等待当前
GeoIP 输入，不重启其任务。README 增加固定 channel 构建命令与服务
asset-directory 字符串路径说明；未启动服务或进行路由功能测试。

新增 dae-geoip 配方：固定 DB-IP 2026-10 CSV origin，源码转换为各国 CIDR，
用固定上游 GeoIP Go 引擎的 plaintext importer 生成 geoip.dat，同时保留
上游 private/test 范围。所有 Go 输入来自离线来源锁。安装生成数据、
generator、转换 inventory、上游 LICENSE 与 DB-IP 署名/来源/变更说明，
分别登记项目 CC-BY-SA-4.0 和数据 CC-BY-4.0。实际构建已启动，日志
/tmp/under-sea-dae-geoip-build.log；尚待配置、生成与安装结果确认。

DB-IP CSV 实际转换完成：710834 个原始范围、251 个国家 tag，逐行地址数
守恒检查通过。Go 来源 locker 已扩展为显式 geosite/geoip 项目选择，各自
独立 cache 和 generated module，保留同样的原始 .info 验证。GeoIP 的六个
实际消费模块来源已在固定 channel Go 1.26.8 下解析，geoip-lock.scm 已
原子生成；日志 /tmp/under-sea-geoip-lock.log。生成配方仍待接入，不作为
最终 geoip.dat 已构建证据。TUI、dashboard 原句柄仍确认运行。

新增 prepare-dae-dbip.py，将 DB-IP CSV 的首/末地址范围转换为国家 CIDR
文本，使用 Python ipaddress 的精确范围划分，逐条确认地址数守恒，拒绝
错误格式、跨 IP 版本和逆序范围。转换 inventory 写在输入目录外，避免
上游 plaintext importer 将元数据误识别为国家规则；上游以文本 basename
映射国家 tag 的路径已核对。已对锁定 2026-10 CSV 启动实际转换，日志
/tmp/under-sea-dae-dbip-prepare.log；最终 GeoIP 生成及安装仍待接入。

dae-geosite 已实际完成源码编译与规则生成，输出
`/gnu/store/vliwvj5fy99097g944jkizacwqcnr2b4-dae-geosite-2026.10.04-6377733`。
GeoIP 的 DB-IP 2026-10 CSV 原始地址范围已取得，哈希、署名及官方 CC-BY-4.0
许可出处登记于 planning/dae-dbip-source.json。准备将 CSV 范围无损展开为
各国家 CIDR 文本，再用上游 GeoIP plaintext 输入生成数据，避免依赖已生成
MMDB；转换脚本、Go 闭包、完整资产组合及功能验证仍待完成。

geosite 首次构建在 Go .info 原始字节哈希处失败，已核对代理与 cache 的
Version/Time/Origin 完全相同，差异仅 Origin JSON 字段顺序。Go 会重写
缓存 JSON；locker 现额外取得 canonical proxy 原始响应，严格比较所有
JSON 字段一致后锁定原始字节，不更改 zip/mod 的 checksum 验证来源。
锁已重新生成并启动重建，日志 /tmp/under-sea-dae-geosite-metadata-build.log。
此前构建终止已确认；此修复不作为数据产物已成功的证据。

geosite 生成器来源锁实际生成成功，新增 dae-data 模块的 dae-geosite 配方。
使用固定规则文本、源码 Go 生成器及离线模块 proxy，现场生成 geosite.dat，
安装到 share/dae 并保留 generator 和 LICENSE，不下载 release 数据产物。
固定 channel 实际构建已启动，日志 /tmp/under-sea-dae-geosite-build.log；
生成与安装结果尚待确认。GeoIP 原始数据、完整资产组合和服务示例仍待补齐。

dae 数据配套开始源码锁：官方 geosite 提交
63777333b7dd1ac57f790e466c0f6a647b9c7281 与 GeoIP 提交
fd96fbac6cffc06ab9a10d6ee8fad61afe9b771c 的归档已取得，哈希与提交日期在
planning/dae-data-sources.json。geosite 包含规则文本和 Go 生成器，源码
MIT；GeoIP 默认生成流程另外依赖 DB-IP MMDB，原始数据来源/许可未锁。
新增 scripts/lock-geosite.py，校验源码/归档 go.mod/go.sum 一致，使用
Go checksum 验证解析实际生成器闭包并原子输出固定来源，不改 go.mod。
固定 channel 依赖解析已启动，日志 /tmp/under-sea-geosite-lock.log；
数据配方、生成产物及整体数据许可审查仍待完成。

Hermes 工厂增加显式组件解析器：按 generated requirements 的
name/version/module/recipe/output 解析真实 Guix 包，核对精确版本及输出
存在，再生成带输出选择的 gexp-input，避免 ONNX Python 输出退回 out。
固定 channel 下五个音频 provider 的实际 Scheme 解析检查通过，动态解析
保留 native 模块向 Hermes 的依赖方向，未新增循环导入。最终音频组合
仍须生成完整来源锁并实际构建；此解析检查不属于功能验证。

音频 provider 清单修正 ONNX 输出选择：recipe 现在为真实 Scheme 变量
onnxruntime-for-hermes，独立 output 字段为 python，避免使用不存在的
带冒号变量名。Locker 验证 module/recipe/output 字符并在生成的组件要求
中显式保留输出（默认 out）；241 项完整音频 inventory 已重新生成。
此项仅消除接入清单歧义，完整来源锁仍受 Porcupine 源码条件项约束，
最终音频组合尚未构建。TUI、dashboard 构建由原句柄确认仍运行。

uvloop 来源的 setup.py 用 host affinity 决定 libuv make -j，忽略 Guix
--cores。已在源码准备中限制为现有 NIX_BUILD_CORES，并要求精确单个补丁
锚点，锁定源码匹配和修改后语法解析通过。此修订需最终配方重建确认；
正在运行的旧快照未重启。TUI、dashboard、Codex host 和 V8 原生预编译
检查任务均由实际句柄确认仍运行，暂无新的终止结果。功能验证仍未开始。

已对 Sherpa 实际 graft 输出执行私有 Python 组件导入，元数据版本
sherpa-onnx 1.13.4、发行 RECORD 文件及 console launchers 均由现有导入器
接入临时目标 `/tmp/under-sea-sherpa-component-import/out`，未 import 引擎。
这确认 Sherpa 的源码产物可走私有 site 接入路径，但完整音频组合来源锁、
共享依赖、模型资源及最终配方仍未完成。旧集成任务及 ONNX 许可修订任务
均经实际 session 句柄确认仍运行；没有按日志静默重启任务。

Web 产物检查进一步接入构建脚本：解析生成的首页，核对 script/img/link
的本地资源引用确实存在且不越出输出目录，不加载 JS 或启动服务。
对已安装的 dzn3h7… 输出实际运行此文件布局检查通过；修改后的构建脚本
仍需随最终包重建。Dashboard、TUI 和 Codex host 已按原句柄确认仍运行，
未因观察间隔重启。此项是产物完整性检查，功能验证仍延后。

修正安装路径后的 Web 实际构建成功，输出
`/gnu/store/dzn3h7c5rw97gsqbfcm5qv7kf815y4q7-hermes-web-assets-0.21.5`，
已直接确认 share/hermes-web/index.html 存在。新增 `hermes-dashboard` 组合
入口，依赖完整集成 Python 运行时和此静态资源，设置上游 HERMES_WEB_DIST
后执行 hermes dashboard，避免启动时 npm 构建。入口安装也检查首页存在。
配方解析通过并已启动实际构建，日志 `/tmp/hermes-dashboard-build.log`；
最终组合产物尚待确认，没有启动 HTTP 服务或开展功能测试。

Web 安装产物审查发现此前成功输出没有首页：Vite 日志明确输出
`hermes_cli/web_dist`，配方错误复制 `web/dist`。已修正安装路径，构建前
删除旧 web_dist，并在构建和安装两处要求 index.html 存在。新实际构建
日志 `/tmp/hermes-web-install-path-build.log`；旧输出不能作为可用 Web 资源证据。
Sherpa 引擎和 Python 绑定实际构建成功，默认 graft 输出
`/gnu/store/j7fmh5njcankqn8a6nriym9qz347qyj7-python-sherpa-onnx-for-hermes-1.13.4`。
最终音频运行时接入、模型资源与功能验证仍待完成。

Hermes Web 静态资源最新实际构建成功，输出
`/gnu/store/jhhlxb105aryh7287rwwl03fisqq081y-hermes-web-assets-0.21.5`。
TypeScript、Vite、安装及 Guix 标准产物阶段通过，Three 核心源码编译已进入
此次构建。后端静态发现、入口与最终组合尚未接入；addon WASM 仍单列，
没有开展页面或后端功能测试。

TUI 旧任务已确认终止：uvloop 构建报告 `./configure` ENOENT。保留源码的
configure 首行为 `#! /bin/sh`，此前只匹配无空格形式，故未修补该解释器。
现统一匹配 shebang 中可选空白并保留写入前 chmod；已启动实际重建，日志
`/tmp/hermes-tui-configure-shebang-build.log`。旧失败不作为接口运行时完成证据。
Web 接入 Three 的任务仍通过实际句柄确认运行，未因输出间隔而重启。

Hermes Web 已接入固定哈希的 Three r180 官方源码：Node 准备阶段仅提取
核心源码、上游构建配置、metadata 和 LICENSE，现场编译六个 JS 入口，
不复制归档中 addon WASM。锁版本和重复来源在接入前检查。最新 Web
derivation 为 `82884m3xy7milblysc8q49xr1pgph147-hermes-web-assets-0.21.5.drv`，
实际构建已启动，日志 `/tmp/hermes-web-three-build.log`；构建结果尚待确认。
Addon JS/WASM 的完整源码配套仍属待办，此接入不作为整个 Three 完成证据。

Three r180 官方源码的六个非压缩 JavaScript 入口已实际编译成功，临时产物
在 `/tmp/under-sea-three-build/build`，日志 `/tmp/hermes-three-js-build.log`。
新增 `scripts/build-hermes-three.mjs`，复用上游构建配置的 GLSL 转换、许可
banner 和共享 core 分组，以已源码构建的 Rolldown 执行；保留 ESM、WebGPU、
TSL 和 CJS 入口。第一次执行发现 output 为数组，已适配后重新成功构建。
这只是 JavaScript 构建证据：Guix 配方、Web 接入及 addon WASM 的来源构建
仍待完成，不能据此称整个 Three 或 Hermes Web 已补齐。没有运行功能测试。

独立 Web 构建已通过 TypeScript，Vite 使用源码 binding 后真实失败于
`@nous-research/ui` 无法解析 three。没有把该模块 externalize 或删掉界面。
正在取得官方 Three r180 源码，后续编译 0.180.0 JS 模块；附带 WASM
须继续审计源项目/实际前端闭包，不复制已有 WASM 载荷冒充源码构建。
失败证据 `/tmp/hermes-web-independent-build.log`；Web 尚未完成。

Web 构建依赖修正：继承 TUI 的 G-expression 即使替换 install phase，
仍将原表达式中的 Python 后端引用列为输入。Web 改用独立标准构建阶段，
只依赖 Node 来源与源码原生 binding；新构建已进入 prepare-node-sources
和 build，日志 `/tmp/hermes-web-independent-build.log`。
旧任务仍运行其已有输入快照，不能以其结果代替最新 Web 定义。

Hermes Web 构建接入：Node 准备脚本支持 tui/web/prepare 目标和独立原生
component 清单，安装前核对上游 lock 与源码产物 metadata 版本一致。
新增 `hermes-web-assets`，接入已源码构建的 rolldown、Tailwind oxide、
Lightning CSS，执行上游 TypeScript/Vite 构建，不运行 npm install。
实际构建启动，日志 `/tmp/hermes-web-assets-build.log`；Three/Shiki 等
先前排除的 WASM 来源仍需补齐，不能以定义存在称 Web 完成。后端静态
资源发现与桌面集成仍待完成。

独立 Python 组件接入进一步确认：CTranslate2、FlatBuffers、Pilk、TFLite、
ONNX 五个实际 store 输出已完成同一临时私有 site 的文件/元数据导入。
导入器重写 RECORD，记录经过 Guix strip 的文件及再生成 launcher 的
实际哈希，避免保留旧 wheel 哈希。没有加载组件代码或执行功能测试。
Sherpa 仍编译中；最终完整音频配方、NumPy 私有锁和条件项尚未完成。

Sherpa 完整源码已实际通过离线 CMake 配置，路径确认使用本仓库 ONNX
1.27.0 头文件与共享库；PortAudio with ALSA，OpenFST 使用外层 2026-04-11
来源，已进入 CPU 核心编译。最终链接、Python wheel 和安装仍待完成。
ONNX 许可证修订版以单编译任务重建，日志 `/tmp/hermes-onnx-license-build.log`。
Hermes 工厂现于 derivation 生成前拒绝独立组件重复或与 sdist 名称重叠，
避免同一私有发行被重复安装；最终组合仍待锁和实际构建。

ONNX Runtime 1.27.0 CPU 引擎及 Python 输出已实际构建成功：
`/gnu/store/2k1ma7vn6m8vyjhnbv2nvic627kvd45k-onnxruntime-for-hermes-1.27.0`、
`/gnu/store/n6yzg70msrnwsyf8s278dbcnx2qmj7gb-onnxruntime-for-hermes-1.27.0-python`。
源码许可证未由默认阶段发现，已补两个输出的显式安装；修订版仍待重建。
Sherpa 的 PyPI sdist 缺少 cxx-api-examples，未关闭目标，改用官方同版
Git 标签完整归档，版本与目录已核对，SHA256
`3243cb386d3a4ac87596adf7d2c89fddf23e2948b154942b987b4d91c1fee295`。
最新绑定/引擎构建日志 `/tmp/hermes-sherpa-full-source-build.log`。
旧 219 项集成构建在旧 libuv helper 脚本处失败，已用当前修复版重新构建，
日志 `/tmp/hermes-integrations-current-build.log`。运行验证仍延后。

Porcupine 包装层审计继续：其 sdist setup.py 假定原 monorepo 布局并调用
git clean，Python 路径逻辑也依赖附带模型/关键词资源。单独复制包装层
不能作为完整引擎补全。Locker 已支持按精确版本和归档哈希读取 payload
audit，已审计的“含原生库、无源码”项目阻止生成完整源码锁；inventory
仍保留所有依赖与阻碍证据。241 项音频 inventory 已包含 Porcupine 审计，
实际音频组合仍须明确处理此条件项，不下载二进制掩盖来源缺口。

Hermes locker 增加 `--python-components`：独立原生包仍保留在完整依赖图，
但其精确 name/version/module/recipe 作为单独 provider 要求输出，sdist
列表不重复构建这些包；清单版本不匹配或缺少配方时明确失败。
`planning/hermes-audio-components.json` 登记五个 provider，241 项合并
inventory 已按此重新生成。provider 登记不代表实际构建完成；Porcupine
的源码条件缺口仍保留，不能以缺少 sdist 数降为零宣称全部来源可用。
完整来源锁生成、provider 与工厂一致性核对及组合构建仍待完成。

TFLite 许可证修订版已完成源码构建，输出
`/gnu/store/cd8ikdf9jhzp9mh7as61rj0pryc5q727-python-tflite-runtime-for-hermes-2.14.0`，
已确认 share/doc 的 LICENSE 存在。仍未接入最终私有音频组合。
Hermes 工厂已增加可选 python-components 来源清单并导出供独立组合模块
使用，在构建私有依赖前按精确版本导入源码组件；现有调用默认空清单。
更新后的集成 derivation 解析通过；仍运行的旧 TUI/SDK 构建保留其快照，
最终新增音频组合需独立锁和完整构建，不能用工厂参数支持替代接入证据。

私有音频运行时接入基础：新增 `scripts/import-hermes-python-components.py`，
按 name/version/output 清单读取已源码构建的发行 metadata 和 RECORD，
复制该发行的文件、拒绝重复包和路径碰撞，重新生成使用 hermes-python
的 console launcher。不复制 propagated inputs，公共依赖继续服从 Hermes
私有来源锁。CTranslate2 4.7.1、FlatBuffers 25.12.19、Pilk 0.2.4 的实际
store 产物已在临时目标完成导入；没有 import 组件代码或运行功能测试。
最终音频组合还需接入 factory、来源锁与 ONNX/TFLite/Sherpa，不能以此
宣称 Hermes 音频已构建完整。

Sherpa Python 安装产物检查补充：本地 wheel 必须包含唯一的
`sherpa_onnx/lib/_sherpa_onnx…so`，其内容须与 CMake 输出一致，metadata
必须为 sherpa-onnx 1.13.4 并保留 entry_points。检查在安装前执行，仅核对
构建产物，不运行功能测试。修改后的配方解析通过；当前仍运行的旧构建
使用其启动时的 store 脚本，之后需确认最新定义实际构建，不能混用证据。

Sherpa Python 配方已接入：`python-sherpa-onnx-for-hermes` 继承完整 CPU
引擎来源和功能，显式启用 Python，用 Hermes 解释器编译扩展，再通过上游
setup.py 元数据生成本地 wheel 并安装。固定 channel derivation 解析通过，
实际构建已启动，日志 `/tmp/hermes-sherpa-python-build.log`。
需等待源码 ONNX 输入，随后确认 CMake、链接、wheel 布局和入口；模型资源
与 Hermes 私有运行时接入仍未完成，不称 H12 已补齐。

Sherpa Python 绑定打包准备：新增 `scripts/package-hermes-sherpa-python.py`，
保留上游 setup.py 的版本、entry_points 和平台 wheel 元数据，改用 Guix
CMake 已编译的扩展，不再次执行上游自动下载/重复 CMake 构建；禁用 PyPI
split-package 形式，原生引擎作为同一 Guix 来源链的输入。
该脚本尚需接入 Python 配方并完成实际构建，不能视为绑定已补全。
另外已确认 Sherpa 上游主动设置 ESPEAK_NG_DIR 来复用其 espeak 来源，
故 Piper 的独立下载路径可由此避免，仍须实际配置验证。

Sherpa 引擎配方已新增并启动构建：`sherpa-onnx-for-hermes` 1.13.4 接入
17 个核对的来源（新增 PortAudio），保留 CLI/C API、ALSA 采集、WebSocket、
TTS 和 diarization，依赖本仓库源码 ONNX。Python binding 将独立接入，
不能以引擎包作为 H12 完成证据。日志 `/tmp/hermes-sherpa-build.log`，
当前需等待 ONNX 输入完成，后续配置/编译结果仍待确认。

TFLite 2.14.0 已完成默认 Guix 源码构建，Python wrapper 和 XNNPACK CPU
引擎已编译，RUNPATH 检查通过，输出
`/gnu/store/kjr7j54wpq4jr564kcaq3wvr81r6pi67-python-tflite-runtime-for-hermes-2.14.0`。
构建日志发现默认许可证阶段没有找到源文件，已显式安装根 LICENSE，修订版
重新构建日志 `/tmp/hermes-tflite-license-build.log`；最终组合接入仍待完成。
Hermes TUI 构建在 libtoolize 生成的只读常规 helper 文件处失败，脚本现于
写入前 chmod 本地副本，symlink 则仍先替换为副本，避免修改 store。
已重建，日志 `/tmp/hermes-tui-libuv-mode-build.log`；功能验证尚未开始。

Sherpa 离线准备脚本已新增并实际运行：16 个来源解包并生成精确
FetchContent 名称的本地缓存；修改 ONNX 查找失败分支为 FATAL_ERROR，
不能继续下载二进制。脚本 `scripts/prepare-hermes-sherpa.py` 尚待接入配方。
OpenFST 来源顺序已核对：Sherpa 首先将自己的 cmake 目录加入模块路径，
kaldifst 后续使用 APPEND，并 include(openfst)，因此按源码的路径顺序
将使用外层 2026-04-11 模块；实际 CMake 配置仍须确认该推断。

Sherpa 递归锁扩展至 16 个归档：新增 kaldifst 1.8.0、kissfft 精确提交、
Sonic 精确提交，均完成归档哈希核对。kaldifst 声明的 OpenFST tag 为
2026-04-10，外层为 2026-04-11，须审查已有 target 的复用顺序而非覆盖来源。
Piper phonemize 的额外 espeak 下载受 ESPEAK_NG_DIR 控制，后续明确接入
源码构建的 espeak 输入，避免其 ExternalProject 自动下载。

Sherpa 来源锁已生成：新增 `scripts/lock-hermes-sherpa.py` 和
`hermes-sherpa-lock.scm`，13 个官方来源归档全部按上游 SHA256 核对。
包含 Kaldi、OpenFST、Eigen、pybind11、WebSocket 和 TTS/diarization 来源；
没有下载 ONNX 二进制。新增递归 inventory 审查这些来源中的额外下载声明，
仍需判断实际目标闭包、接入 PortAudio 和源码 ONNX，并实际编译。
Pilk 独立源码构建已成功，默认 graft 输出
`/gnu/store/zx969d0032bn4w9hp6bk36naai1js849-python-pilk-for-hermes-0.2.4`；
Hermes 私有运行时接入和功能验证尚未完成。

Sherpa ONNX 1.13.4 的锁定 sdist 已取得并核对 SHA256，新增
`planning/hermes-sherpa-source-inventory.json`，登记 CMake 来源和默认功能。
Linux 上游会下载 ONNX Runtime 1.27.0 预编译库；其版本与本仓库正在编译
的引擎一致，可显式接入该源码产物。后续配方须提供头文件/库路径，并将
找不到输入时的下载回退改为明确失败。Kaldi、sentencepiece、WebSocket、
音频采集、TTS/diarization 等默认目标的精确来源仍需锁定，不裁掉这些功能
来绕过来源准备。

Porcupine 来源审计完成：锁定 4.0.3 sdist 内含 13 个原生库，C/C++ 源码
文件为零，证据在 `planning/hermes-porcupine-source-audit.json`。
此归档不能满足源码构建，保留条件缺口，不安装其中原生载荷。
Pilk 0.2.4 是 lazy_deps 明确要求但 uv.lock 未列出的依赖；已取得官方
sdist、核对 SHA256，包含 143 个 C/C++ 源文件，新增独立源码包
`python-pilk-for-hermes` 并开始构建，日志 `/tmp/hermes-pilk-build.log`。
SILK 原始版权/许可随源码保存；实际产物和私有运行时接入仍待完成。

Hermes 合并音频闭包：`planning/hermes-full-audio-inventory.json` 记录现有
集成、云语音、voice/wake 的 241 个 Python 依赖，版本选择无冲突。
应用已审计 faster-whisper 官方来源后，仍需四个独立源码配方：CTranslate2、
FlatBuffers、ONNX Runtime、TFLite Runtime。最终组合需将这些包接入同一
私有运行时，锁定 NumPy 版本并核对依赖元数据；不能只增加全局 PYTHONPATH
后宣称完成。Porcupine 的 sdist 原生载荷来源审计单独开展。

TFLite 实际离线配置已通过：CMake Configuring done、Generating done，
Python interpreter wrapper 目标开始编译其 CPU 依赖。15 个已锁定来源及
本地 FetchContent/XNNPACK/PSimd 路径均被本次 Guix 配置接受，inventory
已登记各归档 SHA256 和此证据。编译、最终链接、wheel 安装和私有运行时
接入仍未完成；不以配置通过代替完整源码构建，更不代表功能验证通过。

TFLite 首次实际构建失败于阶段参数求值：configure-flags 在源码准备前读取
环境变量，路径为空。现改为 configure 阶段显式生成参数并执行 CMake，
重新构建日志 `/tmp/hermes-tflite-configure-phase-build.log`。
既有 V8 host、V8 原生、ONNX、Hermes TUI 构建句柄本轮均确认仍运行；
未重启它们，也未开展功能测试。

新增 `python-tflite-runtime-for-hermes` 2.14.0：使用 15 个离线来源缓存，
显式构建上游 Python interpreter wrapper，保留 XNNPACK CPU 后端，
从源码编译出的扩展与上游 Python 文件生成本地 wheel 并安装。
使用 Hermes Python ABI 和 Guix NumPy/pybind11；首次定义解析的 pybind11
变量名错误已修正，实际构建日志 `/tmp/hermes-tflite-build.log`。
CMake 配置、NumPy ABI 适配及最终产物仍待实际构建确认，功能验证未开始。

TFLite 递归来源补充：FP16 的 PSimd 下载原本使用浮动 master，改按
TensorFlow 2.14.0 官方 workspace 的精确提交锁定，现有 15 个源码归档。
新增 `scripts/prepare-hermes-tflite.py`，将来源清单解包到本地并生成
FetchContent/XNNPACK 的源码路径缓存，保留 XNNPACK，关闭测试/benchmark
构建目标并设置 disconnected。解包与缓存生成已实际完成；Guix package
接入、CMake 配置和 Python 扩展编译仍待完成，不能以此称引擎构建成功。

TFLite 离线来源锁：新增 `scripts/lock-hermes-tflite.py`，下载官方精确提交
归档并固定 SHA256，校验两个 URL 来源的上游 SHA256 和归档路径。
顶层 12 个 CPU 来源已取得；进一步从锁定 XNNPACK 的 Download 模块识别
FXdiv、pthreadpool 精确提交，并加入来源锁流程。
生成模块为 `hermes-tflite-lock.scm`；递归闭包审计、离线 CMake 接入和
Python 扩展实际构建尚未完成。最新 V8 host 已通过来源准备并进入 Cargo 编译，
仍等待最终构建结果。

最新构建缺口：V8 host 的来源准备在 profiler 列表匹配处失败；同名条目
分别存在于 stdlib 复制和覆盖率构建列表，现仅修改前者，保留覆盖率目标定义。
已重新构建，日志 `/tmp/codex-v8-profiler-copy-build.log`，尚无成功产物。
TFLite inventory 已剔除将 CMake 参数声明误识别成 Git 来源的条目，补入
fft2d、x86 neon2sse 两个 URL/SHA256 来源，并标记顶层 CPU 依赖。
XNNPACK/ruy 的递归来源闭包、归档核对和离线输入锁仍待完成。

TFLite 原始源码：已固定 TensorFlow 官方 v2.14.0 标签归档，版本头文件确认
2.14.0，SHA256 `ce357fd0728f0d1b0831d1653f475591662ec5bca736a94ff789e6b1944df19f`。
`planning/hermes-tflite-inventory.json` 登记 CMake 外部 Git 来源；仍需审计实际
目标闭包、锁定子依赖、处理 NumPy/Python 绑定并实际构建，不复制 runtime wheel。
Hermes Linux 唤醒默认使用 ONNX，但 openWakeWord 的声明依赖还包含 TFLite，
不因默认路径不同就丢掉这项补全。

Hermes libuv helper 处理更新：autoreconf 生成的 ltmain.sh 等可能是指向只读
Guix 输入的链接。补解释器路径时先将这些链接替换为构建目录内的副本，
避免修改 store 输入；保留执行权限。最新 TUI 构建日志
`/tmp/hermes-tui-libuv-local-copy-build.log`，先前版本在此处失败，不能算完成。

新增 `onnxruntime-for-hermes` 1.27.0，CPU 引擎与 Python 扩展分输出构建。
用 16 个锁定源码归档生成离线 deps.txt，提供 Guix protoc，禁用自动下载
编译器路径；新依赖缺失时构建失败，不继续联网解析。保留完整 CPU operators，
LTO 关闭以控制构建资源，GPU providers 仍需单独处理。实际构建已启动，日志
`/tmp/hermes-onnx-build.log`；完整编译、安装布局、私有运行时接入仍待完成。

ONNX 外部来源处理：新增 `scripts/lock-hermes-onnx.py`，依据 1.27.0 的 deps.txt
下载 CPU/Python 构建涉及的 16 个官方源码归档，核对上游 SHA1，再固定 SHA256
生成独立来源锁。只处理 source archive；不下载上游 protoc_binary。
日志 `/tmp/hermes-onnx-source-lock.log`，实际引擎构建及 Guix protoc 接入仍待完成。
GPU/其他平台依赖继续留在完整 inventory，不以 CPU 来源集宣称全部后端已完成。
本轮来源锁已成功生成，16 个归档全部核对通过。音频 Python 绑定也已完成默认
graft 构建：CTranslate2 输出
`/gnu/store/r5lkaixipdd3fbzfcacn5vw1mi8lnqpn-python-ctranslate2-for-hermes-4.7.1`，
FlatBuffers 输出
`/gnu/store/vgmjza3ds7vc40g8s9f39yailq72hhhk-python-flatbuffers-for-hermes-25.12.19`。
这里只确认独立包源码构建完成，Hermes 私有运行时尚未接入，功能验证仍延后。

CTranslate2 CPU 引擎与 CLI 已完成源码构建；Python 扩展首次失败在构建后端
找不到 `python` 命令，自定义运行时只提供 python3。新增
`python-for-hermes-wrapper`，将标准命令指向同一个 Hermes 解释器，两个音频
Python 包均使用它，最新日志 `/tmp/hermes-audio-python-wrapper-build.log`。
ONNX Runtime 1.27.0 官方标签归档已取得，后续需锁定 CMake 外部源码依赖，
不能把只下载主仓库作为引擎构建完整的证明。

FlatBuffers 25.12.19 官方源码已取得，Python setup.py 与版本常量均匹配锁定版本。
新增 `flatbuffers-for-hermes` 和 `python-flatbuffers-for-hermes`，分别从同一
源码构建原生工具/库和 Python 运行库，避免没有 sdist 时使用 wheel。
构建日志 `/tmp/hermes-flatbuffers-build.log`；实际构建结果及私有运行时接入
仍待确认。CTranslate2 已使用编译器 OpenMP 通过配置，进入 C++ 编译。

新增 `python-ctranslate2-for-hermes`，从同一官方源码编译 Python 扩展，
使用 Hermes Python ABI、源码构建的 CTranslate2 引擎、Guix pybind11；
移除 `/usr/local` rpath 并指定引擎 store 路径。构建日志
`/tmp/hermes-ctranslate2-python-build.log`，仍等待引擎与扩展的实际完成。
此独立绑定的依赖尚需整合进锁定私有音频运行时，不代表已经接入 Hermes。
首次引擎配置因默认寻找 Intel OpenMP libiomp5 失败，已显式选择编译器
提供的 OpenMP (`OPENMP_RUNTIME=COMP`)，保留并行计算和 CPU dispatch。
最新引擎/绑定组合构建日志 `/tmp/hermes-ctranslate2-openmp-build.log`。

CTranslate2 来源补充：官方 4.7.1 源码已取得并核对 Python 版本常量。
官方 Git tree 提供 cpu_features、spdlog、cxxopts 的精确子模块提交，
对应归档已固定哈希。新增 `ctranslate2-for-hermes`，从源码构建 CPU dispatch、
OpenBLAS/oneDNN 引擎与 CLI；实际构建日志 `/tmp/hermes-ctranslate2-build.log`。
Python 绑定接入和模型来源仍待处理，GPU 后端另需其工具链，不能凭 CPU 库
构建宣称 H11/H12 已完成。

Hermes 本地语音清单：新增 `planning/hermes-local-audio-inventory.json`，
voice/wake 组合为 86 个依赖，其中 flatbuffers 25.12.19、onnxruntime 1.27.0、
tflite-runtime 2.14.0、ctranslate2 4.7.1、faster-whisper 1.2.1 没有锁定 sdist。
正在补精确上游源码来源；Porcupine 等有 sdist 的项目仍需审计是否含专有载荷，
不能以归档存在作为可完整源码构建的证明。locker 已修正依赖遍历丢失版本信息
的问题，保留 uv.lock 的版本边和平台判断，正确选择 Linux/Python 3.12 的
SciPy 1.18.0；遇到同一私有运行时的版本冲突仍明确失败，不任意选版本。

Hermes 云语音来源补充：Mistral 2.4.8、Edge TTS 7.2.7、ElevenLabs 1.59.0
及三个共享依赖均有锁定 sdist，已加入 `hermes-integrations-lock.scm`，
当前选定集成为 219 个 Python 来源、1093 个 Rust crate。
`planning/hermes-cloud-audio-inventory.json` 保存扩展后的组合；仍不涵盖本地
STT、唤醒、SILK 和完整插件生态。补 libyaml 输入以源码构建 PyYAML 扩展，
避免此前缺 yaml.h 而退回纯 Python 的情况。最新集成构建以单 Cargo 任务启动，
日志 `/tmp/hermes-integrations-cloud-audio-build.log`，成功产物仍待确认。

Hermes uvloop 后续失败定位：autoreconf 已生成 configure，但生成脚本仍使用
沙箱不存在的 `/bin/sh`，表现为执行 configure 时 ENOENT。已对生成的 libuv
shell 脚本补 Guix 解释器路径，最新 TUI 构建日志
`/tmp/hermes-tui-libuv-shell-build.log`，实际最终产物仍待确认。
C4 发行审计：固定源码 rust-release.yml 为 Linux CLI 发行列出独立
`codex-responses-api-proxy`，另有 app-server 发行的 `codex-app-server`。
CLI 虽已有相关子命令，独立发行消费者还可能依赖这些文件；已在
`codex-complete` 补两个 Cargo binary 构建与安装，定义解析通过，实际构建待完成。
TypeScript SDK 的独立来源/构建仍待整理，不能称 C4 全部完成。

V8 头文件适配：构建期清除 `CPLUS_INCLUDE_PATH`，避免 Guix libstdc++ 的
stdlib.h 截获源码 libc++ 的 include_next；随后原生编译继续前进。
Chromium thin archive 配置只对 GCC 开索引，但本包 Clang 使用 GNU linker，
已将此索引条件扩展到 Linux 且未使用 lld 的情况，保留相同源码和功能。
适配后的 Ninja 构建已继续，日志 `/tmp/codex-v8-native-preflight.log`；
该临时原生构建用于定位编译问题，最终 Guix host 仍需最新定义的完整构建。
后续调整：C++ 搜索路径改为仅继承 `C_INCLUDE_PATH`，保留 Linux 系统头文件，
同时排除 libstdc++ 专属目录；完全清空搜索路径会遗漏 linux/limits.h。

Clang 23 输入已准备，此前 Clang 21 拒绝的四个参数在 23 上确认接受。
V8 bindgen 改用固定 Guix 包的原始程序，由 GN 显式提供 libclang 23，
避免其 wrapper 强制使用 Clang 18。Guix Rust 不附带可选 coverage profiler，
未启用覆盖率的发行构建不复制该文件；Chromium GN 的不稳定 Rust 选项通过
构建期 `RUSTC_BOOTSTRAP=1` 使用固定 Guix 编译器，不下载其他 Rust 工具链。
这些适配仍需完整编译结果确认，host 尚未完成。

V8 Rust vendor 布局已接入来源准备脚本，45 个目标依赖按 GN 精确版本复制，
8 个新增来源由 `codex-v8-lock.scm` 固定；归档 SHA256 和 Cargo 包名/版本均核对。
原生编译现已进入 2436 个 Ninja 步骤，Clang 21 因不支持源码使用的编译参数失败。
定义已改为该源码 GN 默认的 Clang 23，并准备同版本 LLVM/compiler-rt；
尚需确认实际编译结果，未删除安全相关参数以绕过工具链不匹配。

ICU 数据包实际构建成功，当前产物
`/gnu/store/x14g5hrzkjrs46kys9g3n2mydymzi2c2-codex-icu-data-77.1`（约 10 MiB）。
已补原始 LICENSE 的安装及 Unicode 许可标注，修订版仍需重建。
V8 GN 实际目标依赖审计发现 crate 归档没有 Chromium Rust vendor 目录。
`planning/codex-v8-rust-inventory.json` 登记 45 个精确来源，其中 8 个版本不在
原 Codex Cargo 来源锁：either 1.16.0、ixdtf 0.6.5、litemap 0.8.2、
potential_utf 0.1.5、unicode-ident 1.0.24、writeable 0.6.3、zerofrom 0.1.8、
zerofrom-derive 0.1.7。正在补齐独立来源锁及 Chromium 预期 vendor 布局，
不替换其版本；host 和整体组合均仍未构建完成。

Codex 整体组合：新增 `codex-complete`，继承语音/zsh 组合并增加独立 V8 host，
将其安装为 `codex-resources/codex-code-mode-host`，与锁定版本的 install-context
查找路径一致。固定 channel derivation 解析通过；整体构建已启动，日志
`/tmp/codex-complete-build.log`，等待同一 ICU/V8 输入链。上游模型目录保持默认，
可选 direct 目录不自动启用。ICU 已进入资源生成阶段，成功产物仍待确认。

V8 ICU 数据链：新增 `codex-icu-data`，固定官方 ICU 77.1 Git 标签归档
（SHA256 `ded3a96f6b7236d160df30af46593165b9c78a4ec72a414aa63cf50614e4c14e`）
和 rusty_v8 的 common filter。本地编译生成工具、编译资源并生成数据归档，
上游 Unicode 属性表作为数据输入保留，不使用预打包的 V8 ICU 归档。
构建日志 `/tmp/codex-icu-data-build.log`；host 输入与来源准备脚本已接入，
独立数据包和 host 的实际构建完成均仍待确认。

整体构建更新：`codex-with-audio-and-zsh` 已完成默认 graft 构建，输出
`/gnu/store/f3p9cvlsk673fvb9bv0dsgqmxkw736k9-codex-with-audio-and-zsh-0.160.0`，
安装布局包含 voice host 和补丁 zsh；运行验证延后，V8 仍未集成。
Hermes 最新接口构建在 uvloop 0.22.1 的 vendored libuv 缺少生成的 configure
脚本处失败，已补 Autotools 输入及离线 autoreconf 步骤并重新构建，日志
`/tmp/hermes-tui-autotools-build.log`。V8 的 Ninja Rust 输入已改用声明的 sysroot，
下一项构建缺口为 ICU 77 数据：crate 仅含部分预生成数据，不含完整原始 data
目录，需锁定原始数据与生成过程，不能复制其他裁剪版本的数据冒充完整来源。

最新进度：rolldown 1.2.1 和 Lightning CSS 1.32.0 均已源码构建完成，
分别输出 `/gnu/store/lcawp0spsb2b0j1l6gj3agjlisblndyd-rolldown-for-hermes-1.2.1`
和 `/gnu/store/i13b1mcaq5030ys0jnhh39k8mbcqb6nk-lightningcss-for-hermes-1.32.0`。
它们尚未接入最终前端。V8 原生编译发现 Chromium 默认 bindgen 前缀缺失，
已新增 Guix bindgen、rustfmt 工具输入和显式组合前缀；定义解析通过，
工具输入准备中，实际引擎编译仍需继续。

V8 工具输入已准备完成，重新生成 739 个 GN 目标成功。后续原生构建发现
Chromium 将 compiler-rt 和 llvm-ar 假设为 Clang 同目录组件，而 Guix 分包；
已在源码准备阶段指定固定 compiler-rt builtins 与 LLVM archiver 路径，
并显式声明 Clang 21 的资源版本。继续以原生编译结果确认适配，未开展运行验证。

- `scripts/lock-hermes.py` 已增加可重复 `--extra`、嵌套 extra 解析、
  `--inventory` 来源审计及独立 `--module` 输出。源码归档缺失时阻止生成构建锁，
  不退回下载 wheel。SDK 的运行依赖环记录在 inventory 中，构建顺序还需实际编译确认。
- `planning/hermes-integrations-inventory.json` 登记本轮选定的接口/集成组合：
  213 个依赖，其中 `lark-oapi` 和 `dingtalk-stream` 没有上游锁定 sdist，
  已在 `planning/hermes-source-overrides.json` 补充对应官方标签的精确提交、
  SHA256 和版本常量文件，源码版本已核对。原 inventory 保留上游原始缺口，
  不包括所有音频/桌面依赖。
- `hermes-interfaces-lock.scm` 已锁定 `all` extra 的 102 个 Python 源码包和
  764 个 Rust crate；新增 `hermes-agent-interfaces`，包含 MCP/ACP 和 dashboard
  后端等依赖，保留 ACP 入口。该组合仍不包含 Node 前端，源码构建正在进行。
- `codex-voice-host` 的默认 graft 源码构建已完成：
  `/gnu/store/0bcgc4prx46nnrrkw2a5khb82vj06sxc-codex-voice-host-0.160.0`。
- `codex-zsh` 固定官方 release workflow 的 zsh 提交和 EXEC_WRAPPER 补丁，
  shell、模块、补全函数已源码构建：
  `/gnu/store/42fcqs7r679d34rf7cfxsrxq61xmr2cz-codex-zsh-5.9.0.3-test-77045ef`。
  未生成 Git 源码归档中缺失的 Yodl 手册；这不影响托管 shell 的运行组件。
- `codex-with-audio-and-zsh` 正在编译 CLI 并集成语音 host、zsh 及
  `codex-execve-wrapper`；尚未完成整体构建，V8 仍缺失，C2/C3 仍待整体集成完成。
- Hermes 213 个集成来源已下载，解析出 1094 个 registry Rust crate 和
  `obstore` 的精确 `pyo3-file` Git 来源；已扩展 locker/builder 的精确 Git
  源码处理。新增 crates 下载仍在进行，部分请求返回 403，需检查退出结果处理。

后续更新：已定位上述 403 来自 NumPy vendored Meson 的虚拟测试 crate `bar`，
修正 locker 对实际 Rust Python 后端的扫描范围后，集成锁已成功生成，包含
213 个 Python 来源、1093 个 registry crate 和 1 个 Git 来源。
`hermes-agent-integrations` 已通过固定 channel 的 derivation 解析并开始实际构建。
Hermes 接口包第一次编译在 frozenlist 的构建后端缺失 `expandvars` 时失败，
已补该构建工具后继续编译。剩余构建后端的源码依赖仍在核对，尚不能宣称构建完整。

构建后端补充：`hermes-build-tools.scm` 中三个插件已源码构建成功：
`python-hermes-uv-dynamic-versioning` 0.8.2、
`python-hermes-coherent-licensed` 0.5.2、
`python-hermes-hatch-teams-build` 0.1.0（官方 Teams v2.0.13 提交）。
Teams 插件在 Guix 构建中读取锁定发布版本，避免依赖缺失 Git 历史的 .NET/nbgv
版本推导或回退到 0.0.0；插件原有 workspace 依赖元数据处理保留。
已有运行中的 Hermes 构建使用其启动时的 store 脚本和输入，插件接入后的最终
定义仍需完成实际构建，不能用旧进程的成功替代新定义的构建结果。

C1 进度：新增独立 `codex-code-mode-host` 源码包，已通过 derivation 解析并开始
构建输入准备，日志 `/tmp/codex-v8-build.log`。rusty_v8 使用固定源码归档，
GN/Ninja/Clang/Rust 由 Guix 提供，移除自动下载 Rust 工具链路径；引擎实际编译、
主包集成均尚未完成。该尝试不以预编译 V8 静态库替代源码构建。

网络服务配套：已新增 `(under-sea services networking)`，提供 dae 和 sing-box
的可选 Shepherd service，状态目录、配置路径和 dae 地理数据路径可配置。
定义已在固定 channel 成功解析；没有执行系统 activation 或启动服务，生命周期
验证仍延后。服务定义部分已写入，S3/D2 的最终验收尚未进行。

Node 来源审计：`planning/hermes-node-inventory.json` 记录上游 lock 的 Linux x64
候选输入（1339 个）和平台/原生候选，尚不代表可直接作为源码输入。
明确需要源码构建的原生链包括 Electron 40.10.2、esbuild 0.28.1、
rolldown 1.2.1、Tailwind oxide 4.3.3、Lightning CSS 1.32.0、node-pty 1.1.0；
Tauri CLI 2.11.4 是否属于实际目标构建闭包继续核对。Windows 专用安装器和
glibc/musl 变体需按目标 workspace 闭包剔除，不能照单下载 npm 原生二进制。

Node 后续进度：新增可复用 `scripts/lock-hermes-node.py`，核对发布归档与 lock
一致，按上游 SHA512 验证下载，再按 SHA256 固定 Guix origins。平台分类支持
负向平台标记；归档检查排除原生库、可执行文件及 WASM，不运行 npm scripts。
已生成 `hermes-node-lock.scm`，包含通过当前审计的 JS 来源；被排除项目保留在
inventory，其中包括 Windows 工具、node-pty、Playwright 和部分 Shiki/Three
WASM 资源，需各自源码替换或按实际 workspace 闭包排除。

`esbuild-for-hermes` 0.28.1 已源码构建成功：
`/gnu/store/jwijk8iwcxv8v9sicbhgaxjlyy7566yc-esbuild-for-hermes-0.28.1`。
已新增 `hermes-node-tui` 和离线 Node 构建脚本，使用上游直接打包 Ink 源码的
方式，并指定匹配 Python gateway。TUI 的实际构建已启动，日志
`/tmp/hermes-tui-build.log`；它依赖最新 Hermes 接口运行时构建，尚不算 H3 完成。

最新构建适配：V8 首次 GN 配置失败指出 sandbox 必须配合 libc++ hardening，
现已改用归档中的 libc++/libc++abi 源码并启用硬化继续构建，未关闭 V8 sandbox。
Hermes 集成在 obstore 离线元数据解析处失败，原因是 Cargo.lock 的 `patch.unused`
还声明了 `object_store` 0.12.2 的精确 Git 来源；已扩展 locker 覆盖该来源，
实际使用的 registry `object_store` 0.12.3 不变，再次构建正在进行。

Hermes 后端隔离：确认 Hatch 提前加载动态版本插件会在构建 Pydantic 本身时
混用固定 channel Pydantic 和私有 pydantic-core。构建脚本已按项目声明只在
需要时加载该插件，保持锁定版本；新定义实际构建仍在推进。

H17 进度：固定 channel 已提供 `sqlite-next` 3.53.4，满足 Hermes 源码要求的
WAL-reset 修复版本。新增 `python-for-hermes`，保留 Python 3.12 ABI，替换
SQLite 输入；正在源码构建，日志 `/tmp/hermes-python-build.log`。Hermes 的
构建解释器和安装后解释器均改为此运行时；最终包仍需重新构建，WAL 功能尚未验证。

前端原生来源锁：已新增 `scripts/lock-hermes-native.py` 和
`hermes-native-lock.scm`，固定 rolldown 1.2.1、Tailwind CSS 4.3.3、
Lightning CSS 1.32.0 官方源码归档及 592 个去重后的 registry crate。
对应三个 Node binding 定义位于 `hermes-node-native.scm`，使用 Rust 1.95
离线编译；Tailwind oxide 的实际构建已启动，日志 `/tmp/hermes-oxide-build.log`。
其他两个 binding 尚未完成实际构建；产物接入 Web 构建、桌面构建仍待推进。
node-pty 1.1.0 官方 `v1.1.0` 标签源码已取得，仍待编译和安装。

H17 构建更新：`python-for-hermes` 已完成默认构建，主输出为
`/gnu/store/slr8gncrvhy49k63bj4f69z7ixvpbrp9-python-for-hermes-3.12.12`。
该运行时使用 SQLite 3.53.4；使用它的最新 Hermes 接口/TUI 组合构建已启动，
日志 `/tmp/hermes-tui-sqlite-build.log`。这里只确认构建完成，数据库 WAL 行为仍未验证。

前端 binding 构建更新：Tailwind oxide 4.3.3 已源码构建完成，输出
`/gnu/store/inq0q2i08n3fmb6v89amr43h2v4ribs2-tailwind-oxide-for-hermes-4.3.3`。
rolldown 和 Lightning CSS 的实际源码构建已启动（各 1 个 Cargo 任务），日志
`/tmp/hermes-rolldown-build.log`、`/tmp/hermes-lightningcss-build.log`。
新增 `node-pty-for-hermes`，根据上游 Linux binding.gyp 构建 Unix C++ binding，
使用锁定 node-addon-api 7.1.1 和 Guix Node 头文件，本地编译 TypeScript；
不运行 prebuild/npm install 脚本。实际构建已启动，日志 `/tmp/hermes-node-pty-build.log`。

node-pty 构建已完成：
`/gnu/store/jdlgp83sdcza45zxfkjl4hkjg645qqp3-node-pty-for-hermes-1.1.0`。
这里只确认 Linux binding 与 JavaScript 产物构建成功；桌面集成尚未完成。
- 构建日志：`/tmp/hermes-interfaces-build.log`、`/tmp/codex-voice-build.log`。
  日志路径和“正在进行”仅为本次实施记录；继续工作时必须检查实际进程及退出结果。

## 范围和完成标准

- 面向当前 `x86_64-linux`；Windows、macOS、Android 专用组件单列为范围外。
- 补齐上游运行功能需要的源码、依赖、资源和程序入口。开发工具、网站和发行
  安装器不自动算作运行组件。外部插件生态需要逐项登记，不能承诺无限范围的全覆盖。
- 原生程序从源码编译；不得用下载 wheel、V8 静态库、Electron 二进制、浏览器
  二进制或其他预编译载荷充当补全。源码不可得的后端明确标为条件项。
- 联网解析依赖在构建外完成，输入固定版本、提交和哈希；Guix 构建离线。
- 所有 Guix 命令显式使用 `guix time-machine -C channels.scm`。
- 大型构建明确设置资源和静默超时；Codex 保留 `--max-silent-time=7200`，
  V8/Electron 等按构建日志调整，不靠取消超时掩盖问题。
- 按用户安排，先补组件，之后统一开展功能验证。期间只做产生可用构建产物所需
  的编译和元数据检查，保留现有构建检查，不提前开展新一轮完整集成测试。
- “已补全”和“已验证”分别记录。登录、凭据、远端服务和真实网络环境是运行条件，
  不应被误报为缺失代码；打包不会自动启动服务或修改用户配置。

## 缺口清单

以下编号保留最初发现的补全范围，便于追踪；其中部分已有独立源码产物，
不代表仍需从零打包。当前剩余工作以文首“当前缺口摘要”和“剩余工作的具体拆分”为准。
来源锁、独立组件成功、最终组合接入及功能验证必须分别记录。

### Codex

| 编号 | 缺少的组件 | 补全工作及依赖 |
|---|---|---|
| C1 | `codex-code-mode-host` 和匹配的 V8 | 固定 rusty_v8/V8 源码、子依赖和 GN/Ninja 工具；消除构建脚本自动下载工具链及静态库的路径，源码构建引擎和 host，安装到上游可发现的位置。当前 direct 模型目录只是绕过方案。 |
| C2 | `codex-voice-host` 和音频运行资源 | 增加 Cargo 构建目标及资源布局；处理 ALSA/CPAL、Opus、GStreamer 和插件等依赖。上游 crate 要求 GStreamer 1.28 接口，先核对固定 channel 是否满足，不擅自降级要求。 |
| C3 | 托管的 Codex zsh | 查明上游补丁版 zsh 的准确源码和补丁，不直接下载 DotSlash manifest 中的二进制；源码构建并安装到 `codex-resources/zsh/bin/zsh`，普通 Guix zsh 不能未经确认就宣称等价。 |
| C4 | 独立 SDK/辅助程序的发行范围 | 核对官方 Linux 布局与本包差异；CLI 已有 `exec`、`app-server` 子命令，缺少同名独立程序不等于能力缺失。只有消费者确实依赖独立入口时才增加。TypeScript SDK 如需使用，作为独立包而非 CLI 必需依赖。 |

最大的前置工作是 C1：`V8_FROM_SOURCE` 本身不能保证离线源码构建；GN、工具链和
V8 的源码依赖同样需要锁定。C2/C3 可与其分别维护，避免改动一个组件就重建全部组件。
补全 C1 后恢复使用上游模型目录，保留 direct 目录只能作为明确标注的兼容选项。

### Hermes

当前是核心 Python CLI，且关闭运行时自动 pip 安装。以下可选依赖不能指望第一次
调用时自动补齐。清单依据固定源码的 `pyproject.toml`、`tools/lazy_deps.py` 和
Node workspace；同组依赖去重，并与现有核心 lock 比较后只增加真实缺失项。

| 编号 | 缺少或未完整提供的组件 | 补全工作及依赖 |
|---|---|---|
| H1 | MCP 客户端/服务相关依赖 | `mcp`、`httpx2`、Starlette；补全 stdio/HTTP 所需依赖和入口。仅附带 `optional-mcps` 配置不代表对应外部服务器已安装。 |
| H2 | ACP | `agent-client-protocol`；恢复当前打包时移除的 ACP 入口。 |
| H3 | Node TUI | `ui-tui`、本地 Ink/shared workspace、Node 和 JS 构建依赖；从锁定源码构建，提供稳定启动入口，处理安装路径。 |
| H4 | Web dashboard | FastAPI、Uvicorn、Starlette、python-multipart；构建 `web` 前端及 shared workspace，安装静态资源，补齐后端入口；可选 uvloop 从源码构建。 |
| H5 | Linux 桌面端 | `apps/desktop`、shared workspace、源码构建 Electron、node-pty 等原生依赖，安装图标/桌面入口；去掉 Electron 自动下载及应用内更新路径。依赖 H4 中共享的构建基础，桌面端本身单独构建。 |
| H6 | 原生模型 SDK 与认证 | Anthropic、Bedrock/boto3、Vertex/google-auth、Azure Identity、Mistral SDK。保持上游固定版本并整合共同依赖。已有 OpenAI 兼容接口不替代这些原生接口。 |
| H7 | 搜索和图像生成后端 | Exa、Firecrawl、Parallel Web、fal-client；API 凭据属于用户配置。已有核心文档提取依赖不要重复列为缺失。 |
| H8 | 云终端后端 | Modal、Daytona、Vercel SDK；本地 terminal 已存在。Docker、SSH 等工具后端另外核对外部可执行文件的发现和运行条件。 |
| H9 | 消息网关 | Telegram、Discord（含 voice 依赖）、Slack、Matrix（含加密依赖）、钉钉、飞书、企业微信 callback、Teams、Google Chat；另核对 Home Assistant、SMS 集成所需共享依赖。提供 gateway 入口和可选服务配置。 |
| H10 | 云语音接口 | Edge TTS、ElevenLabs、Mistral STT/TTS、SILK 解码 `pilk`；底层编解码器必须源码构建。 |
| H11 | 本地语音识别与音频采集 | faster-whisper、CTranslate2、ONNX Runtime、sounddevice/PortAudio、NumPy、相关原生依赖；模型资源单独锁定或由用户配置，不能隐式下载。 |
| H12 | 唤醒词 | openWakeWord、TFLite Runtime、sherpa-onnx、sentencepiece、ONNX Runtime、音频依赖及模型资源；TFLite 的源码、外部 CMake 依赖和 Python/NumPy 绑定均需补齐，即使 Linux 默认选择 ONNX。Porcupine 单列源码/许可条件项，不能承诺用闭源原生载荷完成源码构建。Darwin 专用 LiteRT 路径不纳入 Linux。 |
| H13 | 记忆服务 | Honcho、Supermemory、Mem0 SDK；目录中插件的本地嵌入/数据库/服务依赖另做清单，安装插件文件不等于后端可运行。 |
| H14 | 技能依赖及轨迹上传 | Google Workspace、YouTube transcript、`huggingface-hub` 轨迹上传；逐项核对已附带 skills/plugins 的外部程序、SDK 和模型要求，记录可以直接运行与需要额外服务的边界。 |
| H15 | OTLP 监控导出 | OpenTelemetry SDK 和 OTLP HTTP exporter，整合 protobuf 等公共依赖。 |
| H16 | 浏览器和 computer-use | 默认浏览器工具调用 agent-browser CLI；补齐该 Node 工具、浏览器/驱动及其发现路径。另登记 Camofox、browser-use 和远程浏览器插件后端，核对各自 SDK/外部程序，源码构建所需浏览器及驱动，禁止首次运行下载浏览器。上游 macOS cua-driver 集成单列为平台外项。 |
| H17 | SQLite WAL 支持 | 为 Hermes 提供修复 WAL-reset 问题的 SQLite 和匹配 Python 绑定，确认上游判断条件后选版本；当前 DELETE 模式数据库可用，这是运行兼容性/性能补全。 |

上游 `all` extra 刻意不包含很多 lazy dependencies，不能用安装 `all` 作为完整覆盖
的证明。`cron`、`vision`、`pty`、`nemo-relay` 是空兼容 extra，相关核心能力已提供，
不算新增缺口。`dev` 是开发依赖；Termux 专用组合、macOS/Windows 发行产物不纳入本轮。
浏览器、插件的详细边界在 H14/H16 源码审计后收敛；这些项尚不能称为已穷尽所有外部生态。

H14/H16 的外部程序候选另分三类，后续逐条确认调用条件和来源：

| 类别 | 已发现的程序候选 | 计划 |
|---|---|---|
| 常见 Linux 工具 | `convert`、`ffmpeg`、`ffprobe`、`git`、`node`、`npm`、`pdftocairo`、`pdftoppm`、`soffice`、`ss`、`netstat`、`lsof`、`pactl`、`paplay`、`docker`、`uv` | 核对固定 channel 的源码包和实际输出，按技能需求组成可选工具集合，接入明确的发现路径；Docker 等仍需单独登记守护进程条件。 |
| 专用工具或服务客户端 | `gws`、`brv`、`ollama`、`openviking-server`、`buzz`、`raft` | 确认是否必需、有无现成 SDK 路径、源码与许可，以及所需服务/模型；必要时独立打包，来源不明的保留待确认。 |
| 平台条件候选 | `brew`、`system_profiler`、`taskkill` | 核对源码中的平台判断，确认后列为 Linux 范围外，避免误计为 Linux 缺包。 |

候选来自静态扫描，不能直接当成所有功能的必需依赖。清单中的 85 个动态调用
还需逐项解析；Python import 候选也须区分仓库本地模块、已有依赖与真正缺失包。
这项审计属于补全准备，实际执行技能和外部程序仍安排在统一验证阶段。

建议维护可组合的 core、interfaces、integrations、audio、desktop 依赖集合，以及
面向 Linux 的完整组合包。组件共享同一源码版本和锁，入口实际使用包含对应依赖的
运行时，不能仅安装若干独立 Python 包就假定私有 Python 环境会发现它们。

### sing-box

| 编号 | 缺少的组件 | 补全工作及依赖 |
|---|---|---|
| S1 | NaiveProxy outbound | 源码构建匹配上游绑定的 Cronet/Chromium 及其工具链，替换预编译库输入；启用 `with_naive_outbound`，重算 Go 来源锁。按之前安排留后续。 |
| S2 | Tailscale 集成 | 源码构建依赖的 Web 客户端并处理嵌入资源，启用 `with_tailscale`，重新锁定 Go/JS 来源。按之前安排留后续；这不是额外安装独立 tailscaled 就能替代的功能。 |
| S3 | 系统服务集成 | 可选 Shepherd service、配置示例和数据目录约定；记录 TUN/路由/权限要求，不在安装包时启动。 |

其余上游默认 build tags 已启用。本轮以该版本 Linux 默认发行功能为比较基线，
额外实验 tag 需登记其用途再决定，不能未经审计就宣称覆盖所有非默认特性。

### dae

| 编号 | 缺少的组件或配套 | 补全工作及依赖 |
|---|---|---|
| D1 | GeoIP/geosite 规则数据 | 为实际配置使用的数据提供独立、可更新、来源固定的数据包；如上游只给生成产物，锁定原始数据和生成工具，明确数据许可；配置 `DAE_LOCATION_ASSET`。不使用地理规则时不是必需输入。 |
| D2 | 系统服务集成 | Shepherd service、示例配置、状态/资源路径、权限和内核前提说明；不自动启动。 |

dae 普通版和 trace/eBPF 均已源码构建，目前没有发现被主动关闭的上游运行组件。
实际 eBPF 加载和流量转发属于后面的验证任务。独立第三方管理 UI 不自动纳入 dae 本体。

## 实施顺序

| 阶段 | 工作 | 交付物和退出条件 |
|---|---|---|
| 1 | 固定清单和锁定机制 | 对照官方发行布局；补齐 Hermes extras/lazy dependencies、JS 来源锁和外部资源清单，分类为可源码构建、外部服务、平台外或来源待确认；不更改已有 channel。 |
| 2 | Hermes 常用协议和 SDK | H1/H2/H6/H7/H8/H9/H13/H14/H15 的 Python 依赖及原生传递依赖源码包、可组合运行时和入口；插件深层依赖单列，H14 持续更新。 |
| 3 | Codex 完整执行器 | C1 源码构建 V8 与 host，C3 补丁 zsh，C4 发行入口审计；形成可构建的完整 code mode 包布局。V8 若需要新工具链就在仓库定义，不隐式切换 channel。 |
| 4 | Hermes 界面与数据库 | H3/H4/H17，交付源码构建的 Node TUI、dashboard、匹配 SQLite/Python；H5 的 Electron 工具链在此准备。 |
| 5 | 音频、浏览器和桌面 | C2、H5/H10/H11/H12/H16；重型引擎独立包化，明确模型和闭源条件项的处理结果。源码不可得的后端列为无法按本目标补齐，提供可源码构建的替代选项，不算已完成。 |
| 6 | 网络工具配套 | D1/D2/S3，交付可选数据/服务包、使用示例和权限说明。 |
| 7（延后） | sing-box 两个预留功能 | S1/S2，沿用 NaiveProxy/Tailscale 后续处理的约定，不混入前面阶段；完成后进入相同验收。 |
| 8 | 统一验证 | 对已补齐组合执行下表。阶段 7 如继续延期，在报告中保留明确缺口，其他阶段可先统一验收。 |

不承诺未经实际构建依据的工期。V8、Electron/Chromium、ONNX/CTranslate2、
GStreamer 版本适配和补丁 zsh 来源确认是主要不确定项；分别记录构建耗时、峰值
内存、磁盘和静默时长。一个组件受阻时继续推进不依赖它的项目。

## 补全后的统一验证安排

| 对象 | 验收范围 |
|---|---|
| 全部包 | 固定 channel 的默认 graft 构建、离线依赖闭包、入口/资源发现、无自动二进制下载、可写状态与 store 分离；核对每项是否已补全及已验证。 |
| Codex | 实际 V8 执行、host 通信、要求 code mode 的模型工具调用、Linux sandbox、托管 zsh、语音 host 的设备/编解码器发现；真实模型调用需已有用户授权和可用凭据。 |
| Hermes | CLI/TUI/Web/桌面启动，ACP/MCP 交互，网关适配器、SDK、搜索、云终端、语音/唤醒、浏览器、记忆、技能、监控；SQLite WAL 与 FTS5。先本地/模拟服务，再验证具备凭据的真实后端。 |
| sing-box | 启用 tag 清单、配置解析、已选协议的端到端连接、TUN/路由、服务生命周期；S1/S2 补全后加入专项用例。 |
| dae | 在合适 Linux 内核上加载/挂载 eBPF、实际路由/DNS/流量、trace、地理规则与数据路径、服务启停/重载。 |

报告将区分通过、失败、未验证、外部条件不满足、平台外和源码不可得；没有凭据或
音频设备的后端保留“未验证”，不能把 import 成功当作端到端功能通过。

## 附录：固定版本 Hermes 声明的完整可选依赖清单

保留上游版本约束供后续锁定；此表列出声明，不意味着每个传递依赖都缺失。
共享依赖须与现有核心 lock 去重。

| extra | 直接依赖/组合 |
|---|---|
| `uvloop` | `uvloop>=0.15.1,<0.24; sys_platform != 'win32' and sys_platform != 'cygwin' and sys_platform != 'android' and platform_python_implementation != 'PyPy'` |
| `anthropic` | `anthropic==0.87.0` |
| `exa` | `exa-py==2.10.2` |
| `firecrawl` | `firecrawl-py==4.17.0` |
| `parallel-web` | `parallel-web==0.4.2` |
| `fal` | `fal-client==0.13.1` |
| `edge-tts` | `edge-tts==7.2.7` |
| `modal` | `modal==1.3.4` |
| `daytona` | `daytona==0.155.0` |
| `vercel` | `vercel==0.7.2` |
| `dev` | `debugpy==1.8.20`；`pytest==9.1.1`；`pytest-asyncio==1.3.0`；`mcp==2.0.0`；`httpx2==2.7.0`；`starlette==1.3.1`；`ty==0.0.21`；`ruff==0.15.10`；`setuptools==83.0.0` |
| `messaging` | `python-telegram-bot[webhooks]==22.8`；`discord.py[voice]==2.7.1`；`aiohttp==3.14.3`；`brotlicffi==1.2.0.2`；`slack-bolt==1.30.0`；`slack-sdk==3.44.1`；`qrcode==7.4.2` |
| `cron` | 空兼容别名，无新增依赖 |
| `slack` | `slack-bolt==1.30.0`；`slack-sdk==3.44.1`；`aiohttp==3.14.3` |
| `matrix` | `mautrix[encryption]==0.21.1`；`aiosqlite==0.22.1`；`asyncpg==0.31.0`；`aiohttp-socks==0.11.0`；`aiohttp==3.14.3` |
| `wecom` | `defusedxml==0.7.1` |
| `tts-premium` | `elevenlabs==1.59.0` |
| `voice` | `faster-whisper==1.2.1`；`sounddevice==0.5.5`；`numpy==2.4.3` |
| `wake` | `openwakeword==0.6.0`；`onnxruntime==1.27.0`；`sherpa-onnx==1.13.4`；`sentencepiece==0.2.2`；`pvporcupine==4.0.3`；`sounddevice==0.5.5`；`numpy==2.4.3`；`ai-edge-litert==2.1.6; platform_system == 'Darwin'` |
| `honcho` | `honcho-ai==2.2.0` |
| `supermemory` | `supermemory==3.50.0` |
| `mem0` | `mem0ai==2.0.10` |
| `vision` | 空兼容别名，无新增依赖 |
| `pty` | 空兼容别名，无新增依赖 |
| `mcp` | `mcp==2.0.0`；`httpx2==2.7.0`；`starlette==1.3.1` |
| `nemo-relay` | 空兼容别名，无新增依赖 |
| `homeassistant` | `aiohttp==3.14.3` |
| `sms` | `aiohttp==3.14.3` |
| `teams` | `microsoft-teams-apps==2.0.13.4`；`aiohttp==3.14.3` |
| `computer-use` | `mcp==2.0.0`；`httpx2==2.7.0`；`starlette==1.3.1` |
| `acp` | `agent-client-protocol==0.9.0` |
| `mistral` | `mistralai==2.4.8` |
| `otlp` | `opentelemetry-sdk==1.39.1`；`opentelemetry-exporter-otlp-proto-http==1.39.1` |
| `bedrock` | `boto3==1.42.89` |
| `vertex` | `google-auth==2.55.1` |
| `azure-identity` | `azure-identity==1.25.3` |
| `termux` | `python-telegram-bot[webhooks]==22.8`；`hermes-agent[cron]`；`hermes-agent[mcp]`；`hermes-agent[honcho]`；`hermes-agent[acp]` |
| `termux-all` | `hermes-agent[termux]`；`hermes-agent[google]`；`hermes-agent[homeassistant]`；`hermes-agent[sms]`；`hermes-agent[web]`；`hermes-agent[pty]` |
| `dingtalk` | `dingtalk-stream==0.24.3`；`alibabacloud-dingtalk==2.2.42`；`qrcode==7.4.2` |
| `feishu` | `lark-oapi==1.6.8`；`qrcode==7.4.2` |
| `google` | `google-api-python-client==2.194.0`；`google-auth==2.55.1`；`google-auth-oauthlib==1.3.1`；`google-auth-httplib2==0.3.1`；`httplib2==0.32.0`；`pyasn1==0.6.4` |
| `google-chat` | `google-cloud-pubsub==2.39.0`；`google-api-python-client==2.194.0`；`google-auth==2.55.1`；`google-auth-oauthlib==1.3.1`；`google-auth-httplib2==0.3.1`；`httplib2==0.32.0`；`pyasn1==0.6.4` |
| `youtube` | `youtube-transcript-api==1.2.4` |
| `web` | `fastapi==0.133.1`；`uvicorn==0.41.0`；`starlette==1.3.1`；`python-multipart==0.0.32` |
| `all` | `hermes-agent[cron]`；`hermes-agent[pty]`；`hermes-agent[mcp]`；`hermes-agent[uvloop]`；`hermes-agent[homeassistant]`；`hermes-agent[sms]`；`hermes-agent[acp]`；`hermes-agent[google]`；`hermes-agent[web]`；`hermes-agent[youtube]` |

此外，lazy dependency 中存在不由上述 extras 完整表达的项目：
`stt.silk`（pilk）、`tool.trace_upload`（huggingface-hub），以及独立的平台/工具分组。
以下保留完整 feature key，实施时逐个标记现有核心已覆盖、待补齐或平台外：

- `provider.anthropic`
- `provider.bedrock`
- `provider.vertex`
- `provider.azure_identity`
- `search.exa`
- `search.firecrawl`
- `search.parallel`
- `export.otlp`
- `tts.mistral`
- `tts.edge`
- `tts.elevenlabs`
- `stt.mistral`
- `stt.faster_whisper`
- `stt.silk`
- `wake.openwakeword.tflite`
- `wake.openwakeword`
- `wake.sherpa`
- `wake.porcupine`
- `image.fal`
- `memory.honcho`
- `memory.supermemory`
- `memory.mem0`
- `platform.telegram`
- `platform.discord`
- `platform.slack`
- `platform.matrix`
- `platform.dingtalk`
- `platform.feishu`
- `platform.wecom_callback`
- `platform.teams`
- `platform.google_chat`
- `terminal.modal`
- `terminal.daytona`
- `terminal.vercel`
- `skill.google_workspace`
- `skill.youtube`
- `tool.acp`
- `tool.dashboard`
- `tool.vision`
- `tool.doc_extract`
- `tool.computer_use`
- `tool.trace_upload`

### 暂停检查点（2026-10-05）

Hermes 音频完整源码组合 handle76988 已成功完成，Guix 输出
`/gnu/store/h5lym17w9z0dv67l5w3hngl9p0xzb79i-hermes-agent-audio-0.21.5`。
这是源码构建交付记录，不代表功能验收。

React 正式发布重试 handle98615 已修复 AST 类型版本与 `@types/invariant` 缺口，
在收到暂停请求时已通过 Hooks 和 renderer/server 的多个 bundle，仍未完成最终
打包；为切换机器已用 Ctrl-C 中止（exit 130），后续需从同一构建命令重新运行，
不把该中断记为构建失败。Codex V8 host handle25919 同样为切换机器而中止（exit
130）；此前 Ninja 可见进度约 1661/2434，后续重新运行完整构建。当前没有后台构建
应继续占用此机器。统一功能验证仍按原计划延后。
