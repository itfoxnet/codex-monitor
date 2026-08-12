# G0-02 独立 App Server 任务可见性验证

- 日期：2026-08-06
- 环境：macOS 26.3、Xcode 26.2、Codex CLI 0.144.1
- 状态：完成
- 工具：`Tools/CodexProbe` v0.1.0

## 1. 验证目的

确认一个由探针临时启动的独立 stdio App Server，能否读取 Codex 桌面端已经保存的任务，以及它返回的 runtime status 能否代表桌面端当前实时状态。

本验证不启动任务、不恢复任务、不订阅任务、不响应审批，也不修改 Codex 配置。

## 2. 探针安全边界

编译期允许的请求只有：

- `initialize` / `initialized`
- `thread/list`
- `thread/read`
- `thread/loaded/list`

测试明确阻断 `thread/start`、`thread/delete`、`thread/archive`、`turn/start`、`turn/interrupt`、文件写入和 approval 方法。

`thread/list` 固定使用 `useStateDbOnly: true`，避免默认的 JSONL 扫描和元数据修复。输出只保留 thread id 前缀、项目目录末级名称、source kind、状态、active flags 和时间戳。

## 3. 验证步骤

### 3.1 当前项目快照

```bash
swift run codex-probe snapshot \
  --cwd /path/to/codex-monitor \
  --limit 100 \
  --timeout 15
```

### 3.2 当前任务摘要读取

```bash
swift run codex-probe read THREAD_ID --timeout 15
```

### 3.3 最近存储任务来源统计

```bash
swift run codex-probe snapshot --limit 200 --timeout 15
```

服务端本次最多返回 100 条记录；报告在保存前移除了逐任务数组，只保留聚合统计。

## 4. 结果

### 4.1 当前 `codex-monitor` 任务

| 字段 | 结果 |
|---|---|
| 独立 App Server 能否列出 | 能 |
| source kind | `vscode` |
| 独立服务内 loaded 数 | 0 |
| `thread/list` runtime status | `notLoaded` |
| `thread/read` runtime status | `notLoaded` |
| active flags | 空 |

验证执行期间，本任务正在 Codex 桌面端活动。独立 App Server 仍把它报告为 `notLoaded`，说明已保存任务的可见性与另一 App Server 进程中的实时内存状态是两件事。

### 4.2 最近 100 条存储任务

| 指标 | 结果 |
|---|---:|
| 返回任务数 | 100 |
| `vscode` 来源 | 49 |
| `subAgent` 来源 | 51 |
| `notLoaded` | 100 |
| 探针服务内 loaded | 0 |

本次最近记录中没有可确认的 `cli` 或 `appServer` 根任务样本。为了保持探针只读，没有人为创建新任务补齐来源；该项不影响“独立服务无法读取另一进程实时状态”的当前结论。

## 5. 结论

1. 独立 App Server 可以读取桌面 Codex 持久化的任务元数据。
2. `thread/list` 和 `thread/read` 返回的 runtime status 属于当前 App Server 实例；它不能直接反映桌面端另一 stdio App Server 中的 active 状态。
3. 单独启动一个 App Server 只能作为历史快照来源，不能单独满足实时监控。
4. 产品范围已据此调整：只有工作台 App Server 创建或接管的任务提供实时状态；独立原生任务只作历史档案，不增加 Hook 兼容层。

## 6. 限制

- 没有启动托管 daemon。
- 没有调用 `thread/resume` 或任何订阅能力。
- 没有创建 CLI/App Server 新任务，因为这会违反当前只读探针边界。
- 没有测试 approval request 的多客户端分发。
- 结论只适用于本次环境和 Codex CLI 0.144.1。

## 7. 验证证据

- `swift test`：5 项测试通过。
- `swift build -c release`：通过。
- 当前项目 snapshot：1 条 `vscode` 任务，`notLoaded`。
- 同任务 `thread/read`：`notLoaded`。
- 最近 100 条聚合：49 `vscode`、51 `subAgent`、100 `notLoaded`。
