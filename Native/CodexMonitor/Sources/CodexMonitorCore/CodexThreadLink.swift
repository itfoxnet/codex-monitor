import Foundation

public enum CodexThreadLink {
  public static func url(threadID: String) -> URL? {
    guard let identifier = UUID(uuidString: threadID) else { return nil }
    var components = URLComponents()
    components.scheme = "codex"
    components.host = "threads"
    components.path = "/\(identifier.uuidString.lowercased())"
    return components.url
  }
}
