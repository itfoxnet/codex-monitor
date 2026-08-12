import Foundation

public enum JSONRPCDecodeError: Error, Equatable, LocalizedError {
  case notAnObject
  case missingResult

  public var errorDescription: String? {
    switch self {
    case .notAnObject:
      return "App Server message is not a JSON object"
    case .missingResult:
      return "App Server response did not contain a result"
    }
  }
}

public struct RPCErrorPayload: Error, Equatable, LocalizedError {
  public let code: Int
  public let message: String

  public init(code: Int, message: String) {
    self.code = code
    self.message = message
  }

  public var errorDescription: String? {
    "App Server error \(code): \(message)"
  }
}

public struct JSONRPCMessage {
  public let id: Int?
  public let method: String?
  public let result: Any?
  public let error: RPCErrorPayload?
  public let raw: [String: Any]

  public init(line: Data) throws {
    let value = try JSONSerialization.jsonObject(with: line)
    guard let object = value as? [String: Any] else {
      throw JSONRPCDecodeError.notAnObject
    }

    raw = object
    if let number = object["id"] as? NSNumber {
      id = number.intValue
    } else {
      id = nil
    }
    method = object["method"] as? String
    result = object["result"]

    if let payload = object["error"] as? [String: Any] {
      let code = (payload["code"] as? NSNumber)?.intValue ?? -1
      let message = payload["message"] as? String ?? "Unknown App Server error"
      error = RPCErrorPayload(code: code, message: message)
    } else {
      error = nil
    }
  }

  public func requireResultObject() throws -> [String: Any] {
    if let error {
      throw error
    }
    guard let object = result as? [String: Any] else {
      throw JSONRPCDecodeError.missingResult
    }
    return object
  }
}
