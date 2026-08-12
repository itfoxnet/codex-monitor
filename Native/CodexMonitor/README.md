# Codex Monitor Native

SwiftUI 原生 macOS 客户端。应用托管一个本地 stdio Codex App Server，并只读观察其他本机 Codex 会话的生命周期。只有由工作台创建或显式接管的任务进入审批闭环。

## 当前版本

- 应用：0.1.0 本地 Alpha
- 系统：macOS 14+
- 已验证 Codex 协议基线：0.142.2–0.144.1
- 其他 Codex 版本：可以读取历史，但交办、接管、授权和中断入口会关闭

## 开发

    swift test
    swift build

运行只读 App Server 集成测试：

    CODEX_MONITOR_INTEGRATION_TEST=1 swift test --filter realAppServerHandshakeAndReadOnlyList

## 生成可运行应用

    sh Scripts/build-app.sh
    open ".build/app/Codex Monitor.app"

生成的是本机临时使用的 ad-hoc 签名应用。正式分发仍需要 Developer ID 签名、公证和发布授权。

应用位置：`.build/app/Codex Monitor.app`。

## 使用

1. 启动后等待右上角从 `SYNCING` 变为 `LIVE`。
2. 点击“交办任务”，选择项目目录、填写任务目标并开始办理。
3. “全部会话”默认同时显示 `SERVER` 托管职员、`OBSERVED` 本机会话和 `ARCHIVE` 历史档案；左侧按项目归并。
4. 红色举手表示需要授权或补充信息，绿色举手表示完成未阅。
5. 单击卡片查看右侧工作单；双击卡片、点击卡片右下角图标，或点击工作单中的“在 Codex 中打开”，可直接跳到对应原生会话。
6. 其他 Codex 客户端的办理、完成、失败和中止会只读同步；授权仍回原客户端处理。只有显式“接管并继续”后的新 turn 才由工作台管理和审批。

键盘：

- `⌘K`：聚焦搜索。
- `⌘0`：全部；`⌘1`：举手；`⌘2`：办理中；`⌘3`：已完成；`⌘4`：等待中。
- 方向键：在当前职员卡列表中移动选择。
- `⌘⇧A`：把当前项目的完成汇报标记为已阅。
- `⌘R`：刷新；`⌘⇧N`：交办任务。
- `⌘Q`：退出 Codex Monitor；若有工作台托管任务正在办理，会先显示中断确认。

关闭主窗口不会退出菜单栏应用。可在菜单栏面板点击电源图标，或在应用菜单选择“退出 Codex Monitor”。完全退出时如仍有工作台托管任务运行，应用会要求返回工作台或中断后退出。

## 连接与诊断

默认查找顺序：

1. 设置中手动选择的 Codex 可执行文件。
2. `/Applications/Codex.app/Contents/Resources/codex`。
3. Homebrew 常见位置。
4. 当前进程 `PATH`。

设置页可查看连接、Codex 版本和脱敏诊断，也可以手动重连。每个 App Server 请求有 12 秒超时；子进程退出会按退避序列自动重连，Mac 唤醒后会先校准现有连接。

常见问题：

- “没有找到 Codex”：在设置中选择可执行文件，并确认文件可执行。
- 一直无法连接：复制设置页诊断；诊断会截断并隐藏常见绝对路径。
- 其他客户端的任务没有显示“办理中”：先确认该任务最近 10 分钟仍有生命周期活动；旧的未闭合日志会被归档，避免误报。需要在工作台审批时请显式接管。
- 未知版本只读：选择 0.142–0.144 的 Codex，或先更新本项目的 schema 和兼容策略。
- 通知没有出现：在设置开启通知，并在系统设置中授予权限；不影响工作台本身。
- 无法打开原生会话：确认本机 Codex/ChatGPT 客户端可处理 `codex://` 链接，且该会话没有被删除。

## 本地数据与卸载

“清除工作台本地数据”只删除托管 thread id、已阅、设置、脱敏快照和最多 100 条不含请求内容的审批摘要，不删除 Codex 任务或项目文件。应用不会保存完整对话、命令输出或 diff。

卸载开发版：先完全退出 Codex Monitor，再移除 `.build/app/Codex Monitor.app`；如需清除偏好，可先在设置页使用本地数据清理。

## 安全边界

- 使用 codex app-server 的 stdio 传输，不开放网络端口。
- 新任务固定使用 workspace-write 沙箱与 on-request 审批。
- 只响应当前连接收到且 thread/turn/item/request 全部匹配的请求。
- 不提供自动批准、acceptForSession、配置写入、shell/fs RPC、删除或归档。
- 独立 Codex Desktop、IDE 和 CLI 任务只读显示生命周期状态，卡片标记为 `OBSERVED`；工作台不读取其消息内容，也不代为审批。
- 不安装、读取或依赖 Hook。

完整威胁模型与验收证据见仓库 `docs/05-SECURITY-THREAT-MODEL.md` 和 `docs/06-LOCAL-ALPHA-ACCEPTANCE.md`。
