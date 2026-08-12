import Foundation
import Testing

@testable import CodexMonitorAppServer

@Test func realAppServerHandshakeAndReadOnlyList() async throws {
  guard ProcessInfo.processInfo.environment["CODEX_MONITOR_INTEGRATION_TEST"] == "1" else { return }

  let executable = try CodexProcessLocator.locate()
  let client = CodexAppServerClient()
  let api = AppServerAPI(client: client)

  do {
    _ = try await client.start(executable: executable.url)
    _ = try await api.initialize(version: "integration-test")
    let threads = try await api.listThreads(limit: 10)
    _ = try await api.listModels()
    #expect(threads.count <= 10)
    await client.stop()
  } catch {
    await client.stop()
    throw error
  }
}

@Test func threadListFollowsCursorUntilRequestedLimit() async throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let executable = directory.appendingPathComponent("paged-codex")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let script = """
    #!/bin/sh
    IFS= read -r first
    printf '{"id":1,"result":{"data":[{"id":"thread-1"}],"nextCursor":"page-2"}}\\n'
    IFS= read -r second
    printf '{"id":2,"result":{"data":[{"id":"thread-2"}],"nextCursor":null}}\\n'
    while IFS= read -r line; do :; done
    """
  try Data(script.utf8).write(to: executable)
  try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
  defer { try? FileManager.default.removeItem(at: directory) }

  let client = CodexAppServerClient()
  let api = AppServerAPI(client: client)
  _ = try await client.start(executable: executable)
  let threads = try await api.listThreads(limit: 2)
  #expect(threads.compactMap { $0["id"]?.stringValue } == ["thread-1", "thread-2"])
  await client.stop()
}

@Test func recentThreadListReadsOnlyTheNewestPage() async throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let executable = directory.appendingPathComponent("recent-codex")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let script = """
    #!/bin/sh
    IFS= read -r first
    printf '{"id":1,"result":{"data":[{"id":"recent-thread"}],"nextCursor":"older-page"}}\\n'
    IFS= read -r second
    printf '{"id":2,"result":{"data":[{"id":"older-thread"}],"nextCursor":null}}\\n'
    while IFS= read -r line; do :; done
    """
  try Data(script.utf8).write(to: executable)
  try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
  defer { try? FileManager.default.removeItem(at: directory) }

  let client = CodexAppServerClient()
  let api = AppServerAPI(client: client)
  _ = try await client.start(executable: executable)
  let threads = try await api.listRecentThreads(limit: 100)

  #expect(threads.compactMap { $0["id"]?.stringValue } == ["recent-thread"])
  await client.stop()
}

@Test func fullThreadListCanReachTheTwoHundredFirstThread() async throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let executable = directory.appendingPathComponent("large-paged-codex")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

  func response(ids: ClosedRange<Int>, nextCursor: String?) throws -> String {
    let data = ids.map { ["id": "thread-\($0)"] }
    var result: [String: Any] = ["data": data]
    result["nextCursor"] = nextCursor ?? NSNull()
    let requestID = ids.lowerBound == 1 ? 1 : ids.lowerBound == 101 ? 2 : 3
    let envelope: [String: Any] = ["id": requestID, "result": result]
    let encoded = try JSONSerialization.data(
      withJSONObject: envelope,
      options: [.sortedKeys]
    )
    return String(decoding: encoded, as: UTF8.self)
  }

  let firstPage = try response(ids: 1...100, nextCursor: "page-2")
  let secondPage = try response(ids: 101...200, nextCursor: "page-3")
  let thirdPage = try response(ids: 201...201, nextCursor: nil)
  let script = """
    #!/bin/sh
    IFS= read -r first
    printf '%s\\n' '\(firstPage)'
    IFS= read -r second
    printf '%s\\n' '\(secondPage)'
    IFS= read -r third
    printf '%s\\n' '\(thirdPage)'
    while IFS= read -r line; do :; done
    """
  try Data(script.utf8).write(to: executable)
  try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
  defer { try? FileManager.default.removeItem(at: directory) }

  let client = CodexAppServerClient()
  let api = AppServerAPI(client: client)
  _ = try await client.start(executable: executable)
  let threads = try await api.listThreads(limit: 201)
  let ids = threads.compactMap { $0["id"]?.stringValue }

  #expect(ids.count == 201)
  #expect(ids.first == "thread-1")
  #expect(ids.last == "thread-201")
  await client.stop()
}

@Test func defaultFullThreadListContinuesUntilTheLastPage() async throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let executable = directory.appendingPathComponent("default-full-list-codex")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let script = """
    #!/bin/sh
    IFS= read -r first
    printf '{"id":1,"result":{"data":[{"id":"thread-1"}],"nextCursor":"page-2"}}\\n'
    IFS= read -r second
    printf '{"id":2,"result":{"data":[{"id":"thread-2"}],"nextCursor":null}}\\n'
    while IFS= read -r line; do :; done
    """
  try Data(script.utf8).write(to: executable)
  try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
  defer { try? FileManager.default.removeItem(at: directory) }

  let client = CodexAppServerClient()
  let api = AppServerAPI(client: client)
  _ = try await client.start(executable: executable)
  let threads = try await api.listThreads()

  #expect(threads.compactMap { $0["id"]?.stringValue } == ["thread-1", "thread-2"])
  await client.stop()
}
