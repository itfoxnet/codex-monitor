import Foundation

public enum RPCID: Codable, Equatable, Hashable, Sendable, CustomStringConvertible {
  case integer(Int)
  case string(String)

  public init(any value: Any) throws {
    if let value = value as? String {
      self = .string(value)
    } else if let value = value as? NSNumber {
      self = .integer(value.intValue)
    } else {
      throw RPCMessageError.invalidID
    }
  }

  public init(jsonValue: JSONValue) throws {
    if let value = jsonValue.stringValue {
      self = .string(value)
    } else if let value = jsonValue.intValue {
      self = .integer(value)
    } else {
      throw RPCMessageError.invalidID
    }
  }

  public var description: String {
    switch self {
    case .integer(let value): String(value)
    case .string(let value): value
    }
  }

  public var anyValue: Any {
    switch self {
    case .integer(let value): value
    case .string(let value): value
    }
  }
}

public struct RPCRemoteError: Error, LocalizedError, Equatable, Sendable {
  public let code: Int
  public let message: String
  public let data: JSONValue?

  public init(code: Int, message: String, data: JSONValue? = nil) {
    self.code = code
    self.message = message
    self.data = data
  }

  public var errorDescription: String? { "App Server \(code): \(message)" }
}

public enum RPCInboundMessage: Equatable, Sendable {
  case response(id: RPCID, result: JSONValue)
  case failure(id: RPCID, error: RPCRemoteError)
  case request(id: RPCID, method: String, params: JSONValue)
  case notification(method: String, params: JSONValue)
}

public enum RPCMessageCodec {
  public static func decode(_ data: Data) throws -> RPCInboundMessage {
    let any = try JSONSerialization.jsonObject(with: data)
    guard let object = any as? [String: Any] else { throw RPCMessageError.notAnObject }

    if let method = object["method"] as? String {
      let params = try JSONValue(any: object["params"] ?? [:])
      if let id = object["id"], !(id is NSNull) {
        return .request(id: try RPCID(any: id), method: method, params: params)
      }
      return .notification(method: method, params: params)
    }

    guard let rawID = object["id"] else { throw RPCMessageError.missingID }
    let id = try RPCID(any: rawID)
    if let result = object["result"] {
      return .response(id: id, result: try JSONValue(any: result))
    }
    if let rawError = object["error"] as? [String: Any] {
      let code = (rawError["code"] as? NSNumber)?.intValue ?? -1
      let message = rawError["message"] as? String ?? "Unknown App Server error"
      let data = try rawError["data"].map(JSONValue.init(any:))
      return .failure(id: id, error: RPCRemoteError(code: code, message: message, data: data))
    }
    throw RPCMessageError.missingResult
  }

  public static func request(id: RPCID, method: String, params: JSONValue) throws -> Data {
    try encode(["id": id.anyValue, "method": method, "params": params.anyValue])
  }

  public static func notification(method: String, params: JSONValue = .object([:])) throws -> Data {
    try encode(["method": method, "params": params.anyValue])
  }

  public static func response(id: RPCID, result: JSONValue) throws -> Data {
    try encode(["id": id.anyValue, "result": result.anyValue])
  }

  public static func error(id: RPCID, code: Int, message: String) throws -> Data {
    try encode(["id": id.anyValue, "error": ["code": code, "message": message]])
  }

  private static func encode(_ object: [String: Any]) throws -> Data {
    var data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    data.append(0x0A)
    return data
  }
}

public enum RPCMessageError: Error, LocalizedError, Equatable {
  case notAnObject
  case invalidID
  case missingID
  case missingResult

  public var errorDescription: String? {
    switch self {
    case .notAnObject: "App Server message is not a JSON object"
    case .invalidID: "App Server message has an invalid request id"
    case .missingID: "App Server response has no request id"
    case .missingResult: "App Server response has neither result nor error"
    }
  }
}

public struct JSONLineFramer: Sendable {
  private var buffer = Data()

  public init() {}

  public mutating func append(_ data: Data) -> [Data] {
    buffer.append(data)
    var lines: [Data] = []
    while let newline = buffer.firstIndex(of: 0x0A) {
      let line = buffer[..<newline]
      buffer.removeSubrange(...newline)
      if !line.isEmpty { lines.append(Data(line)) }
    }
    return lines
  }

  public mutating func finish() -> Data? {
    guard !buffer.isEmpty else { return nil }
    defer { buffer.removeAll(keepingCapacity: false) }
    return buffer
  }
}

public enum AllowedClientMethod: String, CaseIterable, Sendable {
  case initialize
  case modelList = "model/list"
  case threadList = "thread/list"
  case threadRead = "thread/read"
  case threadLoadedList = "thread/loaded/list"
  case threadStart = "thread/start"
  case threadResume = "thread/resume"
  case threadUnsubscribe = "thread/unsubscribe"
  case turnStart = "turn/start"
  case turnInterrupt = "turn/interrupt"
}

public enum AllowedClientNotification: String, CaseIterable, Sendable {
  case initialized
}
