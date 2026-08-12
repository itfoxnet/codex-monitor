import Foundation

public enum ProjectIdentity {
  public static func normalizedPath(_ path: String) -> String {
    let expanded = NSString(string: path).expandingTildeInPath
    let url = URL(fileURLWithPath: expanded).standardizedFileURL
    if FileManager.default.fileExists(atPath: url.path) {
      return url.resolvingSymlinksInPath().standardizedFileURL.path
    }
    return url.path
  }

  public static func isExistingDirectory(_ path: String) -> Bool {
    var isDirectory: ObjCBool = false
    return FileManager.default.fileExists(atPath: normalizedPath(path), isDirectory: &isDirectory)
      && isDirectory.boolValue
  }

  public static func cacheIdentifier(_ path: String) -> String {
    let hash = normalizedPath(path).utf8.reduce(UInt64(14_695_981_039_346_656_037)) {
      value, byte in
      (value ^ UInt64(byte)) &* 1_099_511_628_211
    }
    return String(hash, radix: 16)
  }
}
