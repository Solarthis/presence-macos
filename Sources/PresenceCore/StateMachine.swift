public enum DetectionStatus {
    case present
    case absent
    case unknown
}

public enum PresenceState: Equatable {
    case launchGuard
    case awaitingPresence
    case present
    case grace(since: Double)
    case protected(since: Double)
    case cooldown(since: Double)
    case paused
    case unknownWarning
}

public enum EventKind: String, Codable {
    case presenceLost
    case graceStarted
    case curtainRaised
    case additionalViewer
    case restoreApproved
    case restoreRejected
    case cameraUnavailable
    case monitoringPaused
    case monitoringResumed
}

public enum Effect: Equatable {
    case raiseCurtain
    case dismissCurtain
    case requestAuthUI
    case startGraceCountdown(seconds: Double)
    case cancelGraceCountdown
    case showUnknownWarning
    case clearUnknownWarning
    case logEvent(EventKind)
}

public struct Machine {
    public private(set) var state: PresenceState
    public let config: MachineConfig

    private let launchTime: Double
    private var detectionStatus: DetectionStatus = .unknown
    private var presenceCandidateStartTime: Double?
    private var confirmedPresenceStartTime: Double?
    private var lastPresentTime: Double?
    private var absenceStartTime: Double?
    private var multiPersonStartTime: Double?
    private var firstPresentConfirmed = false
    private var unknownWarningVisible = false

    public init(config: MachineConfig = MachineConfig(), launchTime: Double = 0) {
        self.state = .launchGuard
        self.config = config
        self.launchTime = launchTime
    }

    public mutating func handle(_ event: PresenceEvent) -> [Effect] {
        switch event {
        case let .detection(t, personCount, band):
            return handleDetection(t: t, personCount: personCount, band: band)
        case let .cameraUnavailable(t):
            return handleUnknown(t: t, cameraUnavailable: true)
        case let .cameraRestored(t):
            return handleCameraRestored(t: t)
        case let .tick(t):
            return handleTick(t: t)
        case let .wake(t), let .displayChange(t), let .sessionActive(t):
            return handleEnvironmentalReset(t: t)
        case let .restoreAuthenticated(t):
            return handleRestoreAuthenticated(t: t)
        case let .pause(t):
            return handlePause(t: t)
        case let .resume(t):
            return handleResume(t: t)
        case let .manualProtect(t):
            return handleManualProtect(t: t)
        }
    }

    private mutating func handleDetection(
        t: Double,
        personCount: Int,
        band: ConfidenceBand
    ) -> [Effect] {
        guard state != .paused else { return [] }

        if band == .low {
            return handleUnknown(t: t, cameraUnavailable: false)
        }

        if case let .cooldown(since) = state, t - since >= config.cooldownSeconds {
            state = unknownWarningVisible ? .unknownWarning : .awaitingPresence
            resetObservations()
        }

        if personCount == 0 {
            return handleConfidentAbsence(t: t)
        }

        return handleConfidentPresence(t: t, personCount: personCount)
    }

    private mutating func handleConfidentPresence(t: Double, personCount: Int) -> [Effect] {
        absenceStartTime = nil
        lastPresentTime = t
        var effects: [Effect] = []

        if unknownWarningVisible {
            unknownWarningVisible = false
            effects.append(.clearUnknownWarning)
        }
        if state == .unknownWarning {
            state = .awaitingPresence
        }

        if presenceCandidateStartTime == nil {
            presenceCandidateStartTime = t
        }

        if let candidateStart = presenceCandidateStartTime,
           t - candidateStart >= config.presenceConfirmSeconds {
            if detectionStatus != .present {
                confirmedPresenceStartTime = t
            }
            detectionStatus = .present
            firstPresentConfirmed = true
        } else {
            detectionStatus = .unknown
        }

        switch state {
        case .launchGuard:
            armIfReady(t: t)
            return effects

        case .awaitingPresence:
            armIfReady(t: t)
            return effects

        case .grace:
            // A confident non-low person frame breaks consecutive absence immediately.
            detectionStatus = .present
            confirmedPresenceStartTime = confirmedPresenceStartTime ?? t
            state = .present
            effects.append(.cancelGraceCountdown)
            startOrResetAdditionalViewer(t: t, personCount: personCount)
            return effects

        case .present:
            effects.append(contentsOf: handleAdditionalViewer(t: t, personCount: personCount))
            return effects

        case .cooldown, .protected, .paused:
            multiPersonStartTime = nil
            return effects

        case .unknownWarning:
            return effects
        }
    }

    private mutating func handleConfidentAbsence(t: Double) -> [Effect] {
        presenceCandidateStartTime = nil
        confirmedPresenceStartTime = nil
        lastPresentTime = nil
        multiPersonStartTime = nil
        detectionStatus = .absent
        var effects: [Effect] = []

        if unknownWarningVisible {
            unknownWarningVisible = false
            effects.append(.clearUnknownWarning)
        }
        if state == .unknownWarning {
            state = .awaitingPresence
        }

        switch state {
        case .present:
            absenceStartTime = t
            state = .grace(since: t)
            effects.append(.logEvent(.presenceLost))
            effects.append(.startGraceCountdown(seconds: config.graceSeconds))
            effects.append(.logEvent(.graceStarted))
            return effects

        case let .grace(since):
            absenceStartTime = since
            if t - since >= config.graceSeconds {
                state = .protected(since: t)
                effects.append(.raiseCurtain)
                effects.append(.logEvent(.curtainRaised))
            }
            return effects

        case .launchGuard, .awaitingPresence, .protected, .cooldown, .paused:
            return effects

        case .unknownWarning:
            return effects
        }
    }

    private mutating func handleUnknown(t: Double, cameraUnavailable: Bool) -> [Effect] {
        guard state != .paused else { return [] }

        detectionStatus = .unknown
        presenceCandidateStartTime = nil
        confirmedPresenceStartTime = nil
        lastPresentTime = nil
        absenceStartTime = nil
        multiPersonStartTime = nil

        var effects: [Effect] = []
        if case .grace = state {
            effects.append(.cancelGraceCountdown)
        }

        switch state {
        case .launchGuard, .protected, .cooldown:
            break
        case .awaitingPresence, .present, .grace:
            state = .unknownWarning
        case .unknownWarning, .paused:
            break
        }

        if !unknownWarningVisible {
            unknownWarningVisible = true
            effects.append(.showUnknownWarning)
        }
        if cameraUnavailable {
            effects.append(.logEvent(.cameraUnavailable))
        }
        return effects
    }

    private mutating func handleCameraRestored(t: Double) -> [Effect] {
        _ = t
        guard state != .paused else { return [] }

        resetObservations()
        var effects: [Effect] = []
        if unknownWarningVisible {
            unknownWarningVisible = false
            effects.append(.clearUnknownWarning)
        }
        if state == .unknownWarning {
            state = .awaitingPresence
        }
        return effects
    }

    private mutating func handleTick(t: Double) -> [Effect] {
        switch state {
        case let .grace(since) where t - since >= config.graceSeconds:
            state = .protected(since: t)
            return [.raiseCurtain, .logEvent(.curtainRaised)]

        case let .cooldown(since) where t - since >= config.cooldownSeconds:
            state = unknownWarningVisible ? .unknownWarning : .awaitingPresence
            resetObservations()
            return []

        default:
            return []
        }
    }

    private mutating func handleEnvironmentalReset(t: Double) -> [Effect] {
        _ = t
        guard state != .paused else { return [] }

        var effects: [Effect] = []
        if case .grace = state {
            effects.append(.cancelGraceCountdown)
        }
        if unknownWarningVisible {
            unknownWarningVisible = false
            effects.append(.clearUnknownWarning)
        }
        resetObservations()
        state = .awaitingPresence
        return effects
    }

    private mutating func handleRestoreAuthenticated(t: Double) -> [Effect] {
        guard case .protected = state else { return [] }

        resetObservations()
        var effects: [Effect] = []
        if unknownWarningVisible {
            effects.append(.clearUnknownWarning)
        }
        unknownWarningVisible = false
        state = .cooldown(since: t)
        effects.append(.dismissCurtain)
        effects.append(.logEvent(.restoreApproved))
        return effects
    }

    private mutating func handlePause(t: Double) -> [Effect] {
        _ = t
        guard state != .paused else { return [] }

        var effects: [Effect] = []
        if case .grace = state {
            effects.append(.cancelGraceCountdown)
        }
        if unknownWarningVisible {
            unknownWarningVisible = false
            effects.append(.clearUnknownWarning)
        }
        resetObservations()
        // Deliberately do not dismiss here: pausing while protected keeps the curtain raised.
        state = .paused
        effects.append(.logEvent(.monitoringPaused))
        return effects
    }

    private mutating func handleResume(t: Double) -> [Effect] {
        _ = t
        guard state == .paused else { return [] }

        resetObservations()
        state = .awaitingPresence
        return [.logEvent(.monitoringResumed)]
    }

    private mutating func handleManualProtect(t: Double) -> [Effect] {
        guard state != .paused else { return [] }
        guard case .protected = state else {
            var effects: [Effect] = []
            if case .grace = state {
                effects.append(.cancelGraceCountdown)
            }
            if unknownWarningVisible {
                unknownWarningVisible = false
                effects.append(.clearUnknownWarning)
            }
            resetObservations()
            state = .protected(since: t)
            effects.append(.raiseCurtain)
            effects.append(.logEvent(.curtainRaised))
            return effects
        }
        return []
    }

    private mutating func armIfReady(t: Double) {
        guard firstPresentConfirmed,
              t - launchTime >= config.launchGuardSeconds,
              detectionStatus == .present,
              let confirmedStart = confirmedPresenceStartTime,
              t - confirmedStart >= config.armAfterPresenceSeconds else {
            if state != .launchGuard {
                state = .awaitingPresence
            }
            return
        }
        state = .present
    }

    private mutating func handleAdditionalViewer(t: Double, personCount: Int) -> [Effect] {
        guard config.additionalViewerEnabled,
              personCount >= config.additionalViewerMinPersons else {
            multiPersonStartTime = nil
            return []
        }

        if multiPersonStartTime == nil {
            multiPersonStartTime = t
            return []
        }
        guard let start = multiPersonStartTime,
              t - start >= config.additionalViewerSustainSeconds else {
            return []
        }

        state = .protected(since: t)
        multiPersonStartTime = nil
        return [.raiseCurtain, .logEvent(.additionalViewer)]
    }

    private mutating func startOrResetAdditionalViewer(t: Double, personCount: Int) {
        if config.additionalViewerEnabled,
           personCount >= config.additionalViewerMinPersons {
            multiPersonStartTime = t
        } else {
            multiPersonStartTime = nil
        }
    }

    private mutating func resetObservations() {
        detectionStatus = .unknown
        presenceCandidateStartTime = nil
        confirmedPresenceStartTime = nil
        lastPresentTime = nil
        absenceStartTime = nil
        multiPersonStartTime = nil
    }
}
