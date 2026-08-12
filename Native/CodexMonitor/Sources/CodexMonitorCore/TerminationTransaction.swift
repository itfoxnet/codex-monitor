public struct TerminationTransaction: Equatable, Sendable {
  public enum State: Equatable, Sendable {
    case idle
    case stopping
  }

  public private(set) var state: State = .idle

  public init() {}

  /// Returns true only for the request that owns the shutdown transaction.
  public mutating func begin() -> Bool {
    guard state == .idle else { return false }
    state = .stopping
    return true
  }

  public mutating func finish() {
    state = .idle
  }
}
