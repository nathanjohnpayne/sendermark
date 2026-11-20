// swift-tools-version: 6.0

// Sendermark: the SendermarkCore library and the `sendermark` command-line tool
// (PRD § Architecture). The Mac app target is added separately (#39).
//
// Layout: sources live under `src/` and tests under `tests/swift/` instead of
// SwiftPM's default `Sources/` and `Tests/`. The repository already has a
// `tests/` directory, and on the default case-insensitive macOS filesystem a
// `Tests/` directory would be the same directory. See
// docs/agents/code-modification-rules.md § Swift package layout.
//
// No third-party dependencies: the package uses only the Swift standard
// library and Apple's system frameworks.

import PackageDescription

let package = Package(
    name: "Sendermark",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(name: "SendermarkCore", targets: ["SendermarkCore"]),
        .executable(name: "sendermark", targets: ["sendermark"]),
    ],
    targets: [
        .target(
            name: "SendermarkCore",
            path: "src/SendermarkCore"
        ),
        .executableTarget(
            name: "sendermark",
            dependencies: ["SendermarkCore"],
            path: "src/sendermark"
        ),
        .testTarget(
            name: "SendermarkTests",
            dependencies: ["SendermarkCore", "sendermark"],
            path: "tests/swift/SendermarkTests"
        ),
    ]
)
