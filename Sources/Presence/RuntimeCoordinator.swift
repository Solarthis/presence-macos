import AppKit
import Foundation
import PresenceCore

final class RuntimeCoordinator: NSObject {
    private var machine: Machine
    private var activeSource: PresenceSource?
    private let menuBarState: MenuBarState
    private let curtainController: CurtainController
    private let authGate: AuthGate
    private let eventStore: EventStore
    private var tickTimer: Timer?
    private var liveTestDismissTimer: Timer?
    private var lastConfidenceBand: ConfidenceBand?
    private var pendingRestoreAction: String?
    private var liveTestEnabled: Bool
    private var observersInstalled = false

    init(menuBarState: MenuBarState, liveTestEnabled: Bool) {
        let launchTime = ProcessInfo.processInfo.systemUptime
        machine = Machine(launchTime: launchTime)
        self.menuBarState = menuBarState
        self.liveTestEnabled = liveTestEnabled
        eventStore = EventStore()

        var authenticationRequest: (() -> Void)?
        curtainController = CurtainController {
            authenticationRequest?()
        }

        var authenticated: (() -> Void)?
        var rejected: (() -> Void)?
        var failureLimitReached: (() -> Void)?
        authGate = AuthGate(
            onSuccess: { authenticated?() },
            onRejected: { rejected?() },
            onSystemFailureLimit: { failureLimitReached?() }
        )

        super.init()

        authenticationRequest = { [weak self] in self?.requestAuthentication() }
        authenticated = { [weak self] in self?.authenticationSucceeded() }
        rejected = { [weak self] in self?.authenticationRejected() }
        failureLimitReached = { [weak self] in self?.curtainController.showQuitButton() }
        menuBarState.setLiveTest(enabled: liveTestEnabled)
    }

    func start(source: PresenceSource?) {
        installObservers()
        startTickTimer()

        guard let source else {
            activeSource = nil
            process(.pause(t: now()))
            menuBarState.showNoCameraPaused()
            return
        }
        begin(source: source, config: .production)
    }

    func startScripted(scenario: ScriptedSource.Scenario) {
        installObservers()
        startTickTimer()
        begin(source: ScriptedSource(scenario: scenario), config: .scriptedDemo)
    }

    func stop() {
        activeSource?.stop()
        activeSource = nil
        tickTimer?.invalidate()
        tickTimer = nil
        liveTestDismissTimer?.invalidate()
        liveTestDismissTimer = nil
        authGate.cancel()
        curtainController.dismiss()
        removeObservers()
    }

    func togglePause() {
        if machine.state == .paused {
            process(.resume(t: now()))
        } else {
            process(.pause(t: now()))
        }
    }

    func protectNow() {
        if machine.state == .paused {
            process(.resume(t: now()))
        }
        process(.manualProtect(t: now()))
    }

    func simulate(_ scenario: ScriptedSource.Scenario) {
        activeSource?.stop()
        authGate.cancel()
        liveTestDismissTimer?.invalidate()
        liveTestDismissTimer = nil
        curtainController.dismiss()
        begin(source: ScriptedSource(scenario: scenario), config: .scriptedDemo)
    }

    private func begin(source: PresenceSource, config: MachineConfig) {
        let launchTime = now()
        machine = Machine(config: config, launchTime: launchTime)
        activeSource = source
        menuBarState.update(from: machine.state, config: machine.config, now: launchTime)
        source.start { [weak self] event in
            if Thread.isMainThread {
                self?.process(event)
            } else {
                DispatchQueue.main.async { self?.process(event) }
            }
        }
    }

    private func process(_ event: PresenceEvent) {
        if case let .detection(_, _, band) = event {
            lastConfidenceBand = band
        }
        let effects = machine.handle(event)
        execute(effects)
        menuBarState.update(from: machine.state, config: machine.config, now: now())
    }

    private func execute(_ effects: [Effect]) {
        for effect in effects {
            switch effect {
            case .raiseCurtain:
                curtainController.raise()
                scheduleLiveTestDismissalIfNeeded()

            case .dismissCurtain:
                liveTestDismissTimer?.invalidate()
                liveTestDismissTimer = nil
                curtainController.dismiss()

            case .requestAuthUI:
                requestAuthentication()

            case .startGraceCountdown, .cancelGraceCountdown:
                break

            case .showUnknownWarning, .clearUnknownWarning:
                break

            case let .logEvent(kind):
                let action = actionTaken(for: kind)
                eventStore.append(
                    kind,
                    confidenceBand: lastConfidenceBand,
                    actionTaken: action
                )
            }
        }
    }

    private func actionTaken(for kind: EventKind) -> String? {
        switch kind {
        case .presenceLost:
            return "presence-lost"
        case .graceStarted:
            return "grace-started"
        case .curtainRaised, .additionalViewer:
            return "curtain-raised"
        case .restoreApproved:
            defer { pendingRestoreAction = nil }
            return pendingRestoreAction ?? "authentication-approved"
        case .restoreRejected:
            return "authentication-rejected"
        case .cameraUnavailable:
            return "monitoring-suspended"
        case .monitoringPaused:
            return "monitoring-paused"
        case .monitoringResumed:
            return "monitoring-resumed"
        }
    }

    private func requestAuthentication() {
        guard curtainController.isRaised else { return }
        authGate.requestAuthentication()
    }

    private func authenticationSucceeded() {
        process(.restoreAuthenticated(t: now()))
        if activeSource == nil {
            process(.pause(t: now()))
        }
    }

    private func authenticationRejected() {
        eventStore.append(
            .restoreRejected,
            confidenceBand: lastConfidenceBand,
            actionTaken: "authentication-rejected"
        )
    }

    private func scheduleLiveTestDismissalIfNeeded() {
        guard liveTestEnabled else { return }
        liveTestDismissTimer?.invalidate()
        let timer = Timer(timeInterval: 10, repeats: false) { [weak self] _ in
            guard let self, self.curtainController.isRaised else { return }
            self.pendingRestoreAction = "live-test-autodismiss"
            self.process(.restoreAuthenticated(t: self.now()))
        }
        liveTestDismissTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func startTickTimer() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.process(.tick(t: self.now()))
        }
        timer.tolerance = 0.1
        tickTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func installObservers() {
        guard !observersInstalled else { return }
        observersInstalled = true
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(
            self,
            selector: #selector(workspaceDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(screensDidWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(sessionDidBecomeActive),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func removeObservers() {
        guard observersInstalled else { return }
        observersInstalled = false
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func workspaceDidWake() {
        processEnvironmental(.wake(t: now()))
    }

    @objc private func screensDidWake() {
        processEnvironmental(.wake(t: now()))
    }

    @objc private func sessionDidBecomeActive() {
        processEnvironmental(.sessionActive(t: now()))
    }

    @objc private func screenParametersDidChange() {
        curtainController.recoverScreens()
        processEnvironmental(.displayChange(t: now()))
    }

    private func processEnvironmental(_ event: PresenceEvent) {
        let curtainWasRaised = curtainController.isRaised
        process(event)
        if curtainWasRaised {
            process(.manualProtect(t: now()))
        }
    }

    private func now() -> Double {
        ProcessInfo.processInfo.systemUptime
    }
}
