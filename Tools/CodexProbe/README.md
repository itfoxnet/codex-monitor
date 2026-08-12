# Codex Monitor Read-Only Probe

G0 技术验证工具。它会启动一个临时的 stdio Codex App Server，并通过编译期白名单限制为以下消息：

- `initialize` / `initialized`
- `thread/list`
- `thread/read`
- `thread/loaded/list`

它不会启动、恢复、修改、归档或删除任务，也不会响应授权请求。默认输出经过脱敏，不包含任务标题、提示词、命令、完整 thread id 或完整路径。

## 构建和测试

```bash
swift test
swift build -c release
```

## 获取工作区快照

```bash
swift run codex-probe snapshot \
  --cwd /absolute/path/to/project \
  --limit 100
```

连接已经启动的托管 daemon：

```bash
swift run codex-probe snapshot \
  --transport daemon-proxy \
  --cwd /absolute/path/to/project
```

连接自定义 Unix socket：

```bash
swift run codex-probe snapshot \
  --transport daemon-proxy \
  --socket /tmp/codex-monitor-app-server.sock
```

`--hold SECONDS` 可在并发连接验证时短暂保持连接，最大 30 秒；它不会加载或订阅任务。

如果需要指定 Codex：

```bash
swift run codex-probe snapshot --codex /absolute/path/to/codex
```

## 读取指定任务的摘要

```bash
swift run codex-probe read THREAD_ID
```

读取同样使用 `includeTurns: false`，输出中只保留状态验证所需字段。

## 安全说明

- `thread/list` 固定使用 `useStateDbOnly: true`，避免扫描并修复 JSONL 元数据。
- 不开放 WebSocket 或 TCP 端口。
- App Server 是探针的子进程；探针结束时关闭它。
- 输出可以进入验证报告，但不应加入真实标题、命令或对话内容。

本工具只保留 App Server 诊断能力。历史 Hook PoC 已从构建目标和源代码中移除；正式产品不会安装或依赖 Hook。
