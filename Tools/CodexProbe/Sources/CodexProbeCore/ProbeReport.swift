import Foundation

public struct ProbeThreadSummary: Codable, Equatable {
  public let idPrefix: String
  public let project: String
  public let status: String
  public let activeFlags: [String]
  public let sourceKind: String
  public let loadedInProbeServer: Bool
  public let updatedAt: Int64?

  public init(
    idPrefix: String,
    project: String,
    status: String,
    activeFlags: [String],
    sourceKind: String,
    loadedInProbeServer: Bool,
    updatedAt: Int64?
  ) {
    self.idPrefix = idPrefix
    self.project = project
    self.status = status
    self.activeFlags = activeFlags
    self.sourceKind = sourceKind
    self.loadedInProbeServer = loadedInProbeServer
    self.updatedAt = updatedAt
  }
}

public struct CodexProbeReport: Codable, Equatable {
  public let probeVersion: String
  public let command: String
  public let transport: String
  public let readOnly: Bool
  public let stateDatabaseOnly: Bool
  public let cwdFilter: String?
  public let platformFamily: String?
  public let platformOS: String?
  public let threadCount: Int
  public let loadedThreadCount: Int
  public let statusCounts: [String: Int]
  public let sourceCounts: [String: Int]
  public let threads: [ProbeThreadSummary]

  public init(
    command: String,
    transport: String,
    cwdFilter: String?,
    initializationResult: [String: Any],
    threadObjects: [[String: Any]],
    loadedThreadIDs: Set<String>
  ) {
    probeVersion = "0.1.0"
    self.command = command
    self.transport = transport
    readOnly = true
    stateDatabaseOnly = true
    self.cwdFilter = cwdFilter.map(Self.redactedProjectName)
    platformFamily = initializationResult["platformFamily"] as? String
    platformOS = initializationResult["platformOs"] as? String

    threads = threadObjects.map { thread in
      let id = thread["id"] as? String ?? "unknown"
      let statusObject = thread["status"] as? [String: Any]
      let status = statusObject?["type"] as? String ?? "unknown"
      let flags = statusObject?["activeFlags"] as? [String] ?? []
      let cwd = thread["cwd"] as? String
      let updatedAt = (thread["updatedAt"] as? NSNumber)?.int64Value

      return ProbeThreadSummary(
        idPrefix: String(id.prefix(12)),
        project: cwd.map(Self.redactedProjectName) ?? "unknown",
        status: status,
        activeFlags: flags.sorted(),
        sourceKind: Self.sourceKind(from: thread),
        loadedInProbeServer: loadedThreadIDs.contains(id),
        updatedAt: updatedAt
      )
    }
    .sorted {
      if $0.updatedAt == $1.updatedAt {
        return $0.idPrefix < $1.idPrefix
      }
      return ($0.updatedAt ?? 0) > ($1.updatedAt ?? 0)
    }

    threadCount = threads.count
    loadedThreadCount = loadedThreadIDs.count
    statusCounts = Dictionary(grouping: threads, by: \.status).mapValues(\.count)
    sourceCounts = Dictionary(grouping: threads, by: \.sourceKind).mapValues(\.count)
  }

  private static func redactedProjectName(_ path: String) -> String {
    let name = URL(fileURLWithPath: path).lastPathComponent
    return name.isEmpty ? "root" : name
  }

  private static func sourceKind(from thread: [String: Any]) -> String {
    if let sourceKind = thread["sourceKind"] as? String {
      return sourceKind
    }
    if let source = thread["source"] as? String {
      return source
    }
    if let source = thread["source"] as? [String: Any] {
      if source["custom"] != nil { return "custom" }
      if source["internal"] != nil { return "internal" }
      if source["subAgent"] != nil || source["subagent"] != nil { return "subAgent" }
      return source["kind"] as? String ?? source["type"] as? String ?? "unknown"
    }
    return "unknown"
  }
}
