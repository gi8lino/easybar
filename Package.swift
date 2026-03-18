// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "EasyBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "EasyBar", targets: ["EasyBar"]),
        .executable(name: "easybarctl", targets: ["easybarctl"])
    ],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit", from: "0.6.0")
    ],
    targets: [
        .target(
            name: "EasyBarShared",
            path: "Sources/shared"
        ),
        .executableTarget(
            name: "EasyBar",
            dependencies: [
                "EasyBarShared",
                .product(name: "TOMLKit", package: "TOMLKit")
            ],
            path: "Sources/EasyBar",
            resources: [
                .copy("Lua/runtime.lua"),
                .copy("Lua/easybar")
            ]
        ),
        .executableTarget(
            name: "easybarctl",
            dependencies: [
                "EasyBarShared"
            ],
            path: "Sources/easybarctl"
        )
    ]
)
