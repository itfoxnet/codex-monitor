# Codex Monitor 文档索引

本文档集把现有 Web 视觉原型推进为 SwiftUI 原生 macOS 产品。根目录中的 `index.html`、`styles.css` 和 `app.js` 继续作为交互与视觉参考，不再作为正式产品架构。

## 推荐阅读顺序

1. [项目章程](./00-PROJECT-CHARTER.md)：目标、范围、用户、成功指标和产品闸门。
2. [产品与体验设计](./01-PRODUCT-UX-DESIGN.md)：信息架构、状态语义、核心流程和视觉规范。
3. [技术架构](./02-TECHNICAL-ARCHITECTURE.md)：SwiftUI 客户端、Codex App Server、事件模型和安全边界。
4. [质量与发布计划](./03-QUALITY-RELEASE-PLAN.md)：测试矩阵、可观测性、发布和回滚。
5. [团队与执行计划](./04-TEAM-EXECUTION-PLAN.md)：岗位职责、RACI、里程碑和开发流程。
6. [安全与隐私威胁模型](./05-SECURITY-THREAT-MODEL.md)：审批、RPC、版本、日志、缓存和通知的风险控制。
7. [本地 Alpha 验收记录](./06-LOCAL-ALPHA-ACCEPTANCE.md)：已实现能力、验证证据和发布前剩余项。
8. [架构决策 ADR-001](./decisions/ADR-001-SWIFTUI-APP-SERVER.md)：为什么由 SwiftUI 工作台托管 App Server，以及实时任务的所有权边界。
9. [G0-02 独立服务验证](./validation/G0-02-STANDALONE-VISIBILITY.md)：独立 App Server 能看到历史任务，但看不到另一实例的实时 active 状态。
10. [G0-03 daemon/proxy 验证](./validation/G0-03-DAEMON-PROXY.md)：为何当前 daemon 不作为 MVP 前提。
11. [G0-05 Hook Observer 历史 PoC](./validation/G0-05-HOOK-OBSERVER-POC.md)：已被 ADR-001 否决路线的验证记录。
12. [可执行任务清单](../TASKS.md)：按依赖排序、带负责人和验收条件的工作项。

## 当前基线

- 日期：2026-08-06
- 本机：macOS 26.3、Xcode 26.2
- Codex CLI：Codex.app 内置 0.142.2；当前 shell 0.144.1
- 当前成品：可运行的本地 SwiftUI Alpha；Web 原型仅保留为历史视觉参考
- 应用产物：`Native/CodexMonitor/.build/app/Codex Monitor.app`
- 架构边界：App Server 是托管任务和审批的权威数据源；独立本机会话仅做生命周期只读观察；不使用 Hook

## 文档状态

| 文档 | 状态 | 进入开发前是否必须批准 |
|---|---|---:|
| 项目章程 | Baseline v2 | 否 |
| 产品与体验设计 | Baseline v2 | 进入高保真前复核 |
| 技术架构 | Baseline v2 | 否，重大边界变化需 ADR |
| 质量与发布计划 | Baseline v2 | 进入 E2E 前复核 |
| 团队与执行计划 | Ready | 否，可随排期调整 |
| ADR-001 | Accepted | 否 |
| 安全与隐私威胁模型 | Implemented | 公开发布前复核 |
| 本地 Alpha 验收 | Passed with release gates | 真实 E2E 前复核 |
| TASKS | In progress | 本地 Alpha 已完成，G4 发布项待授权与实测 |

## 事实来源

- [Codex App Server 官方说明](https://developers.openai.com/codex/app-server/)
- 本机 Codex CLI 帮助输出与进程状态，只用于本项目技术验证，不作为跨版本保证
