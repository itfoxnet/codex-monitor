import CodexMonitorProtocol
import Foundation
import Testing

@testable import CodexMonitorCore

private let thread: JSONValue = [
  "id": "thr_019fd2f0",
  "sessionId": "thr_019fd2f0",
  "cwd": "/Users/demo/Project",
  "name": "修复登录测试",
  "preview": "修复登录测试并运行单元测试",
  "source": "appServer",
  "status": ["type": "active", "activeFlags": []],
  "createdAt": 1_754_400_000,
  "updatedAt": 1_754_400_010,
]

@Test func codexThreadLinkAcceptsOnlyUUIDThreadIDs() {
  let threadID = "019fd20d-2d0a-7733-a3eb-99500c66f3bd"
  #expect(CodexThreadLink.url(threadID: threadID)?.absoluteString == "codex://threads/\(threadID)")
  #expect(CodexThreadLink.url(threadID: "../../settings") == nil)
}

@Test func historyAndHostedTasksHaveDifferentAuthority() {
  var state = TaskBoardState()
  state.mergeThreads([thread], managedIDs: [])
  #expect(state.tasks.first?.displayStatus == .historyOnly)

  state.mergeThreads([thread], managedIDs: ["thr_019fd2f0"])
  #expect(state.tasks.first?.ownership == .hostedLive)
  #expect(state.tasks.first?.displayStatus == .running)
}

@Test func incrementalDiscoveryOnlyInsertsAndIsIdempotent() {
  var state = TaskBoardState()
  state.mergeThreads([thread], managedIDs: [])
  state.applyExternalSessionSnapshots([
    "thr_019fd2f0": ExternalSessionSnapshot(lifecycle: .active, updatedAt: .now)
  ])

  let olderThread: JSONValue = [
    "id": "older-thread",
    "cwd": "/Users/demo/OlderProject",
    "name": "旧卡片",
    "status": ["type": "idle"],
    "createdAt": 1_754_300_000,
    "updatedAt": 1_754_300_010,
  ]
  state.mergeThreads([thread, olderThread], managedIDs: [])
  let existingBeforeDiscovery = state.tasksByID["thr_019fd2f0"]

  let staleCopyOfExisting: JSONValue = [
    "id": "thr_019fd2f0",
    "cwd": "/Users/demo/Project",
    "name": "不应覆盖现有卡片",
    "status": ["type": "idle"],
    "createdAt": 1_754_400_000,
    "updatedAt": 1_754_400_011,
  ]
  let newlyDiscovered: JSONValue = [
    "id": "new-thread",
    "cwd": "/Users/demo/NewProject",
    "name": "启动后新会话",
    "status": ["type": "active", "activeFlags": []],
    "createdAt": 1_754_500_000,
    "updatedAt": 1_754_500_010,
  ]

  let inserted = state.mergeDiscoveredThreads(
    [staleCopyOfExisting, newlyDiscovered], managedIDs: [])

  #expect(inserted == ["new-thread"])
  #expect(state.tasksByID["thr_019fd2f0"] == existingBeforeDiscovery)
  #expect(state.tasksByID["thr_019fd2f0"]?.displayStatus == .running)
  #expect(state.tasksByID["older-thread"]?.title == "旧卡片")
  #expect(state.tasksByID["new-thread"]?.title == "启动后新会话")
  #expect(state.tasks.count == 3)

  let repeated = state.mergeDiscoveredThreads(
    [staleCopyOfExisting, newlyDiscovered], managedIDs: [])
  #expect(repeated.isEmpty)
  #expect(state.tasks.count == 3)
  #expect(state.tasksByID["thr_019fd2f0"] == existingBeforeDiscovery)
}

@Test func freshCompletionForNewDiscoveryIsUnreadButOldCompletionRemainsHistory() {
  let now = Date(timeIntervalSince1970: 2_000_000)
  let newThread: JSONValue = [
    "id": "newly-completed-thread",
    "cwd": "/Users/demo/NewProject",
    "name": "刚完成的新会话",
    "status": ["type": "idle"],
    "createdAt": 1_999_900,
    "updatedAt": 2_000_000,
  ]
  let oldThread: JSONValue = [
    "id": "old-completed-thread",
    "cwd": "/Users/demo/OldProject",
    "name": "启动前已完成会话",
    "status": ["type": "idle"],
    "createdAt": 1_900_000,
    "updatedAt": 1_900_100,
  ]
  var state = TaskBoardState()
  let newlyDiscovered = state.mergeDiscoveredThreads([newThread, oldThread], managedIDs: [])

  state.applyExternalSessionSnapshots(
    [
      "newly-completed-thread": ExternalSessionSnapshot(
        lifecycle: .completed, updatedAt: now),
      "old-completed-thread": ExternalSessionSnapshot(
        lifecycle: .completed, updatedAt: now.addingTimeInterval(-10_000)),
    ],
    reportNewCompletionsFor: newlyDiscovered,
    now: now
  )

  #expect(state.tasksByID["newly-completed-thread"]?.displayStatus == .completedUnseen)
  #expect(state.tasksByID["newly-completed-thread"]?.rawStatus == "externalCompleted")
  #expect(state.tasksByID["old-completed-thread"]?.displayStatus == .historyOnly)
  #expect(state.tasksByID["old-completed-thread"]?.rawStatus == "notLoaded")
}

@Test func externalLifecyclePromotesRunningAndCompletionWithoutGrantingControl() {
  var state = TaskBoardState()
  state.mergeThreads([thread], managedIDs: [])

  state.applyExternalSessionSnapshots([
    "thr_019fd2f0": ExternalSessionSnapshot(lifecycle: .active, updatedAt: .now)
  ])
  #expect(state.tasks.first?.displayStatus == .running)
  #expect(state.tasks.first?.ownership == .historyOnly)
  #expect(state.tasks.first?.isExternallyObserved == true)

  state.mergeThreads([thread], managedIDs: [])
  #expect(state.tasks.first?.displayStatus == .running)

  state.applyExternalSessionSnapshots([
    "thr_019fd2f0": ExternalSessionSnapshot(lifecycle: .completed, updatedAt: .now)
  ])
  #expect(state.tasks.first?.displayStatus == .completedUnseen)
  #expect(state.tasks.first?.ownership == .historyOnly)
}

@Test func alreadyCompletedExternalSessionRemainsHistory() {
  var state = TaskBoardState()
  state.mergeThreads([thread], managedIDs: [])
  state.applyExternalSessionSnapshots([
    "thr_019fd2f0": ExternalSessionSnapshot(lifecycle: .completed, updatedAt: .now)
  ])
  #expect(state.tasks.first?.displayStatus == .historyOnly)
}

@Test func staleUnfinishedExternalSessionDoesNotRemainRunningForever() {
  let now = Date(timeIntervalSince1970: 2_000_000)
  var state = TaskBoardState()
  state.mergeThreads([thread], managedIDs: [])
  state.applyExternalSessionSnapshots(
    [
      "thr_019fd2f0": ExternalSessionSnapshot(
        lifecycle: .active,
        updatedAt: now.addingTimeInterval(-601)
      )
    ],
    now: now
  )

  #expect(state.tasks.first?.displayStatus == .historyOnly)
  #expect(state.tasks.first?.rawStatus == "notLoaded")
}

@Test func oldExternalFailuresAndInterruptionsStayInHistory() {
  let now = Date(timeIntervalSince1970: 20_000)
  for lifecycle in [ExternalSessionLifecycle.failed, .interrupted] {
    var state = TaskBoardState()
    state.mergeThreads([thread], managedIDs: [])
    state.applyExternalSessionSnapshots(
      [
        "thr_019fd2f0": ExternalSessionSnapshot(
          lifecycle: lifecycle,
          updatedAt: now.addingTimeInterval(-10_000)
        )
      ],
      now: now
    )

    #expect(state.tasks.first?.displayStatus == .historyOnly)
  }
}

@Test func externalSessionObserverTracksAppendedLifecycleEvents() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let day = root.appendingPathComponent("2026/08/09")
  let threadID = "019fe777-1234-7abc-8def-1234567890ab"
  let log = day.appendingPathComponent("rollout-2026-08-09T12-00-00-\(threadID).jsonl")
  try FileManager.default.createDirectory(at: day, withIntermediateDirectories: true)
  try Data(
    """
    {"type":"event_msg","payload":{"type":"task_started"}}
    {"type":"event_msg","payload":{"type":"agent_reasoning"}}

    """.utf8
  ).write(to: log)
  defer { try? FileManager.default.removeItem(at: root) }

  let observer = ExternalSessionObserver(sessionsRoot: root)
  var snapshots = await observer.poll(threadIDs: [threadID])
  #expect(snapshots[threadID]?.lifecycle == .active)
  snapshots = await observer.poll(threadIDs: [threadID])
  #expect(snapshots.isEmpty)

  let handle = try FileHandle(forWritingTo: log)
  try handle.seekToEnd()
  try handle.write(
    contentsOf: Data(
      "{\"type\":\"event_msg\",\"payload\":{\"type\":\"task_complete\"}}\n".utf8))
  try handle.close()

  snapshots = await observer.poll(threadIDs: [threadID])
  #expect(snapshots[threadID]?.lifecycle == .completed)
}

@Test func approvalRequestRaisesAndResolvesTheCard() throws {
  var state = TaskBoardState()
  state.mergeThreads([thread], managedIDs: ["thr_019fd2f0"])
  let request = state.addServerRequest(
    id: .integer(42),
    method: "item/commandExecution/requestApproval",
    params: [
      "threadId": "thr_019fd2f0",
      "turnId": "turn_1",
      "itemId": "item_1",
      "command": "swift test",
      "cwd": "/Users/demo/Project",
      "reason": "运行测试",
    ],
    generation: 2
  )
  #expect(request?.kind == .commandApproval)
  #expect(state.tasks.first?.displayStatus == .needsApproval)
  #expect(state.markResponding(try #require(request)))

  state.applyNotification(
    method: "serverRequest/resolved",
    params: [
      "threadId": "thr_019fd2f0",
      "requestId": 42,
    ])
  #expect(state.tasks.first?.attentions.first?.state == .resolved)
  #expect(state.tasks.first?.displayStatus == .running)
}

@Test func staleRequestsExpireAcrossConnectionGenerations() {
  var state = TaskBoardState()
  state.mergeThreads([thread], managedIDs: ["thr_019fd2f0"])
  _ = state.addServerRequest(
    id: .string("request-a"),
    method: "item/fileChange/requestApproval",
    params: ["threadId": "thr_019fd2f0", "turnId": "turn_1", "itemId": "item_1"],
    generation: 1
  )
  state.expireOpenRequests(olderThanGeneration: 2)
  #expect(state.tasks.first?.attentions.first?.state == .expired)
  #expect(state.tasks.first?.displayStatus == .unknown)
}

@Test func concurrentRequestsResolveIndependentlyAndDuplicateIDsRemainIdempotent() throws {
  var state = TaskBoardState()
  state.mergeThreads([thread], managedIDs: ["thr_019fd2f0"])
  state.applyNotification(
    method: "turn/started",
    params: ["threadId": "thr_019fd2f0", "turn": ["id": "turn_1"]]
  )
  let first = state.addServerRequest(
    id: .integer(1),
    method: "item/commandExecution/requestApproval",
    params: ["threadId": "thr_019fd2f0", "turnId": "turn_1", "itemId": "item_1"],
    generation: 3
  )
  _ = state.addServerRequest(
    id: .integer(1),
    method: "item/commandExecution/requestApproval",
    params: ["threadId": "thr_019fd2f0", "turnId": "turn_1", "itemId": "item_1"],
    generation: 3
  )
  _ = state.addServerRequest(
    id: .integer(2),
    method: "item/fileChange/requestApproval",
    params: ["threadId": "thr_019fd2f0", "turnId": "turn_1", "itemId": "item_2"],
    generation: 3
  )

  #expect(state.tasks.first?.attentions.count == 2)
  #expect(state.markResponding(try #require(first)))
  #expect(!state.markResponding(try #require(first)))
  state.applyNotification(
    method: "serverRequest/resolved",
    params: ["threadId": "thr_019fd2f0", "requestId": 1]
  )
  #expect(state.tasks.first?.openAttentions.count == 1)
  #expect(state.tasks.first?.displayStatus == .needsApproval)
}

@Test func lateCompletionCannotFinishANewerActiveTurn() {
  var state = TaskBoardState()
  state.mergeThreads([thread], managedIDs: ["thr_019fd2f0"])
  state.applyNotification(
    method: "turn/started",
    params: ["threadId": "thr_019fd2f0", "turn": ["id": "turn_new"]]
  )
  state.applyNotification(
    method: "turn/completed",
    params: ["threadId": "thr_019fd2f0", "turn": ["id": "turn_old", "status": "completed"]]
  )
  #expect(state.tasks.first?.activeTurnID == "turn_new")
  #expect(state.tasks.first?.displayStatus == .running)
}

@Test func completionCreatesUnreadReport() {
  var state = TaskBoardState()
  state.mergeThreads([thread], managedIDs: ["thr_019fd2f0"])
  state.applyNotification(
    method: "turn/completed",
    params: [
      "threadId": "thr_019fd2f0",
      "turn": ["id": "turn_1", "status": "completed"],
    ])
  #expect(state.tasks.first?.displayStatus == .completedUnseen)
  state.markCompletedSeen(threadID: "thr_019fd2f0")
  #expect(state.tasks.first?.displayStatus == .completedSeen)
  state.restoreCompletedUnseen(threadID: "thr_019fd2f0")
  #expect(state.tasks.first?.displayStatus == .completedUnseen)
}

@Test func projectTaskOrderUsesIDAsADeterministicTieBreaker() {
  let timestamp = Date(timeIntervalSince1970: 1_754_400_010)
  let laterID = TaskRecord(
    id: "thread-b",
    sessionID: "thread-b",
    projectID: "project",
    cwd: "/Users/demo/Project",
    title: "B",
    ownership: .hostedLive,
    displayStatus: .running,
    rawStatus: "active",
    updatedAt: timestamp
  )
  let earlierID = TaskRecord(
    id: "thread-a",
    sessionID: "thread-a",
    projectID: "project",
    cwd: "/Users/demo/Project",
    title: "A",
    ownership: .hostedLive,
    displayStatus: .running,
    rawStatus: "active",
    updatedAt: timestamp
  )
  let state = TaskBoardState(tasksByID: [laterID.id: laterID, earlierID.id: earlierID])

  #expect(state.projects.first?.tasks.map(\.id) == ["thread-a", "thread-b"])
}

@Test func staffIdentityIsStable() {
  #expect(StaffIdentity.name(for: "thr_abc") == StaffIdentity.name(for: "thr_abc"))
  #expect(StaffIdentity.shortID(for: "thr_123456789") == "456789")
}

@Test func projectIdentityNormalizesSymlinks() throws {
  let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let project = base.appendingPathComponent("Project")
  let alias = base.appendingPathComponent("Alias")
  try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
  try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: project)
  defer { try? FileManager.default.removeItem(at: base) }

  #expect(ProjectIdentity.normalizedPath(alias.path) == project.path)
  #expect(ProjectIdentity.isExistingDirectory(alias.path))
  #expect(!ProjectIdentity.isExistingDirectory(project.appendingPathComponent("missing").path))
  #expect(
    ProjectIdentity.cacheIdentifier(alias.path) == ProjectIdentity.cacheIdentifier(project.path))
}
