import CodexProbeCore
import Darwin
import Foundation

private struct CLIOptions {
  enum Command {
    case snapshot
    case read(String)
  }

  var command: Command = .snapshot
  var codexExecutable: String?
  var transport: AppServerTransport = .child
  var socketPath: String?
  var cwd: String?
  var limit = 100
  var timeoutSeconds = 10
  var holdSeconds = 0

  static func parse(_ arguments: [String]) throws -> CLIOptions {
    var options = CLIOptions()
    var index = 0

    if arguments.first == "read" {
      guard arguments.count >= 2 else { throw CLIError.missingThreadID }
      options.command = .read(arguments[1])
      index = 2
    } else if arguments.first == "snapshot" {
      index = 1
    }

    while index < arguments.count {
      let argument = arguments[index]
      switch argument {
      case "--codex":
        index += 1
        guard index < arguments.count else { throw CLIError.missingValue(argument) }
        options.codexExecutable = arguments[index]
      case "--cwd":
        index += 1
        guard index < arguments.count else { throw CLIError.missingValue(argument) }
        options.cwd = URL(fileURLWithPath: arguments[index]).standardizedFileURL.path
      case "--transport":
        index += 1
        guard index < arguments.count,
          let value = AppServerTransport(rawValue: arguments[index])
        else {
          throw CLIError.invalidTransport
        }
        options.transport = value
      case "--socket":
        index += 1
        guard index < arguments.count else { throw CLIError.missingValue(argument) }
        options.socketPath = URL(fileURLWithPath: arguments[index]).standardizedFileURL.path
      case "--limit":
        index += 1
        guard index < arguments.count, let value = Int(arguments[index]) else {
          throw CLIError.invalidInteger(argument)
        }
        options.limit = value
      case "--timeout":
        index += 1
        guard index < arguments.count, let value = Int(arguments[index]) else {
          throw CLIError.invalidInteger(argument)
        }
        options.timeoutSeconds = value
      case "--hold":
        index += 1
        guard index < arguments.count, let value = Int(arguments[index]), value >= 0 else {
          throw CLIError.invalidInteger(argument)
        }
        options.holdSeconds = min(value, 30)
      case "--help", "-h":
        printUsage()
        exit(0)
      default:
        throw CLIError.unknownArgument(argument)
      }
      index += 1
    }

    if options.socketPath != nil, options.transport != .proxy {
      throw CLIError.socketRequiresProxy
    }

    return options
  }

  static func printUsage() {
    print(
      """
      codex-probe snapshot [--transport stdio-child-process|daemon-proxy]
        [--socket PATH] [--codex PATH] [--cwd PATH] [--limit N]
        [--timeout SECONDS] [--hold SECONDS]
      codex-probe read THREAD_ID [--transport stdio-child-process|daemon-proxy]
        [--codex PATH] [--timeout SECONDS]

      The probe starts its own temporary stdio App Server and can only send:
      initialize, thread/list, thread/read, and thread/loaded/list.
      Output is sanitized and excludes titles, prompts, commands, and full paths.
      """)
  }
}

private enum CLIError: Error, LocalizedError {
  case missingThreadID
  case missingValue(String)
  case invalidInteger(String)
  case invalidTransport
  case socketRequiresProxy
  case unknownArgument(String)

  var errorDescription: String? {
    switch self {
    case .missingThreadID:
      return "The read command requires a thread id"
    case .missingValue(let argument):
      return "Missing value for \(argument)"
    case .invalidInteger(let argument):
      return "Expected an integer after \(argument)"
    case .invalidTransport:
      return "Transport must be stdio-child-process or daemon-proxy"
    case .socketRequiresProxy:
      return "--socket can only be used with --transport daemon-proxy"
    case .unknownArgument(let argument):
      return "Unknown argument: \(argument)"
    }
  }
}

do {
  let options = try CLIOptions.parse(Array(CommandLine.arguments.dropFirst()))
  let server = AppServerProcess(
    codexExecutable: options.codexExecutable,
    transport: options.transport,
    socketPath: options.socketPath,
    timeoutSeconds: options.timeoutSeconds
  )
  try server.start()
  defer { server.stop() }

  let initialization = try server.initialize()
  if options.holdSeconds > 0 {
    Thread.sleep(forTimeInterval: TimeInterval(options.holdSeconds))
  }
  let loaded = try server.loadedThreadIDs()
  let threads: [[String: Any]]
  let commandName: String

  switch options.command {
  case .snapshot:
    threads = try server.listThreads(cwd: options.cwd, limit: options.limit)
    commandName = "snapshot"
  case .read(let threadID):
    threads = [try server.readThread(id: threadID)]
    commandName = "read"
  }

  let report = CodexProbeReport(
    command: commandName,
    transport: options.transport.rawValue,
    cwdFilter: options.cwd,
    initializationResult: initialization,
    threadObjects: threads,
    loadedThreadIDs: loaded
  )
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
  let output = try encoder.encode(report)
  FileHandle.standardOutput.write(output)
  FileHandle.standardOutput.write(Data([0x0A]))
} catch {
  FileHandle.standardError.write(Data("codex-probe: \(error.localizedDescription)\n".utf8))
  exit(1)
}
