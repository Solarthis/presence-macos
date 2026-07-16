import PresenceCore

func runSafetyConfigChecks() {
    let production = MachineConfig.production
    let defaults = MachineConfig()

    check(
        production.launchGuardSeconds >= 30,
        "production-launch-guard-at-least-thirty"
    )
    check(production.graceSeconds == 30, "production-grace-is-thirty")
    check(
        production.additionalViewerEnabled == false,
        "production-additional-viewer-off-by-default"
    )
    check(
        production.graceSeconds == defaults.graceSeconds
            && production.presenceConfirmSeconds == defaults.presenceConfirmSeconds
            && production.armAfterPresenceSeconds == defaults.armAfterPresenceSeconds
            && production.cooldownSeconds == defaults.cooldownSeconds
            && production.launchGuardSeconds == defaults.launchGuardSeconds
            && production.additionalViewerEnabled == defaults.additionalViewerEnabled
            && production.additionalViewerMinPersons == defaults.additionalViewerMinPersons
            && production.additionalViewerSustainSeconds == defaults.additionalViewerSustainSeconds,
        "production-tracks-presence-defaults"
    )
    check(
        MachineConfig.scriptedDemo.launchGuardSeconds != production.launchGuardSeconds
            && MachineConfig.scriptedDemo.graceSeconds != production.graceSeconds,
        "demo-config-is-distinct-from-production"
    )

    var guardedMachine = Machine(config: .production, launchTime: 0)
    let guardedEffects = [
        guardedMachine.handle(.detection(t: 1, personCount: 1, band: .high)),
        guardedMachine.handle(.detection(t: 3, personCount: 1, band: .high)),
        guardedMachine.handle(.detection(t: 6, personCount: 1, band: .high)),
        guardedMachine.handle(.detection(t: 7, personCount: 0, band: .high)),
        guardedMachine.handle(.tick(t: 29.9)),
    ].flatMap { $0 }
    check(
        !guardedEffects.contains(.raiseCurtain),
        "production-no-curtain-inside-launch-guard"
    )

    var unconfirmedMachine = Machine(config: .production, launchTime: 0)
    let unconfirmedEffects = [
        unconfirmedMachine.handle(.detection(t: 31, personCount: 0, band: .high)),
        unconfirmedMachine.handle(.tick(t: 100)),
    ].flatMap { $0 }
    check(
        !unconfirmedEffects.contains(.raiseCurtain),
        "production-arming-requires-confirmed-presence"
    )

    let validScenarios: Set<String> = ["walkAway"]
    check(
        LaunchOptions(arguments: [], validScenarios: validScenarios).isProduction,
        "launch-options-empty-args-is-production"
    )
    check(
        LaunchOptions(arguments: ["--live-test"], validScenarios: validScenarios).liveTestEnabled == false,
        "launch-options-live-test-alone-is-inert"
    )

    let invalidLiveTest = LaunchOptions(
        arguments: ["--simulate", "bogus", "--live-test"],
        validScenarios: validScenarios
    )
    check(
        invalidLiveTest.scenarioName == nil && invalidLiveTest.liveTestEnabled == false,
        "launch-options-live-test-requires-valid-scenario"
    )

    let validLiveTest = LaunchOptions(
        arguments: ["--simulate", "walkAway", "--live-test"],
        validScenarios: validScenarios
    )
    check(
        validLiveTest.scenarioName == "walkAway" && validLiveTest.liveTestEnabled,
        "launch-options-simulate-plus-live-test-enables"
    )
    check(
        LaunchOptions(
            arguments: ["--simulate"],
            validScenarios: validScenarios
        ).isProduction,
        "launch-options-simulate-missing-value-is-production"
    )
}
