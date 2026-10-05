# Moldflow Insight HPC 待办

## 目标

用即将到手的三台 x86 机器缩短 Moldflow 的整体工作周期，并尽可能利用空闲算力。先建立可用、可测量的 PBS 集群；再根据实际工作负载决定是否引入 Guix、Goblins 或其他工具。当前不预设操作系统、安装方式或最终拓扑。

关键预期：单个普通 Moldflow 分析主要在一台机器上使用多线程；多节点的直接收益主要来自同时运行多个独立分析，以及 DOE、优化、Runner Balance 等产生的子分析。不要先假定一项普通分析会因为有三台机器就缩短到三分之一。Autodesk 说明其 Linux HPC 求解器不是 MPI 程序，SCM 可将特定作业产生的子分析分配到其他节点。[HPC 概念说明](https://help.autodesk.com/cloudhelp/2026/ENU/MoldflowInsight-CLC-InstallSupplement/files/linux-install-solvers-only/MFLO_HPC_INSTALL_CONCEPT.html)

## 阶段 0：现在可以做的准备

- [ ] 收集三台机器的预期规格：CPU 型号/核心数、内存、系统盘与数据盘、网卡速度、是否有远程管理功能。
- [ ] 确认三台机器的网络条件：能否接有线局域网、交换机速度、固定地址/DHCP 保留、DNS/主机名、是否位于同一网络。
- [ ] 决定是否有一台机器兼任管理/登录节点。初期可以让一台兼任 PBS 管理与计算节点，避免为了角色划分浪费算力；若它不适合长期运行，再调整。
- [ ] 确认现有 Windows 机器是否承担 Synergy 前处理和后处理；Linux HPC 方案只需要 Insight solver，Synergy 不必装在计算节点上。
- [ ] 检查 Autodesk 账户、订阅/许可类型和软件下载权限；确认 Insight Linux thin-client 下载入口可用，并记录许可配置所需信息。
- [ ] 找出 2–3 个有代表性的真实分析作为基准案例：普通 Fill/Pack/Cool/Warp、一个较大模型、以及 DOE/优化（若日常确实会用）。记录模型规模、分析设置、当前运行时间和结果校验方法。
- [ ] 记录希望改善的指标：单个分析完成时间、一天可完成的分析数、排队等待时间、人工提交/收集结果时间。HPC 的收益不只看单作业耗时。
- [ ] 预先定义基准矩阵和记录表，实际测量等节点到手、作业跑通后进行：1 节点 1 作业、单节点并发、3 节点独立作业、3 节点 DOE/优化。记录 wall time、总吞吐量、排队时间、CPU/内存/磁盘利用率、失败率和许可证占用；用相同输入和设置比较。
- [ ] 先向许可管理员/Autodesk 确认许可类型、可同时 checkout 的求解器许可数量及 DOE 子作业的许可行为，再据此设置 PBS 并发上限。不要把“三台机器”直接等同于“三个并发分析许可”。

## 阶段 1：机器到手后，先建立可重复的单机基线

- [ ] 安装并更新操作系统，确认三台机器的 OS 版本和运行库满足所选 Moldflow 版本支持要求。
- [ ] 用同一个代表性案例在一台候选计算机上跑通命令行 `runstudy`；保存输入、日志、输出和运行时间。
- [ ] 检查求解器实际使用的线程数、峰值内存、CPU 利用率、磁盘 I/O 和临时目录用量。
- [ ] 在三台机器分别运行同一案例，确认结果可读且数值一致/在预期误差内；记录每台性能。这样能看出机器之间是否存在明显差异。
- [ ] 比较单机不同线程数的耗时，找到各节点合理的并发/线程配置，避免把“核心数更多”直接等同于“更快”。

## 阶段 2：下载和部署 Insight thin client

- [ ] 下载 Autodesk 提供的 Linux thin-client 安装包，核实版本、校验信息和支持平台。
- [ ] 选择部署方式：共享文件系统上的一份只读安装，或先在每台机器部署。若使用共享安装，验证所有计算节点都能读取并执行；不要因为 Guix 尚未决定而阻塞基础安装。
- [ ] 按 Autodesk 说明配置许可服务和 `mfclient.env`，逐节点测试许可证获取。
- [ ] 配置作业目录、临时目录和结果目录的读写权限；确认 SCM 启动的子进程能访问所需文件。
- [ ] 验证每台机器的薄客户端都能独立运行同一案例，并保存可复现的安装/配置步骤。

## 阶段 3：部署 PBS 并打通一个端到端作业

- [ ] 选定 PBS 实现与版本，阅读其安装要求；先采用最简单、易维护的三节点布局。
- [ ] 配置 PBS 管理/调度服务及每个执行节点的 MOM 服务，登记 CPU、内存等资源。
- [ ] 配置共享作业目录或明确的数据 staging 方案；PBS 能分配节点不代表模型文件自动可见。
- [ ] 测试 SSH 节点间无密码访问。Autodesk 的集群示例需要主执行节点在获分配的节点上启动 SCM。[集群配置说明](https://help.autodesk.com/cloudhelp/2026/ENU/MoldflowInsight-CLC-InstallSupplement/files/linux-install-solvers-only/High-Performance-Clusters-HPC/MoldflowInsight_CLC_InstallSupplement_linux_install_solvers_only_High_Performance_Clusters_HPC_To_configure_Moldflow_Insight_to_html.html)
- [ ] 研究 Autodesk 随 thin-client/文档提供的 PBS 示例脚本和 `cluster_runstudy.sh`，按本集群路径、资源和许可配置调整。
- [ ] 先提交单个普通分析：验证排队、节点分配、求解启动、日志/退出状态、结果文件和失败诊断。
- [ ] 再验证 DOE/优化/Runner Balance 子分析是否能由 SCM 分布到 PBS 分配的节点；同时检查 SCM 清理和作业取消行为。
- [ ] 明确资源请求模板：单作业所需核心/线程数、内存、运行时长、临时空间，以及 DOE 子作业的节点数和并发度。

## 阶段 4：衡量三台机器的真实收益

- [ ] 在同一工作负载下分别测量：单节点单作业、单节点多作业、三节点多作业、三节点 DOE/优化作业。
- [ ] 比较总完成时间、每小时完成的分析数、平均排队时间、CPU/内存利用率和失败率。
- [ ] 检查共享存储和网络是否成为瓶颈；若分析文件频繁读写，比较本地 scratch 与共享目录方案。
- [ ] 制定合适的排队策略，优先避免节点过载和许可证不足；从短作业/简单队列开始，依据使用体验再细化。
- [ ] 用结果决定是否让管理节点也参与计算，以及是否需要增加内存、存储或网络带宽。

### 文件系统起步策略

- [ ] 首轮采用简单的混合方案：共享文件系统放 thin-client 安装、输入 study 和最终结果；每个计算节点用本地 scratch 放临时文件/求解工作目录；作业结束后把需要保留的结果写回共享目录。
- [ ] 先验证 SCM 子作业从其他节点访问输入和输出路径是否正常。Autodesk 的 thin-client 包适合放在多节点共享文件系统；其集群说明也以共享安装为常见配置。
- [ ] 统计模型、结果和临时文件的大小与读写量，并观察共享盘利用率。如果共享盘没有成为瓶颈，就保持简单；若成为瓶颈，再比较全共享工作目录与 PBS 作业启动/结束时 stage-in/stage-out 到本地盘的周转时间、复杂度和故障恢复成本。
- [ ] 比较完整作业周转时间（复制输入 + 求解 + 复制结果），不要只比较求解阶段；Moldflow 临时文件和 DOE 子作业可能改变 I/O 特征。

## 阶段 5：再决定 Guix、容器或 Goblins 是否值得

- [ ] 研究 Guix-HPC 的部署模式和工具。`hpc.guix.info` 的核心方向是可复现的软件部署与科学工作流；它不是 PBS/Slurm 一类的批处理调度器，也不会自动把 Moldflow 求解器变成分布式求解器。[Guix-HPC 介绍](https://hpc.guix.info/about/)
- [ ] 分别评估三种 Guix 用法，不要把它们混为一谈：在现有 Linux 上使用 Guix 管用户态软件；用 Guix System 管理节点操作系统；用 Guix Workflow Language 等工具描述工作流并提交给调度器。
- [ ] 当前首选 Guix System；确认 Moldflow 当前版本的 Linux 支持矩阵和实际依赖。Autodesk 当前列出的 Insight Linux 支持平台是 RHEL 8.6+ / 9.0+，Guix System 未列为受支持平台。若坚持 Guix System，先在一台节点上完整验证许可、求解、SCM 和多节点 DOE，并接受这可能属于 Autodesk 未支持的平台；若官方支持优先级更高，再考虑受支持的 RHEL 系底层系统上安装 Guix 作为包管理器。[平台支持列表](https://help.autodesk.com/cloudhelp/2026/CHT/MoldflowInsight-CLC-InstallSupplement/files/system-requirement/MFLO_SUPPORTED_PLTFRMS_CPT.html)
- [ ] 确认 Autodesk thin-client 的专有二进制、许可组件、运行库和 SCM 能否在目标 Guix 环境中可靠运行；先做小型可重复性验证，不预设求解器一定适合打成普通 Guix 包。
- [ ] 将 Guix 的潜在收益落到具体需求上：固定辅助脚本和分析工具版本、复现作业环境、部署 Python/后处理工具、版本化集群配置。与 PBS 提供的队列、资源分配和节点管理分开评估。
- [ ] 先让 PBS + 原生 thin client 稳定运行，再评估 Guix 的价值：可复现环境、依赖管理、部署便利性。确认 Autodesk 支持边界和许可证服务要求后，再尝试包装；不要把求解器可运行性与“必须由 Guix 管理”绑定。
- [ ] 记录 PBS 真实痛点：提交体验、参数模板、状态通知、工作流、结果归档、多个集群统一入口等。
- [ ] 若主要需求是更方便的提交和监控，可先在 PBS 外层加轻量脚本/界面；PBS 继续负责节点分配。
- [ ] 若要探索 Goblins，先选一个非关键流程做原型（如提交包装、状态通知，或将独立分析作为可领取任务），不接管生产调度。
- [ ] 只有当确有 PBS 无法满足的需求时，再估算自研调度的开发、故障恢复、权限、资源隔离、审计和长期维护成本。

## 当前暂缓决定

- [ ] Guix System 的具体版本、节点配置如何回滚，以及它与 Autodesk 官方支持平台之间的取舍。
- [ ] PBS 服务器是否独占一台机器、是否三台都作为计算节点。
- [ ] 共享存储具体实现及网络升级需求。
- [ ] 是否需要 Goblins，以及它应当做 PBS 上层控制面还是自研调度器。
- [ ] 是否购买 GPU：当前 Insight 求解器没有 GPU 计算选项；Autodesk 说明该选项在 2017 版移除。GPU 可用于图形显示，但不应作为当前求解加速的采购依据。[Autodesk GPU 说明](https://www.autodesk.com/support/technical/article/caas/sfdcarticles/sfdcarticles/Is-it-possible-to-use-the-GPU-in-parallel-with-the-CPU-in-Moldflow.html)

## 初步完成标准

- [ ] 三台机器都能被 PBS 正确识别并分配资源。
- [ ] 普通分析可通过队列提交，能可靠地启动、记录日志并回收结果。
- [ ] 至少一个实际 DOE/多分析工作负载能利用多个节点（若该类作业属于日常工作）。
- [ ] 有基准数据证明三台机器提高了整体吞吐量，并知道单作业耗时是否改善、改善多少。
- [ ] 有一份可复现的安装、配置、提交和故障排查记录。
