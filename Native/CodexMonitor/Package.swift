// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "CodexMonitor",
  defaultLocalization: "zh-Hans",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "CodexMonitor", targets: ["CodexMonitor"]),
    .library(name: "CodexMonitorProtocol", targets: ["CodexMonitorProtocol"]),
    .library(name: "CodexMonitorCore", targets: ["CodexMonitorCore"]),
    .library(name: "CodexMonitorAppServer", targets: ["CodexMonitorAppServer"]),
  ],
  targets: [
    .target(name: "CodexMonitorProtocol"),
    .target(
      name: "CodexMonitorCore",
      dependencies: ["CodexMonitorProtocol"]
    ),
    .target(
      name: "CodexMonitorAppServer",
      dependencies: ["CodexMonitorProtocol", "CodexMonitorCore"]
    ),
    .executableTarget(
      name: "CodexMonitor",
      dependencies: ["CodexMonitorProtocol", "CodexMonitorCore", "CodexMonitorAppServer"]
    ),
    .testTarget(
      name: "CodexMonitorProtocolTests",
      dependencies: ["CodexMonitorProtocol"]
    ),
    .testTarget(
      name: "CodexMonitorCoreTests",
      dependencies: ["CodexMonitorCore", "CodexMonitorProtocol"]
    ),
    .testTarget(
      name: "CodexMonitorAppServerTests",
      dependencies: ["CodexMonitorAppServer", "CodexMonitorProtocol", "CodexMonitorCore"]
    ),
  ]
)
