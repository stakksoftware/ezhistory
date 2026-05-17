// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EzHistory",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "EzHistory",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            path: "Sources/EzHistory"
        ),
    ]
)
