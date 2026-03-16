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
        .package(url: "https://github.com/LebJe/TOMLKit", from: "0.2.0")
    ],
    targets: [
        .executableTarget(
            name: "EasyBar",
            dependencies: [
                .product(name: "TOMLKit", package: "TOMLKit")
            ],
            resources: [
                .copy("Lua/runtime.lua"),
                .copy("Lua/easybar")
            ]
        ),
        .executableTarget(
            name: "easybarctl"
        )
    ]
)
