// PresenceCore — pure, deterministic logic. No AVFoundation, no Vision, no AppKit.
// The state machine and policy pipeline live here so `swift run Checks` verifies
// all safety behavior headlessly (scripted event streams, no camera, no TCC).

public enum PresenceCoreVersion {
    public static let schemaVersion = 1
}
