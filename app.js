const projects = [
  {
    id: "codex-monitor",
    code: "PRJ—01",
    name: "Codex Monitor",
    path: "~/Developer/codex-monitor",
    description: "轻量会话监控仪表盘",
  },
  {
    id: "knowledge-base",
    code: "PRJ—02",
    name: "Knowledge Base",
    path: "~/Work/knowledge-base",
    description: "知识库检索与内容整理",
  },
  {
    id: "shop-api",
    code: "PRJ—03",
    name: "Shop API",
    path: "~/Work/shop-api",
    description: "订单与支付服务",
  },
  {
    id: "landing-page",
    code: "PRJ—04",
    name: "Landing Page",
    path: "~/Sites/launch",
    description: "产品发布页与内容更新",
  },
];

const sessions = [
  {
    id: "CX-8F21",
    projectId: "codex-monitor",
    title: "实现会话状态实时轮询",
    prompt: "为仪表盘接入 Codex 会话状态，并设计可靠的轮询和断线恢复逻辑。",
    branch: "feat/session-polling",
    status: "running",
    progress: 72,
    duration: "18m 42s",
    tokens: "18.4k tokens",
    activity: "正在运行测试",
    updated: "12 秒前",
    started: "20:41:18",
    agent: "codex-1",
    events: [
      ["已读取项目结构", "20:41:22", "识别数据源与前端状态边界", "done"],
      ["完成数据适配器", "20:47:09", "新增会话状态归一化逻辑", "done"],
      ["运行相关测试", "20:59:48", "正在验证断线重连行为", "current"],
    ],
  },
  {
    id: "CX-7D34",
    projectId: "codex-monitor",
    title: "优化移动端项目导航",
    prompt: "让项目列表在手机端保持易用，并保留当前项目的上下文。",
    branch: "fix/mobile-nav",
    status: "completed",
    progress: 100,
    duration: "11m 06s",
    tokens: "9.1k tokens",
    activity: "修改 3 个文件",
    updated: "8 分钟前",
    started: "20:26:14",
    agent: "codex-2",
    events: [
      ["分析布局断点", "20:26:23", "确认 820px 与 650px 两级适配", "done"],
      ["实现抽屉式导航", "20:31:54", "增加焦点与遮罩处理", "done"],
      ["验证通过", "20:37:20", "移动视口检查完成", "done"],
    ],
  },
  {
    id: "CX-6A90",
    projectId: "codex-monitor",
    title: "补充状态筛选单元测试",
    prompt: "覆盖全部、进行中、已完成和异常筛选，以及关键字组合查询。",
    branch: "test/status-filter",
    status: "waiting",
    progress: 0,
    duration: "—",
    tokens: "0 tokens",
    activity: "等待空闲执行位",
    updated: "2 分钟前",
    started: "—",
    agent: "等待分配",
    events: [
      ["任务已创建", "20:57:06", "进入项目执行队列", "current"],
    ],
  },
  {
    id: "CX-2B17",
    projectId: "codex-monitor",
    title: "修复日志时间格式偏差",
    prompt: "日志详情中的相对时间和本地时间不一致，请定位并修复时区处理。",
    branch: "fix/log-timezone",
    status: "failed",
    progress: 38,
    duration: "7m 29s",
    tokens: "6.7k tokens",
    activity: "命令执行失败",
    updated: "14 分钟前",
    started: "20:38:02",
    agent: "codex-3",
    error: "测试环境缺少 TZDATA，时间格式快照未通过。",
    events: [
      ["复现时区偏差", "20:38:16", "UTC+8 快照与预期不一致", "done"],
      ["修改时间格式器", "20:42:44", "统一使用显式时区", "done"],
      ["测试执行失败", "20:45:31", "缺少 TZDATA 环境数据", "error"],
    ],
  },
  {
    id: "CX-9C02",
    projectId: "knowledge-base",
    title: "重构全文搜索索引",
    prompt: "减少大规模文档导入时的索引阻塞，并保持查询结果顺序稳定。",
    branch: "refactor/search-index",
    status: "running",
    progress: 46,
    duration: "32m 18s",
    tokens: "31.2k tokens",
    activity: "正在分析性能报告",
    updated: "5 秒前",
    started: "20:27:42",
    agent: "codex-1",
    events: [
      ["记录基准性能", "20:28:13", "10k 文档导入用时 41.2s", "done"],
      ["拆分批量索引", "20:46:02", "按 500 条分块提交", "done"],
      ["分析新基准", "20:59:55", "正在对比内存峰值", "current"],
    ],
  },
  {
    id: "CX-4E18",
    projectId: "knowledge-base",
    title: "添加 Markdown 表格解析",
    prompt: "支持包含对齐符号、转义竖线和多行内容的 Markdown 表格。",
    branch: "feat/markdown-table",
    status: "completed",
    progress: 100,
    duration: "24m 51s",
    tokens: "20.8k tokens",
    activity: "新增 18 个测试",
    updated: "1 小时前",
    started: "18:54:07",
    agent: "codex-2",
    events: [
      ["梳理解析规则", "18:54:26", "覆盖 GFM 表格边界情况", "done"],
      ["实现解析器", "19:07:48", "加入转义与对齐信息处理", "done"],
      ["全部测试通过", "19:18:58", "18 个新增用例通过", "done"],
    ],
  },
  {
    id: "CX-1F54",
    projectId: "knowledge-base",
    title: "清理重复文档元数据",
    prompt: "识别数据库中重复的文档元数据并提供安全的清理脚本。",
    branch: "chore/dedupe-meta",
    status: "completed",
    progress: 100,
    duration: "16m 03s",
    tokens: "12.5k tokens",
    activity: "生成清理报告",
    updated: "3 小时前",
    started: "17:02:11",
    agent: "codex-4",
    events: [
      ["扫描重复记录", "17:02:22", "发现 43 组重复元数据", "done"],
      ["生成安全脚本", "17:10:09", "保留最新有效记录", "done"],
      ["输出审计报告", "17:18:14", "未直接修改生产数据", "done"],
    ],
  },
  {
    id: "CX-3A73",
    projectId: "knowledge-base",
    title: "验证文档导入回归",
    prompt: "对 PDF、Word、Markdown 三类文档执行导入回归测试。",
    branch: "test/import-regression",
    status: "waiting",
    progress: 0,
    duration: "—",
    tokens: "0 tokens",
    activity: "前置任务运行中",
    updated: "22 分钟前",
    started: "—",
    agent: "等待分配",
    events: [["等待索引重构完成", "20:38:00", "依赖会话 CX-9C02", "current"]],
  },
  {
    id: "CX-0D61",
    projectId: "shop-api",
    title: "实现订单退款接口",
    prompt: "按照现有支付架构实现幂等的订单退款接口和回调处理。",
    branch: "feat/order-refund",
    status: "running",
    progress: 84,
    duration: "41m 09s",
    tokens: "38.9k tokens",
    activity: "正在验证回调签名",
    updated: "19 秒前",
    started: "20:19:01",
    agent: "codex-3",
    events: [
      ["梳理退款状态机", "20:19:25", "确认幂等键与重试策略", "done"],
      ["实现退款与回调", "20:36:41", "新增签名校验", "done"],
      ["沙箱联调", "20:58:51", "正在验证重复回调", "current"],
    ],
  },
  {
    id: "CX-5B88",
    projectId: "shop-api",
    title: "升级数据库迁移脚本",
    prompt: "整理迁移依赖并确保全新数据库与存量数据库均可顺利升级。",
    branch: "chore/db-migration",
    status: "failed",
    progress: 61,
    duration: "13m 32s",
    tokens: "11.6k tokens",
    activity: "迁移版本冲突",
    updated: "29 分钟前",
    started: "20:18:33",
    agent: "codex-4",
    error: "检测到两个迁移头，需确认正确的合并顺序。",
    events: [
      ["检查迁移历史", "20:18:45", "发现分叉版本链", "done"],
      ["尝试自动合并", "20:25:06", "保留两条 schema 变更", "done"],
      ["需要人工确认", "20:32:05", "无法推断生产应用顺序", "error"],
    ],
  },
  {
    id: "CX-8A12",
    projectId: "shop-api",
    title: "补充订单查询缓存",
    prompt: "为高频订单查询增加短时缓存，并在订单状态变化后主动失效。",
    branch: "perf/order-cache",
    status: "completed",
    progress: 100,
    duration: "19m 47s",
    tokens: "15.9k tokens",
    activity: "压测通过",
    updated: "2 小时前",
    started: "18:03:18",
    agent: "codex-2",
    events: [
      ["确认缓存边界", "18:03:44", "只缓存已授权订单查询", "done"],
      ["实现主动失效", "18:11:06", "状态变更后清理缓存键", "done"],
      ["压测通过", "18:23:05", "P95 降低 36%", "done"],
    ],
  },
  {
    id: "CX-7C45",
    projectId: "landing-page",
    title: "更新夏季发布内容",
    prompt: "根据产品文档更新夏季版本发布页文案与功能列表。",
    branch: "content/summer-release",
    status: "completed",
    progress: 100,
    duration: "9m 55s",
    tokens: "7.4k tokens",
    activity: "内容校对完成",
    updated: "4 小时前",
    started: "16:02:17",
    agent: "codex-1",
    events: [
      ["提取版本变化", "16:02:29", "归纳 6 项用户可见更新", "done"],
      ["更新页面文案", "16:07:10", "保持品牌语气一致", "done"],
      ["完成内容校对", "16:12:12", "链接与日期已复核", "done"],
    ],
  },
  {
    id: "CX-6D39",
    projectId: "landing-page",
    title: "压缩首屏媒体资源",
    prompt: "优化首屏图片和视频封面，减少移动网络下的加载时间。",
    branch: "perf/hero-media",
    status: "completed",
    progress: 100,
    duration: "14m 28s",
    tokens: "10.2k tokens",
    activity: "体积减少 43%",
    updated: "5 小时前",
    started: "15:11:04",
    agent: "codex-3",
    events: [
      ["统计媒体体积", "15:11:26", "首屏传输 2.4MB", "done"],
      ["生成响应式资源", "15:18:03", "增加 AVIF 与 WebP", "done"],
      ["性能检查通过", "15:25:32", "首屏媒体减少 43%", "done"],
    ],
  },
  {
    id: "CX-3E96",
    projectId: "landing-page",
    title: "检查多语言路由",
    prompt: "验证中文和英文页面之间的跳转、canonical 与 hreflang 设置。",
    branch: "test/i18n-routing",
    status: "waiting",
    progress: 0,
    duration: "—",
    tokens: "0 tokens",
    activity: "计划在 21:15 运行",
    updated: "6 分钟前",
    started: "—",
    agent: "等待分配",
    events: [["任务已排期", "20:54:11", "等待定时执行", "current"]],
  },
];

const state = {
  projectId: "all",
  status: "all",
  query: "",
  selectedSessionId: null,
};

const statusMeta = {
  running: { label: "办理中", icon: "activity" },
  completed: { label: "完成举手", icon: "check" },
  waiting: { label: "等候安排", icon: "clock" },
  failed: { label: "申请授权", icon: "alert" },
};

const staffNames = ["陈序", "林简", "周衡", "许澈", "沈知", "顾言", "韩川", "江宁", "罗一", "程墨", "苏木", "陆青", "宋祺", "梁安"];

function staffMeta(session) {
  const index = Math.max(0, sessions.findIndex((item) => item.id === session.id));
  return {
    name: staffNames[index] || `职员 ${index + 1}`,
    desk: `${String(index + 1).padStart(2, "0")} 号柜台`,
    badge: session.id.replace("CX-", "CDX-"),
  };
}

const elements = {
  projectList: document.querySelector("#projectList"),
  sessionList: document.querySelector("#sessionList"),
  emptyState: document.querySelector("#emptyState"),
  projectCode: document.querySelector("#projectCode"),
  projectTitle: document.querySelector("#projectTitle"),
  projectMeta: document.querySelector("#projectMeta"),
  projectProgressText: document.querySelector("#projectProgressText"),
  projectProgressBar: document.querySelector("#projectProgressBar"),
  searchInput: document.querySelector("#searchInput"),
  attentionStrip: document.querySelector("#attentionStrip"),
  attentionTitle: document.querySelector("#attentionTitle"),
  attentionText: document.querySelector("#attentionText"),
  drawer: document.querySelector("#sessionDrawer"),
  drawerBackdrop: document.querySelector("#drawerBackdrop"),
  drawerBody: document.querySelector("#drawerBody"),
  drawerFoot: document.querySelector("#drawerFoot"),
  toast: document.querySelector("#toast"),
  sidebar: document.querySelector("#sidebar"),
};

function icon(name) {
  return `<svg aria-hidden="true"><use href="#icon-${name}"></use></svg>`;
}

function getProjectSessions(projectId = state.projectId) {
  return projectId === "all" ? sessions : sessions.filter((session) => session.projectId === projectId);
}

function getCounts(list) {
  return list.reduce(
    (counts, session) => {
      counts.all += 1;
      counts[session.status] += 1;
      return counts;
    },
    { all: 0, running: 0, completed: 0, waiting: 0, failed: 0 },
  );
}

function completionRate(list) {
  if (!list.length) return 0;
  return Math.round((list.filter((session) => session.status === "completed").length / list.length) * 100);
}

function projectState(list) {
  if (list.some((session) => session.status === "failed")) return "failed";
  if (list.some((session) => session.status === "running")) return "running";
  if (list.every((session) => session.status === "completed")) return "completed";
  return "waiting";
}

function renderProjects() {
  const allCounts = getCounts(sessions);
  const allItem = `
    <button class="project-item ${state.projectId === "all" ? "is-active" : ""}" type="button" data-project="all" style="--project-progress:${completionRate(sessions)}%;--project-color:var(--green)">
      <span class="project-state-dot ${projectState(sessions)}"></span>
      <span>
        <span class="project-name">全部项目</span>
        <span class="project-sub">${allCounts.running} 办理 · ${allCounts.completed + allCounts.failed} 举手</span>
      </span>
      <span class="project-total">${sessions.length}</span>
    </button>`;

  const items = projects
    .map((project) => {
      const list = getProjectSessions(project.id);
      const counts = getCounts(list);
      return `
        <button class="project-item ${state.projectId === project.id ? "is-active" : ""}" type="button" data-project="${project.id}" style="--project-progress:${completionRate(list)}%;--project-color:${projectState(list) === "failed" ? "var(--red)" : "var(--green)"}">
          <span class="project-state-dot ${projectState(list)}"></span>
          <span>
            <span class="project-name">${project.name}</span>
            <span class="project-sub">${counts.running} 办理 · ${counts.failed + counts.completed} 举手</span>
          </span>
          <span class="project-total">${list.length}</span>
        </button>`;
    })
    .join("");

  elements.projectList.innerHTML = allItem + items;
}

function renderSummary() {
  const counts = getCounts(sessions);
  document.querySelector("#summaryRunning").textContent = counts.running;
  document.querySelector("#summaryCompleted").textContent = counts.completed;
  document.querySelector("#summaryWaiting").textContent = counts.waiting;
  document.querySelector("#summaryFailed").textContent = counts.failed;
  document.querySelector("#runningNavCount").textContent = counts.running;
  document.querySelector("#failedNavCount").textContent = counts.failed;
}

function renderProjectHeader() {
  const list = getProjectSessions();
  const counts = getCounts(list);
  const project = projects.find((item) => item.id === state.projectId);
  const rate = completionRate(list);

  elements.projectCode.textContent = project?.code || "PRJ—00";
  elements.projectTitle.textContent = project?.name || "全部项目";
  elements.projectMeta.textContent = project
    ? `${list.length} 位职员 · ${project.description}`
    : `共 ${projects.length} 个项目部门，${sessions.length} 位 Codex 职员已到岗`;
  elements.projectProgressText.textContent = `${rate}%`;
  elements.projectProgressBar.style.width = `${rate}%`;

  ["all", "running", "completed", "waiting", "failed"].forEach((key) => {
    const target = document.querySelector(`#${key}Count`);
    if (target) target.textContent = counts[key];
  });

  const failed = list.filter((session) => session.status === "failed");
  elements.attentionStrip.hidden = failed.length === 0;
  elements.attentionStrip.closest(".workspace-head")?.classList.toggle("has-attention", failed.length > 0);
  if (failed.length) {
    elements.attentionTitle.textContent = `${failed.length} 位职员举手申请授权`;
    elements.attentionText.textContent = failed[0].error || "请查看会话日志。";
  }
}

function getVisibleSessions() {
  const query = state.query.trim().toLowerCase();
  return getProjectSessions().filter((session) => {
    const matchesStatus = state.status === "all" || session.status === state.status;
    const staff = staffMeta(session);
    const haystack = `${staff.name} ${staff.desk} ${staff.badge} ${session.title} ${session.id} ${session.branch} ${session.activity}`.toLowerCase();
    return matchesStatus && (!query || haystack.includes(query));
  });
}

function sessionRow(session, index) {
  const meta = statusMeta[session.status];
  const staff = staffMeta(session);
  const raised = session.status === "completed" || session.status === "failed";
  const signal = session.status === "failed"
    ? `<span class="raise-badge is-request">${icon("hand")}申请授权</span>`
    : session.status === "completed"
      ? `<span class="raise-badge is-report">${icon("hand")}完成汇报</span>`
      : `<span class="staff-duty status-label">${meta.label}</span>`;
  const managerAction = session.status === "failed"
    ? `<button class="manager-action is-approve" type="button" data-action="approve" data-id="${session.id}">${icon("key")}处理申请</button>`
    : session.status === "completed"
      ? `<button class="manager-action is-report" type="button" data-action="open" data-id="${session.id}">${icon("check")}听取汇报</button>`
      : `<button class="manager-action" type="button" data-action="toggle" data-id="${session.id}">${icon(session.status === "running" ? "pause" : "play")}${session.status === "running" ? "暂停办理" : "安排办理"}</button>`;

  return `
    <article class="session-row status-${session.status} ${raised ? "is-raised" : ""}" data-session="${session.id}" style="animation-delay:${Math.min(index * 35, 210)}ms">
      <div class="staff-card-top">
        <div class="staff-profile">
          <span class="staff-avatar">
            ${icon("user")}
            ${raised ? `<span class="hand-signal ${session.status === "failed" ? "is-request" : "is-report"}">${icon("hand")}</span>` : `<span class="duty-signal"></span>`}
          </span>
          <span class="staff-identity">
            <strong>${staff.name}</strong>
            <small>${staff.desk} · ${staff.badge}</small>
          </span>
        </div>
        ${signal}
      </div>
      <button class="session-primary" type="button" data-action="open" data-id="${session.id}" aria-label="查看会话：${session.title}">
        <div class="session-copy">
          <span class="task-label">当前工作</span>
          <div class="session-title-line">
            <span class="session-title">${session.title}</span>
          </div>
          <div class="session-meta">
            <span class="branch-name">${icon("branch")}${session.branch}</span>
          </div>
        </div>
      </button>
      <div class="session-card-progress">
        <div class="progress-stats">
          <span class="status-percent">业务进度 ${session.progress}%</span>
          <strong>${session.duration} · ${session.tokens}</strong>
        </div>
        <div class="session-progress"><span style="width:${session.progress}%"></span></div>
      </div>
      <div class="session-card-foot">
        <span class="activity-summary"><strong>${session.activity}</strong><small>${session.updated}</small></span>
        ${managerAction}
      </div>
    </article>`;
}

function renderSessions() {
  const visible = getVisibleSessions();
  elements.sessionList.innerHTML = visible.map(sessionRow).join("");
  elements.sessionList.hidden = visible.length === 0;
  elements.emptyState.hidden = visible.length > 0;
  document.querySelector(".canvas-foot > p:first-child .mono").textContent = getProjectSessions().length;
}

function renderFilters() {
  document.querySelectorAll(".filter-chip").forEach((button) => {
    const active = button.dataset.status === state.status;
    button.classList.toggle("is-active", active);
    button.setAttribute("aria-pressed", String(active));
  });
}

function renderAll() {
  renderProjects();
  renderSummary();
  renderProjectHeader();
  renderFilters();
  renderSessions();
}

function selectProject(projectId) {
  state.projectId = projectId;
  state.status = "all";
  state.query = "";
  elements.searchInput.value = "";
  document.querySelectorAll(".nav-item").forEach((item) => item.classList.remove("is-active"));
  document.querySelector(".nav-item:first-child").classList.add("is-active");
  renderAll();
  closeSidebar();
}

function setStatus(status) {
  state.status = status;
  renderFilters();
  renderSessions();
}

function toggleSession(sessionId) {
  const session = sessions.find((item) => item.id === sessionId);
  if (!session) return;
  const staff = staffMeta(session);

  if (session.status === "running") {
    session.status = "waiting";
    session.activity = "经理已暂停办理";
    session.updated = "刚刚";
    showToast(`已让 ${staff.name} 暂停办理`);
  } else if (session.status === "waiting") {
    session.status = "running";
    session.activity = "已回到柜台继续办理";
    session.updated = "刚刚";
    session.progress = Math.max(3, session.progress);
    session.duration = session.duration === "—" ? "0m 04s" : session.duration;
    session.tokens = session.tokens === "0 tokens" ? "0.2k tokens" : session.tokens;
    session.agent = session.agent === "等待分配" ? "codex-4" : session.agent;
    showToast(`${staff.name} 已开始办理任务`);
  }

  renderAll();
  if (state.selectedSessionId === sessionId) openDrawer(sessionId);
}

function approveSession(sessionId) {
  const session = sessions.find((item) => item.id === sessionId);
  if (!session || session.status !== "failed") return;
  const staff = staffMeta(session);

  session.status = "running";
  session.progress = Math.max(session.progress, 42);
  session.activity = "已获经理授权，继续办理";
  session.updated = "刚刚";
  session.error = undefined;
  session.events = [
    ...session.events.map((event) => [event[0], event[1], event[2], event[3] === "error" ? "done" : event[3]]),
    ["经理已批准授权", new Date().toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" }), `${staff.name} 已恢复任务执行`, "current"],
  ];
  showToast(`已批准 ${staff.name} 的授权申请`);
  renderAll();
  if (state.selectedSessionId === sessionId) openDrawer(sessionId);
}

function statusColor(status) {
  return {
    running: "var(--amber)",
    completed: "var(--green)",
    waiting: "var(--slate)",
    failed: "var(--red)",
  }[status];
}

function openDrawer(sessionId) {
  const session = sessions.find((item) => item.id === sessionId);
  if (!session) return;
  const project = projects.find((item) => item.id === session.projectId);
  const meta = statusMeta[session.status];
  const staff = staffMeta(session);
  state.selectedSessionId = sessionId;
  document.querySelector("#drawerTitle").textContent = `${staff.name}的工作单`;

  elements.drawerBody.innerHTML = `
    <div class="drawer-employee">
      <span class="staff-avatar">
        ${icon("user")}
        ${session.status === "completed" || session.status === "failed" ? `<span class="hand-signal ${session.status === "failed" ? "is-request" : "is-report"}">${icon("hand")}</span>` : `<span class="duty-signal"></span>`}
      </span>
      <span class="staff-identity"><strong>${staff.name}</strong><small>${staff.desk} · ${staff.badge}</small></span>
      ${session.status === "failed" ? `<span class="raise-badge is-request">${icon("hand")}申请授权</span>` : session.status === "completed" ? `<span class="raise-badge is-report">${icon("hand")}完成汇报</span>` : ""}
    </div>
    <div class="drawer-status">
      <span class="status-label" style="color:${statusColor(session.status)}">${meta.label}</span>
      <span class="drawer-session-id">原会话 ${session.id}</span>
    </div>
    <p class="timeline-title">当前工作</p>
    <p class="drawer-prompt">${session.prompt}</p>
    ${session.error ? `<div class="attention-strip drawer-request"><svg><use href="#icon-hand"></use></svg><p><strong>向经理申请授权</strong><span>${session.error}</span></p></div>` : ""}
    <div class="drawer-meta-grid">
      <div class="drawer-meta-item">${icon("folder")}<div><span>所属项目</span><strong>${project.name}</strong></div></div>
      <div class="drawer-meta-item">${icon("branch")}<div><span>业务分支</span><strong>${session.branch}</strong></div></div>
      <div class="drawer-meta-item">${icon("clock")}<div><span>办理用时</span><strong>${session.duration}</strong></div></div>
      <div class="drawer-meta-item">${icon("activity")}<div><span>Token 用量</span><strong>${session.tokens}</strong></div></div>
    </div>
    <p class="timeline-title">工作记录</p>
    <div class="event-list">
      ${session.events.map((event) => `
        <div class="event ${event[3] === "current" ? "is-current" : ""} ${event[3] === "error" ? "is-error" : ""}">
          <div class="event-title"><strong>${event[0]}</strong><time>${event[1]}</time></div>
          <p>${event[2]}</p>
        </div>`).join("")}
    </div>`;

  const primaryButton = session.status === "failed"
    ? `<button class="button drawer-approve" type="button" data-drawer-action="approve">${icon("key")}批准并继续</button>`
    : session.status === "running" || session.status === "waiting"
      ? `<button class="button" type="button" data-drawer-action="toggle">${icon(session.status === "running" ? "pause" : "play")}${session.status === "running" ? "暂停办理" : "安排办理"}</button>`
      : "";
  elements.drawerFoot.innerHTML = `
    ${primaryButton}
    <button class="button button-secondary" type="button" data-drawer-action="copy">${icon("copy")}复制职员工号</button>`;

  elements.drawerBackdrop.hidden = false;
  elements.drawer.inert = false;
  elements.drawer.setAttribute("aria-hidden", "false");
  requestAnimationFrame(() => elements.drawer.classList.add("is-open"));
  document.querySelector("#drawerClose").focus();
}

function closeDrawer() {
  elements.drawer.classList.remove("is-open");
  elements.drawer.inert = true;
  elements.drawer.setAttribute("aria-hidden", "true");
  window.setTimeout(() => {
    elements.drawerBackdrop.hidden = true;
    state.selectedSessionId = null;
  }, 240);
}

function openSidebar() {
  elements.sidebar.inert = false;
  elements.sidebar.setAttribute("aria-hidden", "false");
  elements.sidebar.classList.add("is-open");
}

function closeSidebar() {
  elements.sidebar.classList.remove("is-open");
  syncSidebarAccess();
}

function syncSidebarAccess() {
  const isCompact = window.matchMedia("(max-width: 820px)").matches;
  const isOpen = elements.sidebar.classList.contains("is-open");
  elements.sidebar.inert = isCompact && !isOpen;
  elements.sidebar.setAttribute("aria-hidden", String(isCompact && !isOpen));
}

let toastTimer;
function showToast(message) {
  window.clearTimeout(toastTimer);
  elements.toast.textContent = message;
  elements.toast.classList.add("is-visible");
  toastTimer = window.setTimeout(() => elements.toast.classList.remove("is-visible"), 2200);
}

elements.projectList.addEventListener("click", (event) => {
  const button = event.target.closest("[data-project]");
  if (button) selectProject(button.dataset.project);
});

document.querySelector("#statusFilters").addEventListener("click", (event) => {
  const button = event.target.closest("[data-status]");
  if (button) setStatus(button.dataset.status);
});

elements.searchInput.addEventListener("input", (event) => {
  state.query = event.target.value;
  renderSessions();
});

elements.sessionList.addEventListener("click", (event) => {
  const action = event.target.closest("[data-action]");
  if (action) {
    event.stopPropagation();
    if (action.dataset.action === "toggle") toggleSession(action.dataset.id);
    else if (action.dataset.action === "approve") approveSession(action.dataset.id);
    else openDrawer(action.dataset.id);
    return;
  }
  const row = event.target.closest("[data-session]");
  if (row) openDrawer(row.dataset.session);
});

document.querySelector("#attentionAction").addEventListener("click", () => setStatus("failed"));
document.querySelector("#clearFilters").addEventListener("click", () => {
  state.status = "all";
  state.query = "";
  elements.searchInput.value = "";
  renderAll();
});

document.querySelector("#refreshButton").addEventListener("click", (event) => {
  const button = event.currentTarget;
  button.classList.add("is-refreshing");
  button.disabled = true;
  window.setTimeout(() => {
    button.classList.remove("is-refreshing");
    button.disabled = false;
    document.querySelector("#lastSync").textContent = new Date().toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit", second: "2-digit" });
    showToast("大厅职员状态已同步");
  }, 650);
});

document.querySelectorAll("[data-nav-filter]").forEach((button) => {
  button.addEventListener("click", () => {
    selectProject("all");
    setStatus(button.dataset.navFilter);
    document.querySelectorAll(".nav-item").forEach((item) => item.classList.remove("is-active"));
    button.classList.add("is-active");
  });
});

document.querySelector(".nav-item:first-child").addEventListener("click", (event) => {
  document.querySelectorAll(".nav-item").forEach((item) => item.classList.remove("is-active"));
  event.currentTarget.classList.add("is-active");
  selectProject("all");
});

document.querySelector("#drawerClose").addEventListener("click", closeDrawer);
elements.drawerBackdrop.addEventListener("click", closeDrawer);
document.querySelector("#menuButton").addEventListener("click", openSidebar);
document.querySelector("#sidebarClose").addEventListener("click", closeSidebar);
window.addEventListener("resize", syncSidebarAccess);

elements.drawerFoot.addEventListener("click", async (event) => {
  const action = event.target.closest("[data-drawer-action]");
  if (!action || !state.selectedSessionId) return;
  if (action.dataset.drawerAction === "toggle") {
    toggleSession(state.selectedSessionId);
  } else if (action.dataset.drawerAction === "approve") {
    approveSession(state.selectedSessionId);
  } else {
    const session = sessions.find((item) => item.id === state.selectedSessionId);
    const staffId = session ? staffMeta(session).badge : state.selectedSessionId;
    try {
      await navigator.clipboard.writeText(staffId);
      showToast(`已复制工号 ${staffId}`);
    } catch {
      showToast(`职员工号：${staffId}`);
    }
  }
});

document.addEventListener("keydown", (event) => {
  const typing = event.target.matches("input, textarea");
  if ((event.key === "/" && !typing) || ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k")) {
    event.preventDefault();
    elements.searchInput.focus();
  }
  if ((event.key.toLowerCase() === "r" && !typing) && !event.metaKey && !event.ctrlKey) {
    document.querySelector("#refreshButton").click();
  }
  if (event.key === "Escape") {
    if (elements.drawer.classList.contains("is-open")) closeDrawer();
    closeSidebar();
  }
});

elements.drawer.inert = true;
syncSidebarAccess();
renderAll();
