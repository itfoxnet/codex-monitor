import Foundation

public enum ExternalSessionLifecycle: String, Equatable, Sendable {
  case active
  case completed
  case failed
  case interrupted
  case unknown
}

public struct ExternalSessionSnapshot: Equatable, Sendable {
  public let lifecycle: ExternalSessionLifecycle
  public let updatedAt: Date

  public init(lifecycle: ExternalSessionLifecycle, updatedAt: Date) {
    self.lifecycle = lifecycle
    self.updatedAt = updatedAt
  }
}

/// Observes only lifecycle envelopes in local Codex rollout logs. Message text, tool input,
/// command output, and diffs are never retained or returned.
public actor ExternalSessionObserver {
  private struct Entry {
    let url: URL
    var completeOffset: UInt64
    var fileSize: UInt64
    var modifiedAt: Date
    var lifecycle: ExternalSessionLifecycle
    var emittedLifecycle: ExternalSessionLifecycle?
    var emittedFreshness: Bool?
  }

  private let sessionsRoot: URL
  private let maximumRelevantAge: TimeInterval
  private let activeFreshness: TimeInterval
  private let maximumInitialScanBytes: UInt64
  private var urlsByThreadID: [String: URL] = [:]
  private var entriesByThreadID: [String: Entry] = [:]
  private var missingThreadIDs: [String: Date] = [:]
  private var indexedAt = Date.distantPast

  public init(
    sessionsRoot: URL? = nil,
    maximumRelevantAge: TimeInterval = 2 * 60 * 60,
    activeFreshness: TimeInterval = 10 * 60,
    maximumInitialScanBytes: UInt64 = 4 * 1_024 * 1_024
  ) {
    self.sessionsRoot =
      sessionsRoot
      ?? FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".codex/sessions", isDirectory: true)
    self.maximumRelevantAge = maximumRelevantAge
    self.activeFreshness = activeFreshness
    self.maximumInitialScanBytes = maximumInitialScanBytes
  }

  public func poll(threadIDs: Set<String>) -> [String: ExternalSessionSnapshot] {
    guard !threadIDs.isEmpty else { return [:] }
    let now = Date.now
    let hasUnindexedCandidate = threadIDs.contains { threadID in
      guard urlsByThreadID[threadID] == nil else { return false }
      guard let checkedAt = missingThreadIDs[threadID] else { return true }
      return now.timeIntervalSince(checkedAt) > 60
    }
    if now.timeIntervalSince(indexedAt) > 60 || hasUnindexedCandidate {
      rebuildIndex()
      for threadID in threadIDs where urlsByThreadID[threadID] == nil {
        missingThreadIDs[threadID] = now
      }
    }

    var result: [String: ExternalSessionSnapshot] = [:]
    for threadID in threadIDs {
      guard let url = urlsByThreadID[threadID],
        let metadata = Self.metadata(for: url)
      else { continue }

      var entry: Entry
      if let existing = entriesByThreadID[threadID], existing.url == url,
        metadata.size >= existing.completeOffset
      {
        entry = existing
        if metadata.size != existing.fileSize || metadata.modifiedAt != existing.modifiedAt {
          let update = Self.lifecycleUpdate(in: url, from: existing.completeOffset)
          entry.completeOffset = update.completeOffset
          entry.fileSize = metadata.size
          entry.modifiedAt = metadata.modifiedAt
          if let lifecycle = update.lifecycle { entry.lifecycle = lifecycle }
        }
      } else {
        let initial =
          Date.now.timeIntervalSince(metadata.modifiedAt) <= maximumRelevantAge
          ? Self.latestLifecycle(in: url, maximumBytes: maximumInitialScanBytes)
          : (lifecycle: nil, completeOffset: metadata.size)
        entry = Entry(
          url: url,
          completeOffset: initial.completeOffset,
          fileSize: metadata.size,
          modifiedAt: metadata.modifiedAt,
          lifecycle: initial.lifecycle ?? .unknown,
          emittedLifecycle: nil,
          emittedFreshness: nil
        )
      }
      let freshness = observationIsFresh(entry, now: .now)
      if entry.emittedLifecycle != entry.lifecycle || entry.emittedFreshness != freshness {
        result[threadID] = ExternalSessionSnapshot(
          lifecycle: entry.lifecycle,
          updatedAt: entry.modifiedAt
        )
        entry.emittedLifecycle = entry.lifecycle
        entry.emittedFreshness = freshness
      }
      entriesByThreadID[threadID] = entry
    }

    entriesByThreadID = entriesByThreadID.filter { threadIDs.contains($0.key) }
    missingThreadIDs = missingThreadIDs.filter { threadIDs.contains($0.key) }
    return result
  }

  private func observationIsFresh(_ entry: Entry, now: Date) -> Bool {
    let age = max(0, now.timeIntervalSince(entry.modifiedAt))
    switch entry.lifecycle {
    case .active, .interrupted:
      return age <= activeFreshness
    case .failed:
      return age <= maximumRelevantAge
    case .completed, .unknown:
      return false
    }
  }

  private func rebuildIndex() {
    indexedAt = .now
    guard
      let enumerator = FileManager.default.enumerator(
        at: sessionsRoot,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
      )
    else {
      urlsByThreadID = [:]
      return
    }

    var index: [String: URL] = [:]
    for case let url as URL in enumerator where url.pathExtension == "jsonl" {
      let stem = url.deletingPathExtension().lastPathComponent
      guard stem.count >= 36 else { continue }
      let threadID = String(stem.suffix(36))
      guard UUID(uuidString: threadID) != nil else { continue }
      index[threadID] = url
    }
    urlsByThreadID = index
    missingThreadIDs = missingThreadIDs.filter { index[$0.key] == nil }
  }

  private static func metadata(for url: URL) -> (size: UInt64, modifiedAt: Date)? {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
      let size = (attributes[.size] as? NSNumber)?.uint64Value,
      let modifiedAt = attributes[.modificationDate] as? Date
    else { return nil }
    return (size, modifiedAt)
  }

  private static func latestLifecycle(in url: URL, maximumBytes: UInt64) -> (
    lifecycle: ExternalSessionLifecycle?, completeOffset: UInt64
  ) {
    guard let handle = try? FileHandle(forReadingFrom: url) else {
      return (nil, 0)
    }
    defer { try? handle.close() }
    guard let fileSize = try? handle.seekToEnd() else { return (nil, 0) }
    let startOffset = fileSize > maximumBytes ? fileSize - maximumBytes : 0
    do {
      try handle.seek(toOffset: startOffset)
    } catch {
      return (nil, 0)
    }
    guard let data = try? handle.readToEnd(), !data.isEmpty else {
      return (nil, fileSize)
    }
    let lastCompleteIndex = data.lastIndex(of: 0x0A).map { $0 + 1 } ?? 0
    let completeOffset = startOffset + UInt64(lastCompleteIndex)
    var end = lastCompleteIndex
    while end > 0 {
      while end > 0 && (data[end - 1] == 0x0A || data[end - 1] == 0x0D) { end -= 1 }
      guard end > 0 else { break }
      var start = end
      while start > 0 && data[start - 1] != 0x0A { start -= 1 }
      if start == 0 && startOffset > 0 { break }
      if let lifecycle = lifecycle(from: data.subdata(in: start..<end)) {
        return (lifecycle, completeOffset)
      }
      end = start
    }
    return (nil, completeOffset)
  }

  private static func lifecycleUpdate(in url: URL, from offset: UInt64) -> (
    lifecycle: ExternalSessionLifecycle?, completeOffset: UInt64
  ) {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return (nil, offset) }
    defer { try? handle.close() }
    do {
      try handle.seek(toOffset: offset)
      guard let data = try handle.readToEnd(), !data.isEmpty,
        let lastNewline = data.lastIndex(of: 0x0A)
      else { return (nil, offset) }
      let completeData = data.prefix(through: lastNewline)
      var latest: ExternalSessionLifecycle?
      for line in completeData.split(separator: 0x0A, omittingEmptySubsequences: true) {
        if let lifecycle = lifecycle(from: Data(line)) { latest = lifecycle }
      }
      return (latest, offset + UInt64(completeData.count))
    } catch {
      return (nil, offset)
    }
  }

  private static func lifecycle(from line: Data) -> ExternalSessionLifecycle? {
    guard line.range(of: Data("\"type\":\"event_msg\"".utf8)) != nil,
      line.range(of: Data("task_started".utf8)) != nil
        || line.range(of: Data("task_complete".utf8)) != nil
        || line.range(of: Data("turn_aborted".utf8)) != nil
    else { return nil }
    guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
      object["type"] as? String == "event_msg",
      let payload = object["payload"] as? [String: Any],
      let type = payload["type"] as? String
    else { return nil }

    switch type {
    case "task_started":
      return .active
    case "task_complete":
      let error = payload["error"]
      return error != nil && !(error is NSNull) ? .failed : .completed
    case "turn_aborted":
      return .interrupted
    default:
      return nil
    }
  }
}
