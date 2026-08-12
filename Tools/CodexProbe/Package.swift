// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "CodexMonitorProbe",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(name: "CodexProbeCore", targets: ["CodexProbeCore"]),
    .executable(name: "codex-probe", targets: ["CodexProbe"]),
  ],
  targets: [
    .target(name: "CodexProbeCore"),
    .executableTarget(
      name: "CodexProbe",
      dependencies: ["CodexProbeCore"]
    ),
    .testTarget(
      name: "CodexProbeCoreTests",
      dependencies: ["CodexProbeCore"],
      resources: [.process("Fixtures")]
    ),
  ]
)
