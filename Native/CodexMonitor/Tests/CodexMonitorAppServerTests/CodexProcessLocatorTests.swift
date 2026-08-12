import Foundation
import Testing

@testable import CodexMonitorAppServer

@Test func preferredExecutableIsFirstCandidate() {
  let candidates = CodexProcessLocator.candidateURLs(preferredPath: "/tmp/custom-codex")
  #expect(candidates.first?.path == "/tmp/custom-codex")
  #expect(
    candidates.contains(URL(fileURLWithPath: "/Applications/Codex.app/Contents/Resources/codex")))
}

@Test func hostErrorsAreActionable() {
  #expect(CodexHostError.executableNotFound.localizedDescription.contains("设置"))
  #expect(CodexHostError.staleApproval.localizedDescription.contains("旧连接"))
}

@Test func validatesOnlyKnownProtocolBaselines() {
  #expect(CodexVersionCompatibility.isValidated("codex-cli 0.142.2"))
  #expect(CodexVersionCompatibility.isValidated("codex-cli 0.144.1"))
  #expect(!CodexVersionCompatibility.isValidated("codex-cli 0.145.0"))
  #expect(!CodexVersionCompatibility.isValidated("development build"))
}

@Test func unansweredRequestsTimeOutAndCanBeStopped() async throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let executable = directory.appendingPathComponent("silent-codex")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  try Data("#!/bin/sh\nwhile IFS= read -r line; do :; done\n".utf8).write(to: executable)
  try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
  defer { try? FileManager.default.removeItem(at: directory) }

  let client = CodexAppServerClient()
  _ = try await client.start(executable: executable)
  do {
    _ = try await client.send(.modelList, timeout: .milliseconds(50))
    Issue.record("Expected the unanswered request to time out")
  } catch let error as CodexHostError {
    #expect(error == .requestTimedOut("model/list"))
  }
  await client.stop()
}

@Test func burstOutputPreservesJSONLMessageOrder() async throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let executable = directory.appendingPathComponent("burst-codex")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let script = """
    #!/bin/sh
    IFS= read -r line
    index=0
    while [ "$index" -lt 1500 ]; do
      printf '{"method":"test/event","params":{"index":%s}}\\n' "$index"
      index=$((index + 1))
    done
    printf '{"id":1,"result":{"data":[]}}\\n'
    while IFS= read -r line; do :; done
    """
  try Data(script.utf8).write(to: executable)
  try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
  defer { try? FileManager.default.removeItem(at: directory) }

  let client = CodexAppServerClient()
  _ = try await client.start(executable: executable)
  let result = try await client.send(.modelList, timeout: .seconds(8))
  #expect(result["data"]?.arrayValue == [])
  await client.stop()
}
