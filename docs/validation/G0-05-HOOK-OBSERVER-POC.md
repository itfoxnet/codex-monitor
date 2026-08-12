# G0-05 Hook Observer 最小 PoC（历史验证，路线已否决）

- 日期：2026-08-06
- 状态：Superseded；完成过项目内 PoC，但 ADR-001 已决定不采用 Hook
- 当前产物：仅保留本文验证记录

## 1. 目的

验证在不同 Codex 进程无法共享 App Server runtime state 时，能否通过 Hook 以低开销发送脱敏生命周期事件，同时不决定授权、不阻塞 Codex。

> 本文仅保留架构决策证据。Hook 工具、配置样例和测试已从 Swift package 移除，也从未安装到用户系统。

## 2. 支持事件

- `SessionStart`
- `SessionEnd`
- `PermissionRequest`
- `PostToolUse`
- `Stop`

`PreToolUse` 等未列入事件会被忽略。relay 不输出 `allow`、`deny`、`continue` 或任何 `hookSpecificOutput`。

## 3. 数据最小化

relay 只保留：

- 事件名。
- session id 与 turn id 的 12 字符前缀。
- `cwd` 的末级项目名。
- model、tool name、permission mode。
- 是否存在人类可读 description，不保存 description 内容。
- 本地接收时间。

明确删除 transcript 路径、完整 cwd、完整 id、命令、工具参数和输出。

## 4. 合成闭环结果

合成 `PermissionRequest` 包含完整 transcript 路径、完整项目路径和测试命令。collector 收到：

```json
{
  "eventName": "PermissionRequest",
  "hasHumanDescription": true,
  "model": "gpt-test",
  "permissionMode": "default",
  "project": "codex-monitor",
  "schemaVersion": 1,
  "sessionIDPrefix": "thr_syntheti",
  "toolName": "Bash",
  "turnIDPrefix": "turn_synthet"
}
```

输出中不存在完整路径、transcript 或命令正文。collector 接收一个事件后退出并清理 Unix datagram socket。

## 5. 性能与失败行为

- 第一次冷启动实测约 0.44 秒，低于示例 Hook 的 1 秒超时，但高于 50 ms 性能目标。
- 预热后连续 20 次进程启动、脱敏和 datagram 发送总计 0.11 秒，平均约 5.5 ms/次。
- collector 不存在时，relay 连续 5 次均立即退出 0，不输出错误，不阻塞调用方。
- 正式 P95 仍需安装到真实 Hook 生命周期后测量；本结果只证明最小 PoC 可行。

## 6. 交付物

- 当时曾生成 Hook sanitizer、relay、collector、配置样例和 2 项单元测试。
- 这些文件已在 ADR-001 接受后移除；当前 package 只构建 App Server 探针。

## 7. 安全边界

- 没有创建 `~/.codex/hooks.json`。
- 没有绕过 Codex Hook 信任审查。
- 没有使用真实授权、命令或客户代码。
- 项目不会继续安装或验证真实 Hook。

## 8. 下一步

不再继续真实 Hook 生命周期测试。后续验证转为工作台托管 App Server 的 start、approval、resolved 和 completed 闭环。
