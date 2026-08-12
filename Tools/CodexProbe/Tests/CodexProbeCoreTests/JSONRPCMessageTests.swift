import Foundation
import Testing

@testable import CodexProbeCore

@Test func decodesAResponseAndBuildsASanitizedReport() throws {
  let fixtureURL = try #require(
    Bundle.module.url(
      forResource: "thread-list-response",
      withExtension: "json"
    ))
  let data = try Data(contentsOf: fixtureURL)
  let message = try JSONRPCMessage(line: data)
  let result = try message.requireResultObject()
  let threads = try #require(result["data"] as? [[String: Any]])

  let report = CodexProbeReport(
    command: "snapshot",
    transport: "stdio-child-process",
    cwdFilter: "/Users/example/Developer/codex-monitor",
    initializationResult: ["platformFamily": "unix", "platformOs": "macos"],
    threadObjects: threads,
    loadedThreadIDs: ["thr_running_123456789"]
  )

  #expect(report.threadCount == 2)
  #expect(report.loadedThreadCount == 1)
  #expect(report.transport == "stdio-child-process")
  #expect(report.cwdFilter == "codex-monitor")
  #expect(report.statusCounts == ["active": 1, "notLoaded": 1])
  #expect(report.threads.first?.activeFlags == ["waitingOnApproval"])
  #expect(report.threads.first?.project == "codex-monitor")
}

@Test func decodesAnAppServerError() throws {
  let data = Data(#"{"id":7,"error":{"code":-32601,"message":"Method not found"}}"#.utf8)
  let message = try JSONRPCMessage(line: data)
  #expect(message.error == RPCErrorPayload(code: -32601, message: "Method not found"))
}
