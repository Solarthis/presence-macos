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
    private let policyStore: PolicyStore
    private let hudPanel: HUDPanel
    private let displaysOffExecutor: DisplaysOffExecutor
    private let fixtureCaptureEnabled: Bool
    private var tickTimer: Timer?
    private var liveTestDismissTimer: Timer?
    private var lastConfidenceBand: ConfidenceBand?
    private var pendingRestoreAction: String?
    private var liveTestEnabled: Bool
    private var observersInstalled = false
    private var isScriptedRun = false
    private var policyRefreshPending = false
    private var sourceGeneration = 0
    private var lastPersonCount: Int?
    private var hudWasVisibleBeforeSimulator = false
    private var simulatorRestorePending = false

    init(
        menuBarState: MenuBarState,
        liveTestEnabled: Bool,
        policyStore: PolicyStore = .shared,
        fixtureCaptureEnabled: Bool = false
    ) {
        let launchTime = ProcessInfo.processInfo.systemUptime
        machine = Machine(
            config: .production(applying: policyStore.activePolicy),
            launchTime: launchTime
        )
        self.menuBarState = menuBarState
        self.liveTestEnabled = liveTestEnabled
        self.policyStore = policyStore
        hudPanel = HUDPanel()
        displaysOffExecutor = DisplaysOffExecutor()
#if DEBUG
        self.fixtureCaptureEnabled = fixtureCaptureEnabled
#else
        self.fixtureCaptureEnabled = false
#endif
        eventStore = EventStore.shared

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
        policyStore.onActivePolicyChanged = { [weak self] policy in
            self?.activePolicyChanged(policy)
        }
        menuBarState.setLiveTest(enabled: liveTestEnabled)
        menuBarState.setFixtureCaptureAvailable(self.fixtureCaptureEnabled)
    }

    func start(source: PresenceSource?) {
        activeSource?.stop()
        sourceGeneration += 1
        isScriptedRun = false
        installObservers()
        startTickTimer()

        guard let source else {
            activeSource = nil
            process(.pause(t: now()))
            menuBarState.showNoCameraPaused()
            return
        }
        begin(source: source, config: .production(applying: policyStore.activePolicy))
    }

    func startScripted(scenario: ScriptedSource.Scenario) {
        installObservers()
        startTickTimer()
        beginSimulator(scenario)
    }

    func startForCurrentCameraAuthorization() {
        switch CameraSource.authorizationState {
        case .authorized:
            startCameraMonitoring()
        case .notDetermined:
            start(source: nil)
            menuBarState.showCameraPermissionNeeded()
            updateHUD()
        case .unavailable:
            start(source: nil)
            menuBarState.showCameraUnavailable()
            updateHUD()
        }
    }

    func requestCameraAccess() {
        guard CameraSource.authorizationState == .notDetermined else {
            startForCurrentCameraAuthorization()
            return
        }
        CameraSource.requestAccess { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                if granted {
                    self.startCameraMonitoring()
                } else {
                    self.start(source: nil)
                    self.menuBarState.showCameraUnavailable()
                    self.updateHUD()
                }
            }
        }
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
        hudPanel.hide()
        menuBarState.setHUDVisible(false)
        menuBarState.endSimulator()
        policyStore.onActivePolicyChanged = nil
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
        guard !curtainController.isRaised else { return }
        beginSimulator(scenario)
    }

    func stopSimulator() {
        guard isScriptedRun else { return }
        finishOrDeferSimulatorRestoration()
    }

    func toggleHUD() {
        guard !isScriptedRun else { return }
        if hudPanel.isVisible {
            hudPanel.hide()
            menuBarState.setHUDVisible(false)
        } else {
            hudPanel.show()
            menuBarState.setHUDVisible(true)
            updateHUD()
        }
    }

    func captureFixtureFrame() {
        guard fixtureCaptureEnabled, let camera = activeSource as? CameraSource else { return }
        camera.captureFixtureFrame { result in
            if case .failure = result {
                DispatchQueue.main.async { NSSound.beep() }
            }
        }
    }

    private func begin(source: PresenceSource, config: MachineConfig) {
        sourceGeneration += 1
        let generation = sourceGeneration
        let launchTime = now()
        machine = Machine(config: config, launchTime: launchTime)
        activeSource = source
        lastPersonCount = nil
        menuBarState.update(from: machine.state, config: machine.config, now: launchTime)
        updateHUD()
        source.start { [weak self] event in
            let receive = {
                guard let self, self.sourceGeneration == generation else { return }
                self.process(event)
            }
            if Thread.isMainThread {
                receive()
            } else {
                DispatchQueue.main.async(execute: receive)
            }
        }
    }

    private func process(_ event: PresenceEvent) {
        if case let .detection(_, personCount, band) = event {
            lastPersonCount = personCount
            lastConfidenceBand = band
        }
        let cameraEvent = activeSource is CameraSource
        let effects = machine.handle(event)
        execute(effects, triggeredBy: event)
        menuBarState.update(from: machine.state, config: machine.config, now: now())
        if cameraEvent {
            switch event {
            case .cameraUnavailable:
                menuBarState.showCameraUnavailable()
            case .cameraRestored:
                menuBarState.markCameraAuthorized()
                menuBarState.update(from: machine.state, config: machine.config, now: now())
            case .detection:
                menuBarState.markCameraAuthorized()
            default:
                break
            }
        }
        updateHUD()
    }

    private func execute(_ effects: [Effect], triggeredBy event: PresenceEvent) {
        let protectionKind = effects.compactMap { effect -> EventKind? in
            guard case let .logEvent(kind) = effect,
                  kind == .curtainRaised || kind == .additionalViewer else {
                return nil
            }
            return kind
        }.first

        for effect in effects {
            switch effect {
            case .raiseCurtain:
                let title = protectionKind == .additionalViewer
                    ? "Another person may be able to view your screen"
                    : "Presence protected this workspace"
                curtainController.raise(title: title)
                if !isScriptedRun,
                   let trigger = policyTrigger(for: protectionKind, event: event) {
                    displaysOffExecutor.executeIfAllowed(
                        policy: policyStore.activePolicy,
                        trigger: trigger
                    )
                }
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
                    policyId: isScriptedRun ? nil : policyStore.activePolicyID?.uuidString,
                    confidenceBand: lastConfidenceBand,
                    actionTaken: action
                )
            }
        }
    }

    private func policyTrigger(
        for kind: EventKind?,
        event: PresenceEvent
    ) -> PolicyTrigger? {
        switch event {
        case .detection, .tick:
            break
        default:
            return nil
        }
        switch kind {
        case .additionalViewer:
            return .additionalViewer
        case .curtainRaised:
            return .absence
        default:
            return nil
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
        finishPendingSimulatorRestorationIfPossible()
        if policyRefreshPending {
            policyRefreshPending = false
            activePolicyChanged(policyStore.activePolicy)
        }
        if activeSource == nil {
            process(.pause(t: now()))
        }
    }

    private func authenticationRejected() {
        eventStore.append(
            .restoreRejected,
            policyId: isScriptedRun ? nil : policyStore.activePolicyID?.uuidString,
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
            self.finishPendingSimulatorRestorationIfPossible()
        }
        liveTestDismissTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func startTickTimer() {
        guard tickTimer == nil else { return }
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
        hudPanel.reposition()
        processEnvironmental(.displayChange(t: now()))
    }

    private func processEnvironmental(_ event: PresenceEvent) {
        let curtainWasRaised = curtainController.isRaised
        process(event)
        if curtainWasRaised {
            process(.manualProtect(t: now()))
        }
    }

    private func activePolicyChanged(_ policy: Policy?) {
        guard !isScriptedRun else { return }
        guard !curtainController.isRaised else {
            policyRefreshPending = true
            return
        }

        let config = MachineConfig.production(applying: policy)
        if let source = activeSource {
            start(source: source)
        } else {
            let launchTime = now()
            machine = Machine(config: config, launchTime: launchTime)
            _ = machine.handle(.pause(t: launchTime))
            menuBarState.showNoCameraPaused()
            updateHUD()
        }
    }

    private func beginSimulator(_ scenario: ScriptedSource.Scenario) {
        if !isScriptedRun {
            hudWasVisibleBeforeSimulator = hudPanel.isVisible
        }
        activeSource?.stop()
        sourceGeneration += 1
        authGate.cancel()
        liveTestDismissTimer?.invalidate()
        liveTestDismissTimer = nil
        isScriptedRun = true
        simulatorRestorePending = false
        hudPanel.show()
        menuBarState.setHUDVisible(true)
        menuBarState.beginSimulator(scenario.rawValue)

        let source = ScriptedSource(scenario: scenario) { [weak self] in
            self?.finishOrDeferSimulatorRestoration()
        }
        begin(source: source, config: .scriptedDemo)
    }

    private func finishOrDeferSimulatorRestoration() {
        guard isScriptedRun else { return }
        activeSource?.stop()
        sourceGeneration += 1
        if curtainController.isRaised {
            simulatorRestorePending = true
            return
        }
        restoreProductionAfterSimulator()
    }

    private func finishPendingSimulatorRestorationIfPossible() {
        guard simulatorRestorePending, !curtainController.isRaised else { return }
        simulatorRestorePending = false
        restoreProductionAfterSimulator()
    }

    /// Simulator exit is structurally routed through start(source:), the production-only entrypoint.
    private func restoreProductionAfterSimulator() {
        guard isScriptedRun else { return }
        isScriptedRun = false
        simulatorRestorePending = false
        menuBarState.endSimulator()
        if !hudWasVisibleBeforeSimulator {
            hudPanel.hide()
            menuBarState.setHUDVisible(false)
        }

        switch CameraSource.authorizationState {
        case .authorized:
            startCameraMonitoring()
        case .notDetermined:
            start(source: nil)
            menuBarState.showCameraPermissionNeeded()
            updateHUD()
        case .unavailable:
            start(source: nil)
            menuBarState.showCameraUnavailable()
            updateHUD()
        }
    }

    /// CameraSource construction is private and every instance enters through start(source:).
    private func startCameraMonitoring() {
        menuBarState.markCameraAuthorized()
        start(source: CameraSource(fixtureCaptureEnabled: fixtureCaptureEnabled))
    }

    private func updateHUD() {
        hudPanel.update(
            state: machine.state,
            config: machine.config,
            now: now(),
            personCount: lastPersonCount,
            confidenceBand: lastConfidenceBand,
            scenarioName: menuBarState.activeScenarioName
        )
    }

    private func now() -> Double {
        ProcessInfo.processInfo.systemUptime
    }
}
