import Foundation

public enum RPCPolicyError: Error, Equatable, LocalizedError {
  case requestNotAllowed(String)
  case notificationNotAllowed(String)
  case invalidJSONObject

  public var errorDescription: String? {
    switch self {
    case .requestNotAllowed(let method):
      return "RPC request is not allowed in the read-only probe: \(method)"
    case .notificationNotAllowed(let method):
      return "RPC notification is not allowed in the read-only probe: \(method)"
    case .invalidJSONObject:
      return "RPC payload is not a valid JSON object"
    }
  }
}

public enum ReadOnlyRPCPolicy {
  public static let allowedRequestMethods: Set<String> = [
    "initialize",
    "thread/list",
    "thread/read",
    "thread/loaded/list",
  ]

  public static let allowedNotificationMethods: Set<String> = [
    "initialized"
  ]

  public static func makeRequest(
    method: String,
    id: Int,
    params: [String: Any] = [:]
  ) throws -> Data {
    guard allowedRequestMethods.contains(method) else {
      throw RPCPolicyError.requestNotAllowed(method)
    }

    return try encodeLine([
      "method": method,
      "id": id,
      "params": params,
    ])
  }

  public static func makeNotification(
    method: String,
    params: [String: Any] = [:]
  ) throws -> Data {
    guard allowedNotificationMethods.contains(method) else {
      throw RPCPolicyError.notificationNotAllowed(method)
    }

    return try encodeLine([
      "method": method,
      "params": params,
    ])
  }

  private static func encodeLine(_ object: [String: Any]) throws -> Data {
    guard JSONSerialization.isValidJSONObject(object) else {
      throw RPCPolicyError.invalidJSONObject
    }

    var data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    data.append(0x0A)
    return data
  }
}
