import PresenceCore

private func expectEffects(_ actual: [Effect], _ expected: [Effect], _ name: String) {
    check(actual == expected, name)
}

private func makeArmedMachine(config: MachineConfig = MachineConfig()) -> Machine {
    var machine = Machine(config: config, launchTime: 0)
    precondition(machine.handle(.detection(t: 30, personCount: 1, band: .medium)) == [])
    precondition(machine.handle(.detection(t: 32, personCount: 1, band: .medium)) == [])
    precondition(machine.handle(.detection(t: 35, personCount: 1, band: .medium)) == [])
    precondition(machine.state == .present)
    return machine
}

private func walkAwayHappyPath() {
    var machine = makeArmedMachine()

    expectEffects(
        machine.handle(.detection(t: 36, personCount: 0, band: .high)),
        [
            .logEvent(.presenceLost),
            .startGraceCountdown(seconds: 30),
            .logEvent(.graceStarted),
        ],
        "walkaway-starts-grace-with-exact-effects"
    )
    expectEffects(
        machine.handle(.tick(t: 65.9)),
        [],
        "walkaway-does-not-raise-before-grace"
    )
    expectEffects(
        machine.handle(.tick(t: 66)),
        [.raiseCurtain, .logEvent(.curtainRaised)],
        "walkaway-raises-curtain-after-grace"
    )
    check(machine.state == .protected(since: 66), "walkaway-enters-protected")
}

private func leanAwayReturnsToPresent() {
    var machine = makeArmedMachine()

    _ = machine.handle(.detection(t: 36, personCount: 0, band: .medium))
    expectEffects(
        machine.handle(.detection(t: 50, personCount: 1, band: .medium)),
        [.cancelGraceCountdown],
        "lean-away-cancels-grace-with-exact-effects"
    )
    check(machine.state == .present, "lean-away-returns-to-present")
    expectEffects(
        machine.handle(.tick(t: 100)),
        [],
        "lean-away-never-raises-curtain"
    )
}

private func lowConfidenceNeverProtects() {
    var machine = makeArmedMachine()

    expectEffects(
        machine.handle(.detection(t: 36, personCount: 0, band: .low)),
        [.showUnknownWarning],
        "low-confidence-flicker-shows-warning-only"
    )
    check(machine.state == .unknownWarning, "low-confidence-enters-unknown-warning")
    expectEffects(
        machine.handle(.tick(t: 200)),
        [],
        "low-confidence-flicker-never-protects"
    )
    expectEffects(
        machine.handle(.detection(t: 201, personCount: 1, band: .high)),
        [.clearUnknownWarning],
        "confident-frame-clears-low-confidence-warning"
    )
    check(machine.state == .awaitingPresence, "unknown-recovery-requires-rearming")
}

private func cameraCoveredMidArmedNeverProtects() {
    var machine = makeArmedMachine()

    expectEffects(
        machine.handle(.cameraUnavailable(t: 36)),
        [.showUnknownWarning, .logEvent(.cameraUnavailable)],
        "camera-covered-shows-warning-and-logs"
    )
    check(machine.state == .unknownWarning, "camera-covered-enters-unknown-warning")
    expectEffects(
        machine.handle(.tick(t: 200)),
        [],
        "camera-covered-never-raises-curtain"
    )
    expectEffects(
        machine.handle(.cameraRestored(t: 201)),
        [.clearUnknownWarning],
        "camera-restored-clears-warning"
    )
    check(machine.state == .awaitingPresence, "camera-restored-requires-rearming")
}

private func uncertaintyCancelsActiveGrace() {
    var machine = makeArmedMachine()
    _ = machine.handle(.detection(t: 36, personCount: 0, band: .high))

    expectEffects(
        machine.handle(.cameraUnavailable(t: 40)),
        [
            .cancelGraceCountdown,
            .showUnknownWarning,
            .logEvent(.cameraUnavailable),
        ],
        "camera-loss-cancels-grace-with-exact-effects"
    )
    expectEffects(
        machine.handle(.tick(t: 100)),
        [],
        "unknown-after-grace-never-protects"
    )
}

private func launchGuardBlocksAutomaticProtection() {
    var earlyAbsence = Machine(launchTime: 0)
    expectEffects(
        earlyAbsence.handle(.detection(t: 1, personCount: 0, band: .high)),
        [],
        "launch-guard-early-absence-has-no-effects"
    )
    expectEffects(
        earlyAbsence.handle(.tick(t: 100)),
        [],
        "launch-guard-early-absence-never-protects"
    )
    check(earlyAbsence.state == .launchGuard, "launch-guard-waits-for-first-present")

    var earlyPresentThenAbsent = Machine(launchTime: 0)
    expectEffects(
        earlyPresentThenAbsent.handle(.detection(t: 1, personCount: 1, band: .medium)),
        [],
        "launch-guard-first-presence-candidate-is-inert"
    )
    expectEffects(
        earlyPresentThenAbsent.handle(.detection(t: 3, personCount: 1, band: .medium)),
        [],
        "launch-guard-confirmed-presence-is-inert-before-thirty-seconds"
    )
    expectEffects(
        earlyPresentThenAbsent.handle(.detection(t: 10, personCount: 0, band: .medium)),
        [],
        "launch-guard-early-present-to-absent-is-inert"
    )
    expectEffects(
        earlyPresentThenAbsent.handle(.tick(t: 100)),
        [],
        "launch-guard-violation-attempt-never-protects"
    )

    var absentBeforeFirstPresent = Machine(launchTime: 0)
    expectEffects(
        absentBeforeFirstPresent.handle(.wake(t: 31)),
        [],
        "wake-enters-awaiting-without-effects"
    )
    expectEffects(
        absentBeforeFirstPresent.handle(.detection(t: 32, personCount: 0, band: .high)),
        [],
        "absence-before-first-present-is-inert"
    )
    expectEffects(
        absentBeforeFirstPresent.handle(.tick(t: 100)),
        [],
        "absence-before-first-present-never-protects"
    )
    check(absentBeforeFirstPresent.state == .awaitingPresence, "first-present-gate-remains-disarmed")
}

private func cooldownBlocksRetrigger() {
    var machine = makeArmedMachine()
    _ = machine.handle(.manualProtect(t: 36))

    expectEffects(
        machine.handle(.restoreAuthenticated(t: 40)),
        [.dismissCurtain, .logEvent(.restoreApproved)],
        "restore-authenticated-dismisses-and-logs"
    )
    check(machine.state == .cooldown(since: 40), "restore-enters-cooldown")
    expectEffects(
        machine.handle(.detection(t: 41, personCount: 0, band: .high)),
        [],
        "cooldown-zero-frame-has-no-effects"
    )
    expectEffects(
        machine.handle(.detection(t: 99.9, personCount: 0, band: .high)),
        [],
        "cooldown-zero-frames-never-retrigger"
    )
    expectEffects(
        machine.handle(.detection(t: 100, personCount: 0, band: .high)),
        [],
        "cooldown-expiry-with-absence-stays-disarmed"
    )
    check(machine.state == .awaitingPresence, "cooldown-expiry-requires-rearming")
}

private func environmentalEventsDiscardStaleAbsence() {
    var wakeMachine = makeArmedMachine()
    _ = wakeMachine.handle(.detection(t: 36, personCount: 0, band: .high))
    expectEffects(
        wakeMachine.handle(.wake(t: 40)),
        [.cancelGraceCountdown],
        "wake-cancels-stale-grace"
    )
    expectEffects(
        wakeMachine.handle(.tick(t: 100)),
        [],
        "wake-with-stale-absence-never-protects"
    )
    check(wakeMachine.state == .awaitingPresence, "wake-requires-confirmed-rearming")

    expectEffects(
        wakeMachine.handle(.detection(t: 101, personCount: 1, band: .high)),
        [],
        "wake-rearm-first-detection-is-inert"
    )
    expectEffects(
        wakeMachine.handle(.detection(t: 103, personCount: 1, band: .high)),
        [],
        "wake-rearm-presence-confirmation-is-inert"
    )
    expectEffects(
        wakeMachine.handle(.detection(t: 105.9, personCount: 1, band: .high)),
        [],
        "wake-rearm-waits-full-three-confirmed-seconds"
    )
    check(wakeMachine.state == .awaitingPresence, "wake-not-armed-too-early")
    expectEffects(
        wakeMachine.handle(.detection(t: 106, personCount: 1, band: .high)),
        [],
        "wake-rearm-at-three-confirmed-seconds-has-no-effects"
    )
    check(wakeMachine.state == .present, "wake-arms-after-three-confirmed-seconds")

    var displayMachine = makeArmedMachine()
    expectEffects(
        displayMachine.handle(.displayChange(t: 36)),
        [],
        "display-change-disarms-with-no-effects"
    )
    check(displayMachine.state == .awaitingPresence, "display-change-requires-rearming")

    var sessionMachine = makeArmedMachine()
    expectEffects(
        sessionMachine.handle(.sessionActive(t: 36)),
        [],
        "session-active-disarms-with-no-effects"
    )
    check(sessionMachine.state == .awaitingPresence, "session-active-requires-rearming")
}

private func pauseResumeAndManualProtect() {
    var manual = makeArmedMachine()
    expectEffects(
        manual.handle(.manualProtect(t: 36)),
        [.raiseCurtain, .logEvent(.curtainRaised)],
        "manual-protect-raises-immediately"
    )
    check(manual.state == .protected(since: 36), "manual-protect-enters-protected")

    expectEffects(
        manual.handle(.pause(t: 37)),
        [.logEvent(.monitoringPaused)],
        "pause-while-protected-does-not-dismiss-curtain"
    )
    check(manual.state == .paused, "pause-enters-paused")
    expectEffects(
        manual.handle(.manualProtect(t: 38)),
        [],
        "manual-protect-respects-paused"
    )
    expectEffects(
        manual.handle(.resume(t: 39)),
        [.logEvent(.monitoringResumed)],
        "resume-logs-with-exact-effects"
    )
    check(manual.state == .awaitingPresence, "resume-requires-rearming")
    expectEffects(
        manual.handle(.detection(t: 40, personCount: 0, band: .high)),
        [],
        "resume-stale-absence-is-inert"
    )
}

private func additionalViewerScenarios() {
    var disabled = makeArmedMachine()
    expectEffects(
        disabled.handle(.detection(t: 36, personCount: 2, band: .high)),
        [],
        "additional-viewer-disabled-first-frame-is-inert"
    )
    expectEffects(
        disabled.handle(.detection(t: 50, personCount: 2, band: .high)),
        [],
        "additional-viewer-disabled-stays-inert"
    )
    check(disabled.state == .present, "additional-viewer-feature-is-config-gated")

    let enabledConfig = MachineConfig(additionalViewerEnabled: true)
    var flicker = makeArmedMachine(config: enabledConfig)
    expectEffects(
        flicker.handle(.detection(t: 36, personCount: 2, band: .high)),
        [],
        "second-person-flicker-start-is-inert"
    )
    expectEffects(
        flicker.handle(.detection(t: 40.9, personCount: 1, band: .high)),
        [],
        "second-person-flicker-below-sustain-is-inert"
    )
    expectEffects(
        flicker.handle(.tick(t: 100)),
        [],
        "second-person-flicker-never-protects"
    )
    check(flicker.state == .present, "second-person-flicker-stays-present")

    var sustained = makeArmedMachine(config: enabledConfig)
    expectEffects(
        sustained.handle(.detection(t: 36, personCount: 2, band: .medium)),
        [],
        "second-person-sustain-start-is-inert"
    )
    expectEffects(
        sustained.handle(.detection(t: 41, personCount: 2, band: .medium)),
        [.raiseCurtain, .logEvent(.additionalViewer)],
        "second-person-sustained-raises-curtain"
    )
    check(sustained.state == .protected(since: 41), "second-person-sustained-enters-protected")
}

private func motionlessPresenceAndFrameGapsStaySafe() {
    var machine = makeArmedMachine()

    expectEffects(
        machine.handle(.tick(t: 500)),
        [],
        "zero-frame-gap-does-not-imply-absence"
    )
    check(machine.state == .present, "zero-frame-gap-stays-present")
    expectEffects(
        machine.handle(.detection(t: 1_000, personCount: 1, band: .medium)),
        [],
        "motionless-steady-detection-at-long-interval-is-inert"
    )
    expectEffects(
        machine.handle(.detection(t: 10_000, personCount: 1, band: .high)),
        [],
        "motionless-user-stays-present-indefinitely"
    )
    check(machine.state == .present, "motionless-user-remains-present")
}

private func defaultConfigurationIsExact() {
    let config = MachineConfig()
    check(config.graceSeconds == 30, "default-grace-is-thirty-seconds")
    check(config.presenceConfirmSeconds == 2, "default-presence-confirm-is-two-seconds")
    check(config.armAfterPresenceSeconds == 3, "default-arm-delay-is-three-seconds")
    check(config.cooldownSeconds == 60, "default-cooldown-is-sixty-seconds")
    check(config.launchGuardSeconds == 30, "default-launch-guard-is-thirty-seconds")
    check(config.additionalViewerEnabled == false, "default-additional-viewer-is-disabled")
    check(config.additionalViewerMinPersons == 2, "default-additional-viewer-minimum-is-two")
    check(config.additionalViewerSustainSeconds == 5, "default-additional-viewer-sustain-is-five-seconds")
}

func runStateMachineChecks() {
    defaultConfigurationIsExact()
    walkAwayHappyPath()
    leanAwayReturnsToPresent()
    lowConfidenceNeverProtects()
    cameraCoveredMidArmedNeverProtects()
    uncertaintyCancelsActiveGrace()
    launchGuardBlocksAutomaticProtection()
    cooldownBlocksRetrigger()
    environmentalEventsDiscardStaleAbsence()
    pauseResumeAndManualProtect()
    additionalViewerScenarios()
    motionlessPresenceAndFrameGapsStaySafe()
}
