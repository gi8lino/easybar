// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  name: "EasyBar",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(name: "EasyBarShared", targets: ["EasyBarShared"]),
    .executable(name: "EasyBar", targets: ["EasyBar"]),
    .executable(name: "easybarctl", targets: ["easybarctl"]),
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
      path: "Sources/shared"
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
      name: "easybarctl",
      dependencies: [
        "EasyBarShared"
      ],
      path: "Sources/easybarctl"
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
        "EasyBarShared"
      ],
      path: "agents/network-agent",
      exclude: [
        "Info.plist"
      ]
    ),
  ]
)
