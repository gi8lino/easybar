// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  name: "EasyBar",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(name: "EasyBarShared", targets: ["EasyBarShared"]),
    .library(name: "EasyBarCalendarConfig", targets: ["EasyBarCalendarConfig"]),
    .library(name: "EasyBarCalendarCore", targets: ["EasyBarCalendarCore"]),
    .library(name: "EasyBarCalendarPresentation", targets: ["EasyBarCalendarPresentation"]),
    .library(name: "EasyBarCalendarUI", targets: ["EasyBarCalendarUI"]),
    .library(name: "EasyBarNetworkAgentCore", targets: ["EasyBarNetworkAgentCore"]),
    .executable(name: "EasyBar", targets: ["EasyBarApp"]),
    .executable(name: "EasyBarLuaRuntime", targets: ["EasyBarLuaRuntime"]),
    .executable(name: "EasyBarCtl", targets: ["EasyBarCtl"]),
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
      name: "EasyBarCalendarCore",
      dependencies: [
        "EasyBarShared"
      ],
      path: "Sources/EasyBarCalendarCore"
    ),
    .target(
      name: "EasyBarCalendarPresentation",
      dependencies: [
        "EasyBarShared"
      ],
      path: "Sources/EasyBarCalendarPresentation"
    ),
    .target(
      name: "EasyBarCalendarUI",
      dependencies: [
        "EasyBarShared",
        "EasyBarCalendarPresentation",
      ],
      path: "Sources/EasyBarCalendarUI"
    ),
    .target(
      name: "EasyBarCalendarConfig",
      dependencies: [
        "EasyBarShared",
        "EasyBarCalendarPresentation",
        "EasyBarCalendarUI",
        .product(name: "TOMLKit", package: "TOMLKit"),
      ],
      path: "Sources/EasyBarCalendarConfig"
    ),
    .target(
      name: "EasyBarNetworkAgentCore",
      dependencies: [
        "EasyBarShared"
      ],
      path: "Sources/EasyBarNetworkAgentCore"
    ),
    .executableTarget(
      name: "EasyBarApp",
      dependencies: [
        "EasyBarShared",
        "EasyBarCalendarConfig",
        "EasyBarCalendarPresentation",
        "EasyBarCalendarUI",
        .product(name: "TOMLKit", package: "TOMLKit"),
      ],
      path: "Sources/EasyBarApp",
      exclude: [
        "Info.plist",
        "Lua/easybar_api.base.lua",
        "Lua/easybar_api.events.lua",
      ],
      resources: [
        .copy("Events/event_catalog.json"),
        .copy("Lua/runtime.lua"),
        .copy("Lua/easybar_api.lua"),
        .copy("Lua/easybar"),
        .copy("Themes"),
      ]
    ),
    .executableTarget(
      name: "EasyBarLuaRuntime",
      dependencies: [
        "EasyBarShared"
      ],
      path: "Sources/EasyBarLuaRuntime"
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
        "EasyBarShared",
        "EasyBarCalendarCore",
      ],
      path: "Sources/EasyBarCalendarAgent",
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
      path: "Sources/EasyBarNetworkAgent",
      exclude: [
        "Info.plist"
      ]
    ),
    .testTarget(
      name: "EasyBarTests",
      dependencies: [
        "EasyBarApp",
        "EasyBarLuaRuntime",
        "EasyBarShared",
        "EasyBarCalendarConfig",
        "EasyBarCalendarUI",
      ],
      path: "Tests/EasyBarTests"
    ),
  ]
)
