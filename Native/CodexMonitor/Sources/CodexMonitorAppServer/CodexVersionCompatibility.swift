import Foundation

public enum CodexVersionCompatibility {
  /// Protocol baselines exercised against the checked-in schemas and local integration tests.
  /// Unknown versions remain useful for read-only history, but cannot create turns or answer approvals.
  public static func isValidated(_ versionDescription: String) -> Bool {
    guard let version = semanticVersion(in: versionDescription) else { return false }
    return version.major == 0 && (142...144).contains(version.minor)
  }

  private static func semanticVersion(in value: String) -> (major: Int, minor: Int, patch: Int)? {
    guard let expression = try? NSRegularExpression(pattern: #"(\d+)\.(\d+)\.(\d+)"#),
      let match = expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
      match.numberOfRanges == 4,
      let majorRange = Range(match.range(at: 1), in: value),
      let minorRange = Range(match.range(at: 2), in: value),
      let patchRange = Range(match.range(at: 3), in: value),
      let major = Int(value[majorRange]),
      let minor = Int(value[minorRange]),
      let patch = Int(value[patchRange])
    else { return nil }
    return (major, minor, patch)
  }
}
