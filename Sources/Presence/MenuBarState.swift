import SwiftUI
import PresenceCore

final class MenuBarState: ObservableObject {
    static let shared = MenuBarState()

    @Published private(set) var statusText = "PAUSED"
    @Published private(set) var detailText = "monitoring off — camera pipeline not yet installed"
    @Published private(set) var symbolName = "pause.circle.fill"
    @Published private(set) var isPaused = true
    @Published private(set) var isProtected = false
    @Published private(set) var isSafeMode = false
    @Published private(set) var liveTestEnabled = false
    @Published private(set) var cameraAuthorizationState = CameraAuthorizationState.notDetermined
    @Published private(set) var isHUDVisible = false
    @Published private(set) var activeScenarioName: String?
    @Published private(set) var fixtureCaptureAvailable = false

    var isSimulatorRunning: Bool { activeScenarioName != nil }

    var menuBarText: String {
        let base = "\(statusText) — \(detailText)"
        let simulatorText = activeScenarioName.map { " — SIMULATOR: \($0)" } ?? ""
        let liveTestText = liveTestEnabled ? " — LIVE TEST" : ""
        return "\(base)\(simulatorText)\(liveTestText)"
    }

    private init() {}

    func setLiveTest(enabled: Bool) {
        liveTestEnabled = enabled
    }

    func setFixtureCaptureAvailable(_ available: Bool) {
        fixtureCaptureAvailable = available
    }

    func setHUDVisible(_ visible: Bool) {
        isHUDVisible = visible
    }

    func beginSimulator(_ scenarioName: String) {
        activeScenarioName = scenarioName
    }

    func endSimulator() {
        activeScenarioName = nil
    }

    func showCameraPermissionNeeded() {
        cameraAuthorizationState = .notDetermined
        showCameraUnavailableText()
    }

    func showCameraUnavailable() {
        cameraAuthorizationState = .unavailable
        showCameraUnavailableText()
    }

    func markCameraAuthorized() {
        cameraAuthorizationState = .authorized
    }

    func showSafeMode(notice: String?) {
        isSafeMode = true
        isPaused = true
        isProtected = false
        statusText = "Presence — safe mode (disabled)"
        detailText = notice ?? "monitoring and protection are disabled"
        symbolName = "exclamationmark.shield.fill"
    }

    func showNoCameraPaused() {
        isSafeMode = false
        isPaused = true
        isProtected = false
        statusText = "PAUSED"
        detailText = "monitoring off — camera pipeline not yet installed"
        symbolName = "pause.circle.fill"
    }

    private func showCameraUnavailableText() {
        isSafeMode = false
        isPaused = true
        isProtected = false
        statusText = "CAMERA UNAVAILABLE"
        detailText = "camera unavailable — monitoring off"
        symbolName = "video.slash.fill"
    }

    func update(from state: PresenceState, config: MachineConfig, now: Double) {
        guard !isSafeMode else { return }

        isPaused = state == .paused
        if case .protected = state {
            isProtected = true
        } else {
            isProtected = false
        }

        switch state {
        case .launchGuard, .awaitingPresence, .cooldown:
            statusText = "MONITORING"
            detailText = "waiting for confirmed presence"
            symbolName = "eye.fill"

        case .present:
            statusText = "PRESENT"
            detailText = "workspace presence confirmed"
            symbolName = "person.crop.circle.fill"

        case let .grace(since):
            let remaining = max(0, Int(ceil(config.graceSeconds - (now - since))))
            statusText = "GRACE"
            detailText = "protecting in \(remaining) s"
            symbolName = "timer"

        case .protected:
            statusText = "PROTECTED"
            detailText = "workspace curtain raised"
            symbolName = "lock.fill"

        case .paused:
            showNoCameraPaused()

        case .unknownWarning:
            statusText = "UNKNOWN"
            detailText = "camera unavailable — monitoring suspended"
            symbolName = "video.slash.fill"
        }
    }
}
