# Fix spec — isolate production safety timing from simulator paths

## Defect
`RuntimeCoordinator.begin(source:)` hard-codes `MachineConfig(graceSeconds: 8,
launchGuardSeconds: 0, additionalViewerEnabled: true)` for EVERY source. The slice-3 spec
scoped that compressed timing to scripted demo scenarios only. As written, any future
production camera source wired through `start(source:)` would inherit zero launch guard and
the 8-second demo grace. This must become structurally impossible.

## Required changes (narrow — do not refactor anything else)

### 1. `Sources/PresenceCore/Constants.swift`
Add two named configs:

```swift
public extension MachineConfig {
    /// Production always derives from PresenceDefaults. Never accepts compressed timing.
    static var production: MachineConfig { MachineConfig() }
    /// Compressed timing for explicit DEBUG scripted runs only. Never used with a camera.
    static var scriptedDemo: MachineConfig {
        MachineConfig(graceSeconds: 8, launchGuardSeconds: 0, additionalViewerEnabled: true)
    }
}
```

### 2. `Sources/PresenceCore/LaunchOptions.swift` (new file, pure logic, no imports beyond Foundation)
```swift
public struct LaunchOptions {
    public let scenarioName: String?   // non-nil only if --simulate <name> present AND name is valid
    public let liveTestEnabled: Bool   // true only if --live-test present AND scenarioName != nil
    public var isProduction: Bool { scenarioName == nil }
    public init(arguments: [String], validScenarios: Set<String>)
}
```
Parsing: `scenarioName` = the argument following `--simulate` iff it is in `validScenarios`,
else nil. `liveTestEnabled` = `arguments.contains("--live-test") && scenarioName != nil`.

### 3. `Sources/Presence/RuntimeCoordinator.swift`
- `begin(source:)` becomes `begin(source:config:)` — no timing literals anywhere in this file.
- `start(source:)` (production entry: nil today, camera in slice 5) always passes
  `MachineConfig.production` to `begin`. It must be IMPOSSIBLE to reach `start(source:)`
  with any other config — do not add a config parameter to it.
- New `startScripted(scenario:)` — calls installObservers/startTickTimer then
  `begin(source: ScriptedSource(scenario: scenario), config: .scriptedDemo)`.
- `simulate(_:)` (menu DEBUG action) uses `.scriptedDemo` explicitly.

### 4. `Sources/Presence/PresenceApp.swift`
Build `LaunchOptions(arguments: CommandLine.arguments, validScenarios:
Set(ScriptedSource.Scenario.allCases.map(\.rawValue)))`. If `options.scenarioName` maps to a
Scenario → `runtime.startScripted(scenario:)`; otherwise `runtime.start(source: nil)`.
`liveTestEnabled` comes from `options.liveTestEnabled` (keep the existing comment about the
bypass being confined to explicit scripted DEBUG runs).

### 5. `Sources/Checks/SafetyConfigChecks.swift` (new) + call it from `main.swift`
Add checks (use the existing `check(_:_:)` helper):
- `production-launch-guard-at-least-thirty`: `MachineConfig.production.launchGuardSeconds >= 30`
- `production-grace-is-thirty`: `MachineConfig.production.graceSeconds == 30`
- `production-additional-viewer-off-by-default`: `MachineConfig.production.additionalViewerEnabled == false`
- `production-tracks-presence-defaults`: production equals a `MachineConfig()` built from defaults, field by field
- `demo-config-is-distinct-from-production`: scriptedDemo launch guard/grace differ from production
- `production-no-curtain-inside-launch-guard`: a Machine with `.production` fed
  detection(present)…absence…ticks entirely inside t < launchGuardSeconds never emits `.raiseCurtain`
- `production-arming-requires-confirmed-presence`: with `.production`, absence/tick events with
  NO prior confirmed presence never emit `.raiseCurtain` even after launch guard elapses
- `launch-options-empty-args-is-production`: `LaunchOptions(arguments: [], validScenarios: s).isProduction`
- `launch-options-live-test-alone-is-inert`: `["--live-test"]` → liveTestEnabled == false
- `launch-options-live-test-requires-valid-scenario`: `["--simulate","bogus","--live-test"]` → scenarioName == nil, liveTestEnabled == false
- `launch-options-simulate-plus-live-test-enables`: `["--simulate","walkAway","--live-test"]` with "walkAway" valid → both set
- `launch-options-simulate-missing-value-is-production`: `["--simulate"]` → isProduction

## Constraints
- No new dependencies. No changes to StateMachine.swift transition logic, AuthGate.swift,
  SafetyGates.swift, CurtainController.swift, EventStore.swift.
- `swift build && swift run Checks` must pass; report the full Checks summary line.
- Report a concise file-change summary when done.
