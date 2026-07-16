public enum ConfidenceBand: String, Codable {
    case low
    case medium
    case high
}

public enum PresenceEvent {
    case detection(t: Double, personCount: Int, band: ConfidenceBand)
    case cameraUnavailable(t: Double)
    case cameraRestored(t: Double)
    case tick(t: Double)
    case wake(t: Double)
    case displayChange(t: Double)
    case sessionActive(t: Double)
    case restoreAuthenticated(t: Double)
    case pause(t: Double)
    case resume(t: Double)
    case manualProtect(t: Double)
}
