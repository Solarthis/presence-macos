// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Presence",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic: state machine, policy pipeline. MUST have zero AVFoundation/Vision imports
        // (enforced by verify.sh grep gate).
        .target(name: "PresenceCore"),
        .executableTarget(name: "Presence", dependencies: ["PresenceCore"]),
        // Assert-based verification harness. XCTest does not exist on this machine (CLT only).
        .executableTarget(name: "Checks", dependencies: ["PresenceCore"]),
    ]
)
