import Foundation
import Testing

@testable import CodexProbeCore

@Test func allowsOnlyTheDocumentedProbeRequests() throws {
  #expect(
    ReadOnlyRPCPolicy.allowedRequestMethods == [
      "initialize",
      "thread/list",
      "thread/read",
      "thread/loaded/list",
    ])

  for method in ReadOnlyRPCPolicy.allowedRequestMethods {
    let line = try ReadOnlyRPCPolicy.makeRequest(method: method, id: 1)
    #expect(line.last == 0x0A)
  }
}

@Test func blocksMutatingAndApprovalMethods() {
  let blocked = [
    "thread/start",
    "thread/delete",
    "thread/archive",
    "turn/start",
    "turn/interrupt",
    "fs/writeFile",
    "item/commandExecution/requestApproval",
  ]

  for method in blocked {
    #expect(throws: RPCPolicyError.requestNotAllowed(method)) {
      try ReadOnlyRPCPolicy.makeRequest(method: method, id: 1)
    }
  }
}

@Test func allowsOnlyInitializedNotification() throws {
  let line = try ReadOnlyRPCPolicy.makeNotification(method: "initialized")
  #expect(line.last == 0x0A)

  #expect(throws: RPCPolicyError.notificationNotAllowed("turn/interrupt")) {
    try ReadOnlyRPCPolicy.makeNotification(method: "turn/interrupt")
  }
}
