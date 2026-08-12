import AppKit
import CodexMonitorAppServer
import CodexMonitorCore
import CodexMonitorProtocol
import Foundation
import Observation
import SwiftUI

struct ReportAcknowledgement: Equatable {
  let threadIDs: [String]
  let message: String
}

enum RefreshPhase: Equatable {
  case idle
  case refreshing
  case succeeded(Date)
  case failed(String)

  var isRefreshing: Bool {
    if case .refreshing = self { return true }
    return false
  }
}

private struct TaskSelectionAnchor: Equatable {
  let taskID: String
  let filter: TaskFilter
  let projectID: String?
  let query: String
  let visibleOrder: [String]
}

private enum ThreadSyncKind {
  case full
  case discovery
}

private struct ThreadSync {
  let id: UInt64
  let generation: UInt64
  let kind: ThreadSyncKind
  let task: Task<Void, Error>
}

@MainActor
@Observable
final class AppModel {
  var connection = ConnectionStatus()
  var board = TaskBoardState()
  var models: [ModelOption] = []
  private(set) var selectedProjectID: String?
  var selectedTaskID: String?
  var searchText = ""
  var filter: TaskFilter = .all
  var isNewTaskPresented = false
  var isSettingsPresented = false
  var bannerMessage: String?
  var protocolWarningMessage: String?
  var reportAcknowledgement: ReportAcknowledgement?
  var isBusy = false
  var protocolCompatible = false
  var searchFocusRequest = 0
  private(set) var refreshPhase: RefreshPhase = .idle
  private(set) var lastSuccessfulRefreshAt: Date?

  let preferences: AppPreferences

  private let client: CodexAppServerClient
  private let api: AppServerAPI
  private let notifications = NotificationCoordinator()
  private let externalSessionObserver = ExternalSessionObserver()
  private var eventTask: Task<Void, Never>?
  private var externalObservationTask: Task<Void, Never>?
  private var threadDiscoveryTask: Task<Void, Never>?
  private var reconciliationTask: Task<Void, Never>?
  private var reconnectTask: Task<Void, Never>?
  private var acknowledgementDismissTask: Task<Void, Never>?
  private var selectionAnchor: TaskSelectionAnchor?
  private var externalObservationInitialized = false
  private var started = false
  private var isShuttingDown = false
  private var connectionInFlight = false
  private var reconnectAttempt = 0
  private var threadSync: ThreadSync?
  private var nextThreadSyncID: UInt64 = 0
  private var discoveryFailureCount = 0
  private var pendingNewThreadObservationIDs = Set<String>()
  private var filteredTaskCacheScope: TaskQueryScope?
  private var filteredTaskCacheRevision: UInt64?
  private var filteredTaskCache: [TaskRecord] = []

  init(
    preferences: AppPreferences? = nil,
    client: CodexAppServerClient = CodexAppServerClient()
  ) {
    let resolvedPreferences = preferences ?? AppPreferences()
    self.preferences = resolvedPreferences
    self.client = client
    api = AppServerAPI(client: client)
    board.restoreCachedTasks(resolvedPreferences.loadCachedTasks())
  }

  var tasks: [TaskRecord] {
    board.tasks
  }

  var filteredTasks: [TaskRecord] {
    let natural = naturallyFilteredTasks
    guard let selectionAnchor,
      selectionAnchor.filter == filter,
      selectionAnchor.projectID == selectedProjectID,
      selectionAnchor.query == normalizedSearchText
    else { return natural }
    return StableTaskOrderPolicy.apply(
      previousOrder: selectionAnchor.visibleOrder,
      to: natural
    )
  }

  private var naturallyFilteredTasks: [TaskRecord] {
    let scope = currentQueryScope
    if filteredTaskCacheScope != scope || filteredTaskCacheRevision != board.revision {
      filteredTaskCacheScope = scope
      filteredTaskCacheRevision = board.revision
      filteredTaskCache = board.filteredTasks(in: scope)
    }
    return filteredTaskCache
  }

  private var normalizedSearchText: String {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var currentQueryScope: TaskQueryScope {
    TaskQueryScope(
      projectID: selectedProjectID,
      filter: filter,
      query: normalizedSearchText,
      hidesSensitiveContent: preferences.privacyMode
    )
  }

  var selectedTask: TaskRecord? {
    guard let selectedTaskID else { return nil }
    return board.tasksByID[selectedTaskID]
  }

  var activeTasks: [TaskRecord] {
    tasks.filter {
      $0.ownership == .hostedLive
        && ($0.activeTurnID != nil
          || [.running, .needsApproval, .needsInput].contains($0.displayStatus))
    }
  }

  var canManageTasks: Bool { connection.isOnline && protocolCompatible }

  var scopedTasks: [TaskRecord] {
    board.tasks(projectID: selectedProjectID)
  }

  var attentionTasks: [TaskRecord] {
    board.filteredTasks(in: TaskQueryScope(projectID: nil, filter: .attention, query: ""))
  }
  var managerAttentionCount: Int { board.metrics.attention }
  var runningCount: Int { board.metrics.running }
  var approvalCount: Int { board.metrics.approval }
  var completedUnreadCount: Int { board.metrics.completedUnread }
  var unknownCount: Int { board.metrics.unknown }
  var historyCount: Int { board.metrics.history }
  private var scopedMetrics: TaskMetrics { board.metrics(projectID: selectedProjectID) }
  var scopedRunningCount: Int { scopedMetrics.running }
  var scopedApprovalCount: Int { scopedMetrics.approval }
  var scopedAttentionCount: Int { scopedMetrics.attention }
  var scopedCompletedUnreadCount: Int { scopedMetrics.completedUnread }
  var scopedHistoryCount: Int { scopedMetrics.history }

  func start() async {
    guard !started else { return }
    started = true
    isShuttingDown = false
    let events = client.events
    eventTask = Task { [weak self] in
      for await event in events {
        guard !Task.isCancelled else { return }
        await self?.handle(event)
      }
    }
    await connect()
    externalObservationTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        await self.refreshExternalSessionStatuses()
        do {
          try await Task.sleep(for: .seconds(2))
        } catch {
          return
        }
      }
    }
    threadDiscoveryTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        let delay = await self.discoverRecentThreadsIfNeeded()
        do {
          try await Task.sleep(for: .seconds(delay))
        } catch {
          return
        }
      }
    }
    reconciliationTask = Task { [weak self] in
      while !Task.isCancelled {
        do {
          try await Task.sleep(for: .seconds(60))
        } catch {
          return
        }
        guard !Task.isCancelled, let self else { return }
        await self.reconcileHostedState()
      }
    }
  }

  func connect() async {
    guard !connectionInFlight else { return }
    connectionInFlight = true
    defer { connectionInFlight = false }
    reconnectTask?.cancel()
    await client.stop()
    connection.phase = .detecting
    connection.detail = "正在查找 Codex…"
    connection.updatedAt = .now
    bannerMessage = nil

    do {
      let preferred = preferences.codexPath.isEmpty ? nil : preferences.codexPath
      let executable = try await Task.detached(priority: .userInitiated) {
        try CodexProcessLocator.locate(preferredPath: preferred)
      }.value
      connection.version = executable.version
      connection.executablePath = executable.url.path
      protocolCompatible = CodexVersionCompatibility.isValidated(executable.version)
      connection.phase = .starting
      connection.detail = "正在启动本地 App Server…"

      let generation = try await client.start(executable: executable.url)
      connection.generation = generation
      board.expireOpenRequests(olderThanGeneration: generation)
      connection.phase = .initializing
      connection.detail = "正在与 Codex 握手…"
      _ = try await api.initialize(version: appVersion)

      connection.phase = .syncing
      connection.detail = "正在同步职员状态…"
      try await refresh()
      if protocolCompatible {
        await resumeManagedThreads()
        try await refresh()
      }
      models = (try? await api.listModels()) ?? []

      connection.phase = .online
      connection.detail = protocolCompatible ? "App Server 已连接" : "App Server 已连接（只读兼容模式）"
      connection.updatedAt = .now
      reconnectAttempt = 0
      if !protocolCompatible {
        bannerMessage = "Codex 版本尚未经过协议验证，工作台已切换为只读模式。"
      }
    } catch {
      connection.phase = .unavailable
      connection.detail = error.localizedDescription
      connection.updatedAt = .now
      bannerMessage = error.localizedDescription
    }
  }

  func retry() {
    Task { await connect() }
  }

  func refreshFromUI() async {
    guard !refreshPhase.isRefreshing else { return }
    if case .failed = refreshPhase { bannerMessage = nil }
    refreshPhase = .refreshing
    do {
      try await refresh()
      let completedAt = Date.now
      lastSuccessfulRefreshAt = completedAt
      refreshPhase = .succeeded(completedAt)
    } catch is CancellationError {
      refreshPhase = .idle
    } catch {
      let message = "状态核对失败：\(error.localizedDescription)"
      refreshPhase = .failed(message)
      bannerMessage = "\(message)。请重试。"
    }
  }

  func retryRefresh() {
    Task { await refreshFromUI() }
  }

  func dismissRefreshFailure() {
    if case .failed = refreshPhase { refreshPhase = .idle }
    bannerMessage = nil
  }

  func revalidateAfterWake() async {
    guard !connectionInFlight else { return }
    if await client.isRunning {
      do {
        connection.phase = .syncing
        connection.detail = "正在校准唤醒后的状态…"
        try await refresh()
        connection.phase = .online
        connection.detail = protocolCompatible ? "App Server 已连接" : "App Server 已连接（只读兼容模式）"
        connection.updatedAt = .now
        return
      } catch {
        // A live process with a broken transport must be replaced before the full handshake.
      }
    }
    await connect()
  }

  func refresh() async throws {
    while let inFlight = threadSync {
      if inFlight.generation != connection.generation {
        inFlight.task.cancel()
        _ = try? await awaitThreadSync(inFlight)
        continue
      } else {
        switch inFlight.kind {
        case .full:
          try await awaitThreadSync(inFlight)
          return
        case .discovery:
          _ = try? await awaitThreadSync(inFlight)
          continue
        }
      }
    }

    let generation = connection.generation
    let sync = makeThreadSync(kind: .full, generation: generation) { [weak self] in
      guard let self else { return }
      try await self.performFullRefresh(expectedGeneration: generation)
    }
    threadSync = sync
    try await awaitThreadSync(sync)
  }

  private func performFullRefresh(expectedGeneration: UInt64) async throws {
    let threads = try await api.listThreads()
    try ensureCurrentGeneration(expectedGeneration)
    board.mergeThreads(threads, managedIDs: preferences.managedThreadIDs)
    if let selectedProjectID,
      !board.projects.contains(where: { $0.id == selectedProjectID })
    {
      selectProject(id: nil)
    }
    if let selectedTaskID, board.tasksByID[selectedTaskID] == nil {
      dismissTaskSelection()
    }
    await refreshExternalSessionStatuses(expectedGeneration: expectedGeneration)
    try ensureCurrentGeneration(expectedGeneration)
    protocolWarningMessage = nil
    if connection.phase == .online {
      connection.detail = protocolCompatible ? "App Server 已连接" : "App Server 已连接（只读兼容模式）"
      connection.updatedAt = .now
    }
    lastSuccessfulRefreshAt = .now
    persistCache()
  }

  private func reconcileHostedState() async {
    guard connection.isOnline, !isShuttingDown else { return }
    do {
      try await refresh()
      lastSuccessfulRefreshAt = .now
    } catch is CancellationError {
      return
    } catch {
      protocolWarningMessage = "自动状态核对失败，将在 60 秒内重试。也可以立即点击“刷新”重新核对。"
    }
  }

  private func refreshExternalSessionStatuses(
    including additionalThreadIDs: Set<String> = [],
    reportNewCompletionsFor: Set<String> = [],
    expectedGeneration: UInt64? = nil
  ) async {
    let observationGeneration = expectedGeneration ?? connection.generation
    pendingNewThreadObservationIDs = pendingNewThreadObservationIDs.filter {
      board.tasksByID[$0]?.ownership == .historyOnly
    }
    var threadIDs = ExternalObservationPolicy.candidateThreadIDs(tasks: board.tasks)
    threadIDs.formUnion(additionalThreadIDs)
    threadIDs.formUnion(pendingNewThreadObservationIDs)
    guard !threadIDs.isEmpty else { return }
    let snapshots = await externalSessionObserver.poll(threadIDs: threadIDs)
    guard observationGeneration == connection.generation else { return }

    let previous = Dictionary(
      uniqueKeysWithValues: board.tasks.map { ($0.id, $0.displayStatus) })
    let previousRevision = board.revision
    board.applyExternalSessionSnapshots(
      snapshots,
      reportNewCompletionsFor: reportNewCompletionsFor.union(pendingNewThreadObservationIDs)
    )
    let conclusivelyObservedIDs = snapshots.compactMap { threadID, snapshot in
      snapshot.lifecycle == .unknown ? nil : threadID
    }
    pendingNewThreadObservationIDs.subtract(conclusivelyObservedIDs)
    guard board.revision != previousRevision else {
      externalObservationInitialized = true
      return
    }
    if externalObservationInitialized, preferences.notificationsEnabled {
      await notifyStatusChanges(previous: previous)
    }
    externalObservationInitialized = true
  }

  private func discoverRecentThreadsIfNeeded() async -> Double {
    guard connection.isOnline else { return 5 }
    guard threadSync == nil else { return 5 }

    let generation = connection.generation
    let sync = makeThreadSync(kind: .discovery, generation: generation) { [weak self] in
      guard let self else { return }
      try await self.performThreadDiscovery(expectedGeneration: generation)
    }
    threadSync = sync

    do {
      try await awaitThreadSync(sync)
      if discoveryFailureCount >= 3, connection.isOnline {
        connection.detail = protocolCompatible ? "App Server 已连接" : "App Server 已连接（只读兼容模式）"
        connection.updatedAt = .now
      }
      discoveryFailureCount = 0
      return 5
    } catch is CancellationError {
      return 5
    } catch {
      discoveryFailureCount += 1
      if discoveryFailureCount >= 3, connection.isOnline {
        connection.detail = "App Server 已连接（新会话发现正在重试）"
        connection.updatedAt = .now
      }
      return min(60, 5 * pow(2, Double(discoveryFailureCount)))
    }
  }

  private func performThreadDiscovery(expectedGeneration: UInt64) async throws {
    let threads = try await api.listRecentThreads()
    try ensureCurrentGeneration(expectedGeneration)
    guard connection.isOnline else { throw CancellationError() }

    let newThreadIDs = board.mergeDiscoveredThreads(
      threads,
      managedIDs: preferences.managedThreadIDs
    )
    guard !newThreadIDs.isEmpty else { return }

    pendingNewThreadObservationIDs.formUnion(newThreadIDs)
    persistCache()
    await refreshExternalSessionStatuses(
      including: newThreadIDs,
      reportNewCompletionsFor: newThreadIDs,
      expectedGeneration: expectedGeneration
    )
    try ensureCurrentGeneration(expectedGeneration)
  }

  private func makeThreadSync(
    kind: ThreadSyncKind,
    generation: UInt64,
    operation: @escaping @MainActor () async throws -> Void
  ) -> ThreadSync {
    nextThreadSyncID &+= 1
    return ThreadSync(
      id: nextThreadSyncID,
      generation: generation,
      kind: kind,
      task: Task { @MainActor in try await operation() }
    )
  }

  private func awaitThreadSync(_ sync: ThreadSync) async throws {
    defer {
      if threadSync?.id == sync.id { threadSync = nil }
    }
    try await sync.task.value
  }

  private func ensureCurrentGeneration(_ expectedGeneration: UInt64) throws {
    guard expectedGeneration == connection.generation else { throw CancellationError() }
  }

  func createTask(_ draft: TaskDraft) async -> Bool {
    guard draft.isValid, canManageTasks else { return false }
    isBusy = true
    defer { isBusy = false }
    do {
      let started = try await api.startTask(draft)
      preferences.managedThreadIDs.insert(started.threadID)
      try await refresh()
      board.markManaged(threadID: started.threadID)
      selectTask(threadID: started.threadID)
      isNewTaskPresented = false
      persistCache()
      return true
    } catch {
      bannerMessage = error.localizedDescription
      return false
    }
  }

  func takeOver(_ task: TaskRecord, prompt: String) async -> Bool {
    guard !task.isExternalActive else {
      bannerMessage = "这个会话正在另一个 Codex 客户端中运行，请先在原客户端结束或暂停任务。"
      return false
    }
    guard canManageTasks, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return false
    }
    isBusy = true
    defer { isBusy = false }
    do {
      _ = try await api.resumeAndStartTurn(
        threadID: task.id,
        prompt: prompt,
        cwd: task.cwd,
        model: nil
      )
      preferences.managedThreadIDs.insert(task.id)
      board.markManaged(threadID: task.id)
      try await refresh()
      selectTask(task)
      persistCache()
      return true
    } catch {
      bannerMessage = error.localizedDescription
      return false
    }
  }

  func decide(_ request: AttentionRequest, decision: ApprovalDecision) async {
    guard canManageTasks,
      request.generation == connection.generation,
      board.markResponding(request)
    else {
      bannerMessage = "这项请示已经失效，请等待状态重新同步。"
      return
    }
    do {
      try await api.respond(to: request, decision: decision)
      preferences.recordAudit(
        taskID: request.threadID,
        kind: request.kind,
        action: decision.rawValue,
        outcome: "sent"
      )
    } catch {
      _ = board.restoreOpenRequest(request)
      persistCache()
      bannerMessage = "授权结果未能送达：\(error.localizedDescription)。这项请示仍可重试。"
      preferences.recordAudit(
        taskID: request.threadID,
        kind: request.kind,
        action: decision.rawValue,
        outcome: "failed"
      )
    }
  }

  func answer(_ request: AttentionRequest, answers: [String: [String]]) async {
    guard canManageTasks,
      request.kind == .userInput,
      request.generation == connection.generation,
      board.markResponding(request)
    else {
      bannerMessage = "这项请示已经失效，请等待状态重新同步。"
      return
    }
    do {
      try await api.respond(to: request, decision: .accept, answers: answers)
      preferences.recordAudit(
        taskID: request.threadID,
        kind: request.kind,
        action: "answer",
        outcome: "sent"
      )
    } catch {
      _ = board.restoreOpenRequest(request)
      persistCache()
      bannerMessage = "回答未能送达：\(error.localizedDescription)。已保留填写内容，可以重试。"
      preferences.recordAudit(
        taskID: request.threadID,
        kind: request.kind,
        action: "answer",
        outcome: "failed"
      )
    }
  }

  @discardableResult
  func interrupt(_ task: TaskRecord) async -> Bool {
    guard canManageTasks, let turnID = task.activeTurnID else { return false }
    do {
      try await api.interrupt(threadID: task.id, turnID: turnID)
      return true
    } catch {
      bannerMessage = error.localizedDescription
      return false
    }
  }

  func interruptAllActiveTasks() async -> Bool {
    var allSucceeded = true
    for task in activeTasks {
      if !(await interrupt(task)) { allSucceeded = false }
    }
    return allSucceeded
  }

  func shutdown() async {
    guard !isShuttingDown else { return }
    isShuttingDown = true
    eventTask?.cancel()
    externalObservationTask?.cancel()
    threadDiscoveryTask?.cancel()
    reconciliationTask?.cancel()
    reconnectTask?.cancel()
    acknowledgementDismissTask?.cancel()
    threadSync?.task.cancel()
    eventTask = nil
    externalObservationTask = nil
    threadDiscoveryTask = nil
    reconciliationTask = nil
    reconnectTask = nil
    acknowledgementDismissTask = nil
    threadSync = nil
    await client.stop()
    connection.phase = .disconnected
    connection.detail = "已安全停止"
    connection.updatedAt = .now
    refreshPhase = .idle
    started = false
  }

  func markCompletedSeen(_ task: TaskRecord) {
    guard task.displayStatus == .completedUnseen else { return }
    releaseSelectionAnchor(for: task.id)
    board.markCompletedSeen(threadID: task.id)
    showReportAcknowledgement(
      threadIDs: [task.id],
      message: "已确认 \(StaffIdentity.name(for: task.id)) 的完成汇报"
    )
    persistCache()
  }

  func undoLastReportAcknowledgement() {
    guard let acknowledgement = reportAcknowledgement else { return }
    acknowledgementDismissTask?.cancel()
    for threadID in acknowledgement.threadIDs {
      board.restoreCompletedUnseen(threadID: threadID)
    }
    reportAcknowledgement = nil
    persistCache()
  }

  func dismissReportAcknowledgement() {
    acknowledgementDismissTask?.cancel()
    reportAcknowledgement = nil
  }

  func openInCodex(_ task: TaskRecord) {
    guard let url = CodexThreadLink.url(threadID: task.id) else {
      bannerMessage = "这个会话的编号无效，无法在 Codex 中打开。"
      return
    }
    guard NSWorkspace.shared.urlForApplication(toOpen: url) != nil else {
      bannerMessage = "没有找到可以打开这个会话的 Codex 客户端。"
      return
    }
    guard NSWorkspace.shared.open(url) else {
      bannerMessage = "Codex 未能打开这个会话，请稍后重试。"
      return
    }
  }

  func markCurrentProjectReportsSeen() {
    let projectID = selectedProjectID
    let reports = tasks.filter {
      $0.displayStatus == .completedUnseen
        && (projectID == nil || $0.projectID == projectID)
    }
    guard !reports.isEmpty else { return }
    if let selectedTaskID, reports.contains(where: { $0.id == selectedTaskID }) {
      releaseSelectionAnchor(for: selectedTaskID)
    }
    for task in reports {
      board.markCompletedSeen(threadID: task.id)
    }
    showReportAcknowledgement(
      threadIDs: reports.map(\.id),
      message: "已确认 \(reports.count) 份完成汇报"
    )
    persistCache()
  }

  func selectProject(id: String?) {
    guard selectedProjectID != id else { return }
    selectedProjectID = id
    filteredTaskCacheScope = nil
    filteredTaskCacheRevision = nil
    selectionAnchor = nil
    selectedTaskID = TaskSelectionPolicy.retainedTaskID(
      afterSelecting: id,
      currentTaskID: selectedTaskID,
      tasksByID: board.tasksByID
    )
  }

  func selectTask(_ task: TaskRecord) {
    let visible = naturallyFilteredTasks
    selectionAnchor =
      visible.contains(where: { $0.id == task.id })
      ? TaskSelectionAnchor(
        taskID: task.id,
        filter: filter,
        projectID: selectedProjectID,
        query: normalizedSearchText,
        visibleOrder: visible.map(\.id)
      ) : nil
    selectedTaskID = task.id
  }

  func selectTask(threadID: String) {
    guard let task = board.tasksByID[threadID] else {
      selectionAnchor = nil
      selectedTaskID = threadID
      return
    }
    selectTask(task)
  }

  func dismissTaskSelection() {
    selectionAnchor = nil
    selectedTaskID = nil
  }

  func moveSelection(_ direction: MoveCommandDirection, columns: Int) {
    let visible = filteredTasks
    guard !visible.isEmpty else { return }
    guard let selectedTaskID,
      let index = visible.firstIndex(where: { $0.id == selectedTaskID })
    else {
      selectTask(visible[0])
      return
    }
    let columns = max(1, columns)
    let delta: Int
    switch direction {
    case .left: delta = -1
    case .right: delta = 1
    case .up: delta = -columns
    case .down: delta = columns
    @unknown default: return
    }
    selectTask(visible[min(max(index + delta, 0), visible.count - 1)])
  }

  func revealTask(threadID: String) async {
    selectProject(id: nil)
    filter = .all
    searchText = ""
    if board.tasksByID[threadID] == nil {
      do {
        try await refresh()
      } catch {
        dismissTaskSelection()
        bannerMessage = "无法定位通知对应的会话：\(error.localizedDescription)。请刷新后重试。"
        return
      }
    }
    guard let task = board.tasksByID[threadID] else {
      dismissTaskSelection()
      bannerMessage = "通知对应的会话尚未同步或已不在 Codex 中。请刷新后重试。"
      return
    }
    selectTask(task)
  }

  func enableNotifications() async {
    let granted = await notifications.requestAuthorization()
    preferences.notificationsEnabled = granted
    if !granted { bannerMessage = "系统没有授予通知权限。" }
  }

  func clearLocalData() {
    preferences.clearLocalData()
    board = TaskBoardState()
    dismissTaskSelection()
    dismissReportAcknowledgement()
    selectProject(id: nil)
    Task {
      await notifications.clear()
      try? await refresh()
    }
  }

  func diagnosticsText() async -> String {
    let serverLog = await client.sanitizedDiagnostics()
    return """
      Codex Monitor \(appVersion)
      连接：\(connection.phase.rawValue)
      Codex：\(connection.version ?? "未知")
      Server 代次：\(connection.generation)
      托管任务：\(preferences.managedThreadIDs.count)
      当前举手：\(approvalCount)
      本地审批摘要：\(preferences.auditCount)

      \(serverLog)
      """
  }

  private var appVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
  }

  private func releaseSelectionAnchor(for threadID: String) {
    if selectionAnchor?.taskID == threadID { selectionAnchor = nil }
  }

  private func showReportAcknowledgement(threadIDs: [String], message: String) {
    acknowledgementDismissTask?.cancel()
    reportAcknowledgement = ReportAcknowledgement(threadIDs: threadIDs, message: message)
    acknowledgementDismissTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(6))
      guard !Task.isCancelled else { return }
      self?.reportAcknowledgement = nil
    }
  }

  private func resumeManagedThreads() async {
    for id in preferences.managedThreadIDs {
      _ = try? await api.resume(threadID: id)
    }
  }

  private func handle(_ event: AppServerInbound) async {
    switch event {
    case .notification(let method, let params, let generation):
      guard generation == connection.generation else { return }
      let oldStatuses = Dictionary(
        uniqueKeysWithValues: board.tasks.map { ($0.id, $0.displayStatus) })
      board.applyNotification(method: method, params: params)
      persistCache()
      if preferences.notificationsEnabled {
        await notifyStatusChanges(previous: oldStatuses)
      }
    case .serverRequest(let id, let method, let params, let generation):
      guard generation == connection.generation else { return }
      guard protocolCompatible else {
        await api.rejectUnknownRequest(id: id, generation: generation)
        bannerMessage = "只读兼容模式不会处理授权请求。"
        return
      }
      if let request = board.addServerRequest(
        id: id, method: method, params: params, generation: generation)
      {
        persistCache()
        if preferences.notificationsEnabled, let task = board.tasksByID[request.threadID] {
          await notifications.notify(
            task: task,
            title: "\(StaffIdentity.name(for: task.id)) 正在举手",
            body: request.title,
            privacyMode: preferences.privacyMode
          )
        }
      } else {
        await api.rejectUnknownRequest(id: id, generation: generation)
      }
    case .protocolError(let message, let generation):
      guard generation == connection.generation else { return }
      protocolWarningMessage =
        "有一条实时消息未能解析，已保留上次有效状态。当前状态可能不完整，请点击“刷新”重新核对。"
      connection.detail = "App Server 已连接（1 条消息待核对：\(message)）"
      connection.updatedAt = .now
    case .terminated(let status, let generation):
      guard generation == connection.generation else { return }
      board.expireOpenRequests(olderThanGeneration: generation + 1)
      connection.phase = .reconnecting
      connection.detail = "App Server 已退出（\(status)），正在重连…"
      connection.updatedAt = .now
      persistCache()
      scheduleReconnect()
    }
  }

  private func scheduleReconnect() {
    reconnectTask?.cancel()
    let delays: [Double] = [0.5, 1, 2, 4, 8, 15, 30]
    let delay = delays[min(reconnectAttempt, delays.count - 1)]
    reconnectAttempt += 1
    reconnectTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(delay))
      guard !Task.isCancelled else { return }
      await self?.connect()
    }
  }

  private func notifyStatusChanges(previous: [String: TaskDisplayStatus]) async {
    for task in board.tasks {
      guard previous[task.id] != task.displayStatus else { continue }
      if task.displayStatus == .completedUnseen {
        await notifications.notifyCompletion(
          task: task,
          privacyMode: preferences.privacyMode
        )
      } else if task.displayStatus == .failed {
        await notifications.notify(
          task: task,
          title: "\(StaffIdentity.name(for: task.id)) 异常汇报",
          body: task.projectName,
          privacyMode: preferences.privacyMode
        )
      }
    }
  }

  private func persistCache() {
    preferences.cache(tasks: board.tasks)
  }
}
