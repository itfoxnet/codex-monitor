# Codex Monitor 可执行任务清单

更新时间：2026-08-06  
架构基线：SwiftUI + 工作台托管 Codex App Server（stdio），无 Hook

## 1. 状态规则

- `[ ]` 待开始，`[~]` 进行中，`[x]` 已完成，`[!]` 阻塞。
- 每项任务控制在 0.5–2 个理想工程日；更大任务先拆分。
- “完成”要求交付物、测试和验收条件同时成立。
- 会产生真实模型用量的 E2E、签名、公证和外部分发需单独确认。
- 不修改全局 Codex 配置，不安装 Hook，不依赖私有 IPC。

## 2. 角色

| 缩写 | 角色 | 核心责任 |
|---|---|---|
| PM | 产品经理 | 范围、优先级、用户故事、验收和里程碑 |
| UX | 产品 / UX 设计师 | 经理工作台、职员卡、举手、审批和无障碍 |
| MAC | macOS SwiftUI 工程师 | 应用、界面、状态、通知、缓存和性能 |
| INT | Codex 集成 / 协议工程师 | App Server、JSON-RPC、事件、审批请求和兼容 |
| QA | 测试工程师 | 用例、自动化、E2E、性能、恢复和发布验收 |
| SEC | 安全与隐私工程师 | RPC 白名单、审批安全、脱敏和威胁模型 |
| REL | 构建与发布工程师 | Xcode 工程、CI、签名、公证和回滚 |
| DOC | 技术写作者 | 首次启动、诊断、隐私和用户指南 |

## 3. 当前关键路径

```text
REL-01 → INT-01 → INT-02 → INT-03 → INT-04 → INT-05 → INT-06
                    └──────────────→ DATA-01 → DATA-02 → DATA-03

UX-01 → UI-01 → UI-02 → UI-03 → UI-04 → E2E-01 → PERF-02 → REL-04
                    INT-06 ────────────────┘
```

## 4. 当前执行结论

本地 Alpha 的设计、实现、自动化测试、真实只读集成、原生界面验收和 ad-hoc 应用包已经完成。后续队列只包含需要模型用量、持续运行、额外测试环境、外部参与者或发布权限的工作：

1. 用户确认后运行 `E2E-01` 真实任务闭环。
2. 在测试机完成 `E2E-02` 睡眠/唤醒与 `PERF-02` 8 小时长稳。
3. 完成 `LOC-01` 英文字符串目录和 `QA-03` 全量辅助功能矩阵。
4. 用户授权后执行 `REL-03` Developer ID 签名、公证与 Beta 分发。
5. 收集 Beta 数据后决定 `REL-04` / `PM-03` 正式发布。

## 5. 已完成：发现、验证与决策

- [x] **PM-00｜建立项目文档基线** — Owner: PM
  - 交付物：章程、体验、技术、质量、团队、ADR 和任务清单。

- [x] **UX-00｜固定视觉方向** — Owner: UX
  - 交付物：银行营业厅 / 调度台隐喻、紧凑职员卡和举手语义。

- [x] **INT-00｜确认本机开发基线** — Owner: INT
  - 结果：macOS 26.3、Xcode 26.2、Codex CLI 0.144.1。

- [x] **G0-01｜建立只读 App Server 探针** — Owner: INT
  - 验收：初始化、list、read、loaded/list 由封闭白名单控制。

- [x] **G0-02｜验证跨实例任务可见性** — Owner: INT + QA
  - 结果：能读取保存任务，但不能读取另一个 Server 的实时 active 状态。

- [x] **G0-03｜验证 daemon/proxy 前提** — Owner: INT
  - 结果：当前安装缺少 installer 管理版 standalone Codex；daemon 不作为 MVP 前提。

- [x] **G0-04｜接受 Server 托管范围** — Owner: PM + INT + SEC
  - 决策：实时任务必须由工作台创建或显式接管；独立原生任务仅作历史。

- [x] **G0-05｜停止 Hook 路线** — Owner: PM + INT
  - 验收：ADR、架构、质量、团队和任务清单不再依赖 Hook；探针包不再构建 Hook 工具。

- [x] **G0-06｜批准 ADR-001** — Owner: PM + INT + SEC
  - 结果：状态改为 Accepted，MVP 使用应用托管 stdio App Server。

## 6. G1：工程与安全基础

- [x] **REL-01｜建立原生工程骨架** — Owner: REL + MAC；估时：1d；依赖：G0-06
  - 交付物：macOS 14+ App target、协议库、领域库、单元和 UI 测试 target。
  - 验收：空壳菜单栏应用和窗口可构建；测试可独立运行。

- [x] **INT-01｜生成版本化协议 schema** — Owner: INT；估时：1d；依赖：REL-01
  - 操作：用当前 `codex app-server generate-json-schema` 生成版本资产。
  - 验收：初始化、thread、turn、item、approval、resolved、错误和未知字段 fixtures 不含真实用户内容。

- [x] **ARC-01｜冻结模块与 Actor 边界** — Owner: MAC + INT；估时：1d；依赖：REL-01、INT-01
  - 交付物：`CodexHost`、`CodexProtocol`、`TaskStore`、`ApprovalCoordinator`、UI targets。
  - 验收：UI 不直接访问 `Process`；协议层不含产品文案。

- [x] **SEC-01｜完成 MVP 威胁模型** — Owner: SEC；估时：1d；依赖：ARC-01
  - 范围：恶意标题、命令预览、请求错配、迟到响应、日志、缓存和通知。
  - 验收：每个高风险项有防护、测试和负责人。

- [x] **SEC-02｜定义类型化 RPC 白名单** — Owner: INT + SEC；估时：1d；依赖：INT-01、SEC-01
  - 验收：发送入口不接受任意 method；禁止 shell、fs、config、删除、归档和长期权限方法。

- [x] **REL-02｜建立本地 CI 基线** — Owner: REL；估时：0.5d；依赖：REL-01
  - 验收：构建、单元测试和格式检查可重复；不触发真实模型用量。

## 7. G2：App Server、协议与状态

- [x] **INT-02｜实现 Codex 发现与 Host 进程** — Owner: INT；估时：1.5d；依赖：ARC-01
  - 验收：自定义路径、PATH、桌面资源候选、未安装和版本不兼容均有测试。
  - 验收：stdio 子进程异常退出可检测；stderr 限长脱敏。

- [x] **INT-03｜实现 JSONL RPC 与握手** — Owner: INT；估时：1.5d；依赖：INT-02、SEC-02
  - 验收：逐行、半包、非法消息、request id、server request、EOF 和取消测试通过。

- [x] **INT-04｜实现 thread/turn 托管接口** — Owner: INT；估时：2d；依赖：INT-03
  - 范围：`thread/start`、`thread/resume`、`thread/list/read`、`turn/start`、退出保护 `turn/interrupt`。
  - 验收：新任务、历史接管、非托管历史和 active turn 的所有权清楚。

- [x] **INT-05｜实现事件路由与连接代次** — Owner: INT；估时：1.5d；依赖：INT-03
  - 验收：thread/turn/item/resolved 事件按 id 路由；重连后旧 request 自动过期。

- [x] **INT-06｜实现 ApprovalCoordinator** — Owner: INT + SEC；估时：2d；依赖：INT-05、SEC-02
  - 范围：命令、文件、权限和用户输入 request。
  - 验收：只响应 Server 提供的可用决策；request/thread/turn/item/连接代次全部匹配。
  - 验收：双击、迟到、重复、resolved 后响应和并发请求测试通过。

- [x] **INT-07｜实现重连、睡眠恢复和退出保护** — Owner: INT + MAC；估时：1.5d；依赖：INT-04、INT-05
  - 验收：崩溃、睡眠、重启和用户退出行为可理解，不把未知显示为完成。

- [x] **INT-08｜实现未知版本安全退化** — Owner: INT；估时：0.5d；依赖：INT-06
  - 验收：未知版本仅历史读取，禁用 start/resume/turn/approval 并显示诊断。

- [x] **INT-09｜实现启动后外部会话自动发现** — Owner: INT + MAC + QA；完成：2026-08-12
  - 范围：5 秒 State DB 最近页、全量 State DB 游标校准、局部合并、立即生命周期观察、单飞、连接代次保护和失败退避。
  - 验收：无需手动刷新即可发现新会话；不删除或覆盖旧卡；快速完成仍有汇报；32 项回归通过；1,260 个根会话与 State DB 对账一致。

- [x] **DATA-01｜实现项目与职员映射** — Owner: MAC；估时：1d；依赖：ARC-01
  - 验收：符号链接、同名目录、隐藏路径和 thread id 稳定映射通过。

- [x] **DATA-02｜实现 TaskStore 状态机** — Owner: MAC + INT；估时：2d；依赖：INT-05、DATA-01
  - 验收：运行、等待、审批、补充信息、完成、失败、中断、未知和 historyOnly 正确。

- [x] **DATA-03｜实现最小本地存储与迁移** — Owner: MAC + SEC；估时：1d；依赖：DATA-02、SEC-01
  - 范围：设置、托管 thread id、别名、已阅、通知去重和 7 天快照。
  - 验收：不保存凭据、完整对话、完整命令、输出和 diff；可一键清除。

## 8. G2/G3：产品与 SwiftUI 界面

- [x] **UX-01｜输出信息架构和核心流程稿** — Owner: UX + PM；估时：1d；依赖：G0-06
  - 范围：交办任务、实时职员卡、审批举手、完成汇报、历史档案和断线。
  - 验收：用户能理解“工作台托管”边界。

- [x] **UX-02｜输出菜单栏与主窗口高保真稿** — Owner: UX；估时：1.5d；依赖：UX-01
  - 尺寸：360 pt 菜单栏、900×600 最小窗口、1180×760 推荐窗口。
  - 验收：举手可在 3 秒内识别，统计区不挤占卡片空间。

- [x] **UX-03｜输出审批、工作单和退出保护稿** — Owner: UX + SEC；估时：1d；依赖：UX-01、SEC-01
  - 验收：一次允许、拒绝、取消、过期、并发和敏感命令折叠均有状态。

- [~] **UX-04｜完成组件与无障碍规格** — Owner: UX + QA；估时：1d；依赖：UX-02、UX-03
  - 验收：键盘、VoiceOver、200% 字体、灰度、高对比度和减少动态效果可用。

- [x] **UI-01｜实现设计令牌和基础组件** — Owner: MAC；估时：1d；依赖：UX-04、REL-01
  - 验收：无 Emoji 图标；状态不只依赖颜色。

- [x] **UI-02｜实现菜单栏面板** — Owner: MAC；估时：1.5d；依赖：UI-01、DATA-02
  - 验收：显示办理、举手、完成未阅、异常和连接状态。

- [x] **UI-03｜实现项目轨道和职员卡面板** — Owner: MAC；估时：2d；依赖：UI-01、DATA-02
  - 验收：2–4 列自适应；举手突出；100 个任务滚动流畅。

- [x] **UI-04｜实现工作单与审批面板** — Owner: MAC + INT；估时：2d；依赖：UI-03、INT-06
  - 验收：操作范围、原因、可用决策和最终结果清晰；过期请求不可点击。

- [x] **UI-05｜实现任务交办与历史接管** — Owner: MAC + INT；估时：1.5d；依赖：UI-01、INT-04
  - 验收：项目、请求、模型和安全预设明确；接管前解释所有权变化。

- [x] **UI-06｜实现搜索、筛选和键盘导航** — Owner: MAC；估时：1d；依赖：UI-03
  - 验收：`⌘K`、状态筛选、方向键、Return 和批量已阅可用。

- [x] **UI-07｜实现设置、诊断和隐私** — Owner: MAC + INT；估时：1.5d；依赖：INT-08、DATA-03
  - 验收：Codex 路径、版本、Server、通知、缓存清理和脱敏诊断完整。

- [x] **NTF-01｜实现通知聚合与路由** — Owner: MAC；估时：1d；依赖：UI-04、DATA-03
  - 验收：审批即时、完成 10 秒聚合、重连不重放、隐私模式不泄露内容。

- [ ] **LOC-01｜建立中英文字符串目录** — Owner: MAC + DOC；估时：0.5d；依赖：UI-07
  - 验收：用户文案来自 strings catalog，无硬编码状态文案。

## 9. G3/G4：验证、稳定与发布

- [x] **QA-01｜建立需求到测试追踪表** — Owner: QA；估时：1d；依赖：UX-01、ARC-01
  - 验收：每个用户故事有正常、错误、恢复和安全用例。

- [x] **QA-02｜完成协议与状态自动化回归** — Owner: QA + INT；估时：1.5d；依赖：INT-08、DATA-02
  - 验收：重复、乱序、并发 approval、未知字段和跨连接迟到事件覆盖。

- [!] **E2E-01｜验证真实托管任务闭环** — Owner: QA + INT；估时：2d；依赖：UI-04、UI-05、QA-01
  - 场景：新建、运行、批准、拒绝、补充信息、完成、失败和中断。
  - 注意：会产生真实模型用量，运行前单独确认。

- [~] **E2E-02｜验证重连、睡眠与退出** — Owner: QA；估时：1d；依赖：INT-07、E2E-01
  - 验收：睡眠、Server 崩溃、应用重启和退出确认后状态一致。

- [~] **QA-03｜完成无障碍与视觉验收** — Owner: QA + UX；估时：1d；依赖：UI-07、LOC-01

- [ ] **PERF-01｜完成规模与事件风暴测试** — Owner: QA + MAC；估时：1d；依赖：UI-06、DATA-02
  - 验收：100/500 任务和 1,000 事件达到质量预算。

- [ ] **PERF-02｜完成 8 小时长稳测试** — Owner: QA；估时：1d；依赖：E2E-02、NTF-01
  - 验收：无持续内存增长、崩溃、假在线或重复通知。

- [~] **SEC-03｜执行发布前安全复核** — Owner: SEC；估时：1d；依赖：E2E-01、DATA-03
  - 验收：RPC、审批、子进程、日志、缓存、通知和诊断包检查通过。

- [x] **DOC-01｜编写用户指南与故障排查** — Owner: DOC；估时：1d；依赖：UI-07、E2E-02
  - 验收：首次启动、交办、审批、退出、隐私、卸载和诊断可由新用户完成。

- [!] **REL-03｜制作签名 Alpha/Beta 包** — Owner: REL；估时：1d；依赖：SEC-03、PERF-01
  - 注意：签名、公证和外部分发前单独确认。

- [ ] **PM-02｜执行 5–10 人 Beta 验收** — Owner: PM + UX + QA；估时：2d；依赖：REL-03
  - 验收：至少 80% 用户在 3 秒内识别待处理数量和项目。

- [ ] **REL-04｜生成 v1.0.0 Release Candidate** — Owner: REL；估时：1d；依赖：PM-02、PERF-02
  - 验收：P0/P1=0、签名、公证、许可证、SHA-256、更新说明和回滚包齐全。

- [ ] **PM-03｜正式发布决策** — Owner: PM + QA + SEC + REL；估时：0.5d；依赖：REL-04

## 10. v1.1 候选

- [ ] `acceptForSession` 与长期权限策略的独立安全设计。
- [ ] `turn/steer`、fork、批量中断和任务编排。
- [ ] 归档、删除和历史保留策略。
- [ ] 官方共享 daemon 或原生客户端实时互通（仅在公开支持后评估）。
- [ ] 跨设备或团队工作台。
