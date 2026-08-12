import Foundation

public enum JSONValue: Codable, Equatable, Hashable, Sendable {
  case object([String: JSONValue])
  case array([JSONValue])
  case string(String)
  case number(Double)
  case bool(Bool)
  case null

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else if let value = try? container.decode([String: JSONValue].self) {
      self = .object(value)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Unsupported JSON value")
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .object(let value): try container.encode(value)
    case .array(let value): try container.encode(value)
    case .string(let value): try container.encode(value)
    case .number(let value): try container.encode(value)
    case .bool(let value): try container.encode(value)
    case .null: try container.encodeNil()
    }
  }

  public init(any value: Any) throws {
    switch value {
    case let value as [String: Any]:
      self = .object(try value.mapValues(JSONValue.init(any:)))
    case let value as [Any]:
      self = .array(try value.map(JSONValue.init(any:)))
    case let value as String:
      self = .string(value)
    case let value as NSNumber:
      if CFGetTypeID(value) == CFBooleanGetTypeID() {
        self = .bool(value.boolValue)
      } else {
        self = .number(value.doubleValue)
      }
    case _ as NSNull:
      self = .null
    default:
      throw JSONValueError.unsupportedType(String(describing: type(of: value)))
    }
  }

  public var anyValue: Any {
    switch self {
    case .object(let value): return value.mapValues(\.anyValue)
    case .array(let value): return value.map(\.anyValue)
    case .string(let value): return value
    case .number(let value):
      if value.rounded(.towardZero) == value { return NSNumber(value: Int64(value)) }
      return NSNumber(value: value)
    case .bool(let value): return value
    case .null: return NSNull()
    }
  }

  public subscript(key: String) -> JSONValue? {
    guard case .object(let value) = self else { return nil }
    return value[key]
  }

  public var objectValue: [String: JSONValue]? {
    guard case .object(let value) = self else { return nil }
    return value
  }

  public var arrayValue: [JSONValue]? {
    guard case .array(let value) = self else { return nil }
    return value
  }

  public var stringValue: String? {
    guard case .string(let value) = self else { return nil }
    return value
  }

  public var boolValue: Bool? {
    guard case .bool(let value) = self else { return nil }
    return value
  }

  public var intValue: Int? {
    guard case .number(let value) = self else { return nil }
    return Int(exactly: value)
  }

  public var doubleValue: Double? {
    guard case .number(let value) = self else { return nil }
    return value
  }

  public func rendered(maxLength: Int = 240) -> String {
    let raw: String
    if JSONSerialization.isValidJSONObject(anyValue),
      let data = try? JSONSerialization.data(withJSONObject: anyValue, options: [.sortedKeys]),
      let text = String(data: data, encoding: .utf8)
    {
      raw = text
    } else {
      raw = String(describing: anyValue)
    }
    guard raw.count > maxLength else { return raw }
    return String(raw.prefix(maxLength)) + "…"
  }
}

public enum JSONValueError: Error, LocalizedError, Equatable {
  case unsupportedType(String)

  public var errorDescription: String? {
    switch self {
    case .unsupportedType(let type): "Unsupported JSON type: \(type)"
    }
  }
}

extension JSONValue: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) { self = .string(value) }
}

extension JSONValue: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension JSONValue: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int) { self = .number(Double(value)) }
}

extension JSONValue: ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) { self = .number(value) }
}

extension JSONValue: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (String, JSONValue)...) {
    self = .object(Dictionary(uniqueKeysWithValues: elements))
  }
}
