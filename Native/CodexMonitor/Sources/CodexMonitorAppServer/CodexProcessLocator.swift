import Foundation

public struct CodexExecutable: Equatable, Sendable {
  public let url: URL
  public let version: String

  public init(url: URL, version: String) {
    self.url = url
    self.version = version
  }
}

public enum CodexProcessLocator {
  public static func locate(preferredPath: String? = nil) throws -> CodexExecutable {
    let candidates = candidateURLs(preferredPath: preferredPath)
    guard
      let executable = candidates.first(where: {
        FileManager.default.isExecutableFile(atPath: $0.path)
      })
    else {
      throw CodexHostError.executableNotFound
    }
    return CodexExecutable(url: executable, version: try readVersion(at: executable))
  }

  public static func candidateURLs(preferredPath: String?) -> [URL] {
    var candidates: [URL] = []
    if let preferredPath, !preferredPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      candidates.append(URL(fileURLWithPath: preferredPath))
    }

    candidates.append(URL(fileURLWithPath: "/Applications/Codex.app/Contents/Resources/codex"))
    candidates.append(URL(fileURLWithPath: "/opt/homebrew/bin/codex"))
    candidates.append(URL(fileURLWithPath: "/usr/local/bin/codex"))

    let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
    for directory in path.split(separator: ":") {
      candidates.append(URL(fileURLWithPath: String(directory)).appendingPathComponent("codex"))
    }

    var seen = Set<String>()
    return candidates.filter { seen.insert($0.standardizedFileURL.path).inserted }
  }

  private static func readVersion(at executable: URL) throws -> String {
    let process = Process()
    let output = Pipe()
    process.executableURL = executable
    process.arguments = ["--version"]
    process.standardOutput = output
    process.standardError = output
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw CodexHostError.versionCheckFailed
    }
    let data = output.fileHandleForReading.readDataToEndOfFile()
    let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { throw CodexHostError.versionCheckFailed }
    return text
  }
}

public enum CodexHostError: Error, LocalizedError, Equatable, Sendable {
  case executableNotFound
  case versionCheckFailed
  case alreadyRunning
  case notRunning
  case transportClosed
  case requestTimedOut(String)
  case invalidResponse(String)
  case invalidProjectDirectory
  case staleApproval

  public var errorDescription: String? {
    switch self {
    case .executableNotFound: "没有找到 Codex。请在设置中选择 Codex 可执行文件。"
    case .versionCheckFailed: "无法读取 Codex 版本。"
    case .alreadyRunning: "Codex App Server 已经在运行。"
    case .notRunning: "Codex App Server 尚未连接。"
    case .transportClosed: "Codex App Server 连接已关闭。"
    case .requestTimedOut(let method): "Codex App Server 请求超时：\(method)"
    case .invalidResponse(let field): "Codex App Server 响应缺少字段：\(field)"
    case .invalidProjectDirectory: "项目目录不存在或不是文件夹。"
    case .staleApproval: "这项授权来自旧连接，已经不能处理。"
    }
  }
}
