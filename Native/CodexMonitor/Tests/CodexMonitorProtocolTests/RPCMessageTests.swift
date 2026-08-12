import Foundation
import Testing

@testable import CodexMonitorProtocol

@Test func framesPartialJSONLines() throws {
  var framer = JSONLineFramer()
  #expect(framer.append(Data(#"{"id":1,"res"#.utf8)).isEmpty)
  let suffix = #"ult":{}}"# + "\n" + #"{"method":"ready","params":{}}"# + "\n"
  let lines = framer.append(Data(suffix.utf8))
  #expect(lines.count == 2)
  #expect(try RPCMessageCodec.decode(lines[0]) == .response(id: .integer(1), result: .object([:])))
  #expect(
    try RPCMessageCodec.decode(lines[1]) == .notification(method: "ready", params: .object([:])))
}

@Test func decodesServerRequestAndError() throws {
  let request = Data(
    #"{"id":"req-1","method":"item/fileChange/requestApproval","params":{"threadId":"t1"}}"#.utf8)
  #expect(
    try RPCMessageCodec.decode(request)
      == .request(
        id: .string("req-1"),
        method: "item/fileChange/requestApproval",
        params: ["threadId": "t1"]
      )
  )

  let failure = Data(#"{"id":7,"error":{"code":-32601,"message":"Unsupported"}}"#.utf8)
  #expect(
    try RPCMessageCodec.decode(failure)
      == .failure(
        id: .integer(7),
        error: RPCRemoteError(code: -32601, message: "Unsupported")
      )
  )
}

@Test func treatsNullIDMethodMessagesAsNotifications() throws {
  let message = Data(
    #"{"id":null,"method":"thread/status/changed","params":{"threadId":"t1"}}"#.utf8)
  #expect(
    try RPCMessageCodec.decode(message)
      == .notification(
        method: "thread/status/changed",
        params: ["threadId": "t1"]
      ))
}

@Test func outboundMethodsRemainClosed() {
  #expect(AllowedClientMethod.allCases.count == 10)
  #expect(!AllowedClientMethod.allCases.map(\.rawValue).contains("command/exec"))
  #expect(!AllowedClientMethod.allCases.map(\.rawValue).contains("config/value/write"))
  #expect(AllowedClientNotification.allCases == [.initialized])
}

@Test func jsonValueRoundTrips() throws {
  let value: JSONValue = [
    "name": "monitor",
    "count": 3,
    "enabled": true,
    "items": ["a", "b"],
  ]
  let encoded = try JSONEncoder().encode(value)
  #expect(try JSONDecoder().decode(JSONValue.self, from: encoded) == value)
}
