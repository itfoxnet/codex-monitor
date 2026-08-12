# G0-03 托管 daemon 与 proxy 验证

- 日期：2026-08-06
- 环境：Codex CLI 0.144.1
- 状态：验证完成；daemon 在当前环境不可用，但不再是 MVP 前提

## 1. 目的

验证本机托管 App Server daemon、`app-server proxy` 和两个并发只读客户端能否建立连接。

## 2. 托管 daemon 结果

执行 `codex app-server daemon start` 后，Codex 拒绝启动，原因是缺少 installer 管理的固定 standalone 安装：

```text
~/.codex/packages/standalone/current/codex
```

当前 Codex 来自桌面应用/普通 CLI。daemon 命令要求由 Codex installer 管理的 standalone 路径，以便从固定位置启动和更新服务。

本项目没有执行官方安装脚本，也没有改变 Codex 安装方式。

## 3. 临时 Unix listener 回退验证

为了判断手动 Unix listener 是否能提供同等连接，执行了以下受控回退：

1. `codex app-server --listen unix://` 启动成功。
2. `daemon version` 能识别 control socket，并报告 CLI/App Server 版本为 0.144.1。
3. 两个并发 `app-server proxy` 只读客户端均在 15 秒后超时。
4. listener 日志显示 control socket WebSocket upgrade 收到不兼容的协议内容。

这说明手动 `--listen unix://` 不能冒充 installer 管理的 daemon control endpoint。继续适配该差异会依赖未承诺实现，因此停止尝试。

## 4. 清理结果

- 临时 App Server 已终止。
- `daemon version` 再次返回 socket 不存在。
- 没有残留 `app-server --listen unix://` 进程。
- 测试产生的零字节 startup lock 和空 control 目录已清理。
- 没有安装 standalone Codex，没有修改 Hook 或 Codex 配置。

## 5. 结论

| 问题 | 结果 |
|---|---|
| 当前环境能否启动托管 daemon | 不能，缺少 installer 管理版 standalone |
| 是否应自动安装以继续 | 不应，需要独立用户决策 |
| 手动 Unix listener 能否替代 daemon proxy | 不能 |
| 是否影响现有桌面 Codex | 未发现；测试后无服务残留 |

G0-03 的 daemon 路线在当前环境不可用，但不再构成项目阻断。ADR-001 选择由应用托管 stdio App Server；未来只有官方 daemon 可用且语义经过验证时才复审。
