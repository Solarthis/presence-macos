import Foundation

public struct LaunchOptions {
    public let scenarioName: String? // Non-nil only for a valid --simulate value.
    public let liveTestEnabled: Bool // True only for --live-test with a valid scenario.
    public var isProduction: Bool { scenarioName == nil }

    public init(arguments: [String], validScenarios: Set<String>) {
        if let flagIndex = arguments.firstIndex(of: "--simulate"),
           arguments.indices.contains(flagIndex + 1),
           validScenarios.contains(arguments[flagIndex + 1]) {
            scenarioName = arguments[flagIndex + 1]
        } else {
            scenarioName = nil
        }
        liveTestEnabled = arguments.contains("--live-test") && scenarioName != nil
    }
}
