// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  name: "EasyBar",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(name: "EasyBarShared", targets: ["EasyBarShared"]),
    .library(name: "EasyBarNetworkAgentCore", targets: ["EasyBarNetworkAgentCore"]),
    .executable(name: "EasyBar", targets: ["EasyBar"]),
    .executable(name: "easybar", targets: ["EasyBarCtl"]),
    .executable(name: "EasyBarCalendarAgent", targets: ["EasyBarCalendarAgent"]),
    .executable(name: "EasyBarNetworkAgent", targets: ["EasyBarNetworkAgent"]),
  ],
  dependencies: [
    .package(url: "https://github.com/LebJe/TOMLKit", from: "0.6.0")
  ],
  targets: [
    .target(
      name: "EasyBarShared",
      dependencies: [
        .product(name: "TOMLKit", package: "TOMLKit")
      ],
      path: "Sources/EasyBarShared"
    ),
    .target(
      name: "EasyBarNetworkAgentCore",
      dependencies: [
        "EasyBarShared"
      ],
      path: "Sources/EasyBarNetworkAgentCore"
    ),
    .executableTarget(
      name: "EasyBar",
      dependencies: [
        "EasyBarShared",
        .product(name: "TOMLKit", package: "TOMLKit"),
      ],
      path: "Sources/EasyBar",
      resources: [
        .copy("Lua/runtime.lua"),
        .copy("Lua/easybar_api.lua"),
        .copy("Lua/easybar"),
      ]
    ),
    .executableTarget(
      name: "EasyBarCtl",
      dependencies: [
        "EasyBarShared"
      ],
      path: "Sources/EasyBarCtl"
    ),
    .executableTarget(
      name: "EasyBarCalendarAgent",
      dependencies: [
        "EasyBarShared"
      ],
      path: "agents/calendar-agent",
      exclude: [
        "Info.plist"
      ]
    ),
    .executableTarget(
      name: "EasyBarNetworkAgent",
      dependencies: [
        "EasyBarShared",
        "EasyBarNetworkAgentCore",
      ],
      path: "agents/network-agent/App"
    ),
  ]
)
