public enum PresenceDefaults {
    public static let graceSeconds = 30.0 // Thirty seconds tolerates ordinary brief walk-aways.
    public static let presenceConfirmSeconds = 2.0 // Two seconds filters single-frame person flicker.
    public static let armAfterPresenceSeconds = 3.0 // Three confirmed seconds prevents hasty re-arming.
    public static let cooldownSeconds = 60.0 // One minute prevents an immediate post-restore retrigger.
    public static let launchGuardSeconds = 30.0 // Thirty seconds keeps startup and camera warm-up safe.
    public static let additionalViewerEnabled = false // Multi-viewer protection stays opt-in for this slice.
    public static let additionalViewerMinPersons = 2 // Two people is the first additional-viewer condition.
    public static let additionalViewerSustainSeconds = 5.0 // Five seconds rejects a passing second-person flicker.
}

public struct MachineConfig {
    public var graceSeconds: Double
    public var presenceConfirmSeconds: Double
    public var armAfterPresenceSeconds: Double
    public var cooldownSeconds: Double
    public var launchGuardSeconds: Double
    public var additionalViewerEnabled: Bool
    public var additionalViewerMinPersons: Int
    public var additionalViewerSustainSeconds: Double

    public init(
        graceSeconds: Double = PresenceDefaults.graceSeconds,
        presenceConfirmSeconds: Double = PresenceDefaults.presenceConfirmSeconds,
        armAfterPresenceSeconds: Double = PresenceDefaults.armAfterPresenceSeconds,
        cooldownSeconds: Double = PresenceDefaults.cooldownSeconds,
        launchGuardSeconds: Double = PresenceDefaults.launchGuardSeconds,
        additionalViewerEnabled: Bool = PresenceDefaults.additionalViewerEnabled,
        additionalViewerMinPersons: Int = PresenceDefaults.additionalViewerMinPersons,
        additionalViewerSustainSeconds: Double = PresenceDefaults.additionalViewerSustainSeconds
    ) {
        self.graceSeconds = graceSeconds
        self.presenceConfirmSeconds = presenceConfirmSeconds
        self.armAfterPresenceSeconds = armAfterPresenceSeconds
        self.cooldownSeconds = cooldownSeconds
        self.launchGuardSeconds = launchGuardSeconds
        self.additionalViewerEnabled = additionalViewerEnabled
        self.additionalViewerMinPersons = additionalViewerMinPersons
        self.additionalViewerSustainSeconds = additionalViewerSustainSeconds
    }
}

public extension MachineConfig {
    /// Production always derives from PresenceDefaults. Never accepts compressed timing.
    static var production: MachineConfig { MachineConfig() }

    /// Compressed timing for explicit DEBUG scripted runs only. Never used with a camera.
    static var scriptedDemo: MachineConfig {
        MachineConfig(graceSeconds: 8, launchGuardSeconds: 0, additionalViewerEnabled: true)
    }
}
