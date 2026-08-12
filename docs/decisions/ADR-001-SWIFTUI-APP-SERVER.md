# ADR-001：SwiftUI 客户端托管 Codex App Server

- 状态：Accepted
- 日期：2026-08-06
- 决策人：产品经理、技术负责人、安全负责人

## 背景

Web 原型已经验证项目分组、紧凑职员卡和举手隐喻，但使用模拟数据。正式产品需要低资源常驻、菜单栏、通知、实时任务事件以及经理处理授权的闭环。

技术验证发现：一个独立 App Server 可以读取 Codex Desktop 已保存的任务，但无法获得另一个 App Server 进程中的实时内存状态；当前安装也没有可供多个客户端共享的 installer 托管 daemon。继续追求“旁观所有原生会话”将需要 Hook 或私有接口，并且无法保证权威审批状态。

Codex App Server 是官方面向富客户端的接口，提供任务历史、运行状态、审批请求和流式事件。因此产品必须在“旁观独立任务”与“自己托管任务”之间做出明确选择。

## 决策

1. 正式产品使用 SwiftUI 原生 macOS 菜单栏应用。
2. 应用启动并托管一个 `codex app-server --listen stdio://` 子进程。
3. 只有由工作台 `thread/start` 创建或显式 `thread/resume` 接管的任务进入实时监控。
4. 独立 Codex Desktop、IDE 和 CLI 任务最多作为历史档案读取，不计入实时状态。
5. MVP 支持从工作台交办任务，以及对当前 Server request 进行一次性批准、拒绝或取消。
6. MVP 禁止自动批准、`acceptForSession`、长期权限规则和任意 RPC 调用。
7. 不安装或依赖 Hook，不使用私有 IPC，不解析 transcript 内部格式。
8. 不开放 WebSocket/TCP 端口；未来官方 daemon 可用时再单独复审。

## 选择理由

- 同一 App Server 同时拥有任务执行和事件流，运行状态与审批结果不需要跨进程推断。
- stdio 父子进程边界轻量、无需网络监听，适合本机 SwiftUI 应用。
- 工作台能够完整表达“职员举手—经理处理—职员继续—完成汇报”。
- 单一实时数据源显著减少去重、置信度、Hook 信任和原生审批竞争问题。
- 封闭 RPC 类型与严格 request 关联可以把审批能力限制在明确范围内。

## 代价与产品影响

- 工作台不能实时监控用户在其他 Codex 客户端中独立启动的任务。
- 用户必须从工作台交办任务，或显式接管历史任务，才能获得实时体验。
- 应用完全退出或崩溃可能中断在途 turn，因此必须提供退出保护和恢复校准。
- 客户端需要维护 Codex 版本兼容、JSON-RPC DTO 和审批安全测试。
- 首期直接分发比 Mac App Store 更现实，需要自行处理签名与更新。

## 被否决方案

### App Server 快照 + Hook

Hook 能提供跨进程生命周期信号，但增加全局配置、信任提示和额外进程；授权解决仍需要推断。既然任务由工作台 Server 托管，这套兼容层没有必要。

### 继续使用纯 Web

需要本地桥接服务、端口和额外浏览器安全边界；菜单栏、通知和生命周期整合较弱。Web 原型只保留为视觉参考。

### 只读取 SQLite、JSONL 或 transcript

适合历史调查，不适合权威实时状态；内部格式和审批语义不足以支撑产品承诺。

### 直接接入 Codex Desktop 私有 IPC

缺少公开稳定契约，升级与安全风险不可接受。

### 等待或强制安装托管 daemon

当前环境缺少 installer 管理版 standalone Codex。强制改变用户安装方式不是 MVP 的合理前置条件；官方 daemon 将作为未来可替换宿主，而不是当前依赖。

## 验证证据

- G0-02：独立 stdio App Server 能列出保存任务，但活动桌面任务仍为 `notLoaded`，说明跨实例实时状态不可用。
- G0-03：当前安装无法启动 installer 托管 daemon；手动 Unix listener 不能替代 daemon control endpoint。
- G0-05：Hook observer 合成 PoC 虽可运行，但该路线现已被产品范围否决，未安装到系统。

完整记录：

- [G0-02 独立服务可见性](../validation/G0-02-STANDALONE-VISIBILITY.md)
- [G0-03 daemon/proxy 验证](../validation/G0-03-DAEMON-PROXY.md)
- [G0-05 Hook Observer 历史 PoC](../validation/G0-05-HOOK-OBSERVER-POC.md)

## 复审条件

- Codex Desktop 正式提供公开、稳定、可共享的本地 Server/daemon。
- App Server 的 stdio、审批或订阅契约发生破坏性变化。
- 产品要增加跨设备、团队或远程连接。
- 产品要支持长期权限、自动批准或更广泛的任务控制。
- 产品计划上架 Mac App Store，需要重新评估子进程与沙箱边界。

## 参考

- [Codex App Server](https://developers.openai.com/codex/app-server/)
