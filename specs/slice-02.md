# Slice 2 spec — pure presence state machine + Checks scenario suite

You are implementing ONE slice of the Presence macOS app. Read STATE.md and ACCEPTANCE.md
first. Work ONLY in `Sources/PresenceCore/` and `Sources/Checks/`. Do not touch any other
file. No new dependencies. No AVFoundation/Vision/AppKit/SwiftUI imports in PresenceCore
(verify.sh greps for this). When done, `swift build && swift run Checks` must exit 0.

## Design (follow exactly — boring and explicit)

`Sources/PresenceCore/Events.swift`
- `public enum ConfidenceBand: String, Codable { case low, medium, high }`
- `public enum PresenceEvent` with cases (all carrying `t: Double`, monotonic seconds supplied by caller):
  `detection(t: Double, personCount: Int, band: ConfidenceBand)`,
  `cameraUnavailable(t: Double)`, `cameraRestored(t: Double)`,
  `tick(t: Double)`  (periodic clock, ~1 Hz),
  `wake(t: Double)`, `displayChange(t: Double)`, `sessionActive(t: Double)`,
  `restoreAuthenticated(t: Double)` (LocalAuthentication succeeded),
  `pause(t: Double)`, `resume(t: Double)`, `manualProtect(t: Double)`.

`Sources/PresenceCore/StateMachine.swift`
- `public enum DetectionStatus { case present, absent, unknown }` — derived internally with
  hysteresis: PRESENT requires ≥ `Config.presenceConfirmSeconds` (2 s) of consecutive
  detections with personCount ≥ 1 and band != .low; ABSENT requires consecutive
  personCount == 0 (band != .low) — the state machine tracks the absence start time;
  any low-band detection or camera unavailability maps to UNKNOWN.
- `public enum PresenceState: Equatable` cases:
  `launchGuard` (initial — nothing may fire until 30 s after launch AND first confirmed present),
  `awaitingPresence` (armed only after ≥3 s confirmed presence),
  `present`, `grace(since: Double)`, `protected(since: Double)`,
  `cooldown(since: Double)`, `paused`, `unknownWarning`.
- `public enum Effect: Equatable` cases:
  `raiseCurtain`, `dismissCurtain`, `requestAuthUI`, `startGraceCountdown(seconds: Double)`,
  `cancelGraceCountdown`, `showUnknownWarning`, `clearUnknownWarning`,
  `logEvent(EventKind)` where `public enum EventKind: String, Codable` covers:
  presenceLost, graceStarted, curtainRaised, additionalViewer, restoreApproved,
  restoreRejected, cameraUnavailable, monitoringPaused, monitoringResumed.
- `public struct MachineConfig` with fields (defaults in Constants.swift):
  `graceSeconds` (default 30), `presenceConfirmSeconds` (2), `armAfterPresenceSeconds` (3),
  `cooldownSeconds` (60), `launchGuardSeconds` (30),
  `additionalViewerEnabled` (false for now), `additionalViewerMinPersons` (2),
  `additionalViewerSustainSeconds` (5).
- `public struct Machine` holding `state`, config, and minimal bookkeeping (launch time,
  last-present time, absence-start time, multi-person-start time, first-present-confirmed flag),
  with `public mutating func handle(_ event: PresenceEvent) -> [Effect]`.
  Keep it a deterministic pure value type — no Date(), no timers, no threads; ALL time comes
  from event timestamps.

### Hard behavioral rules (each one has at least one Check)
1. UNKNOWN never triggers protection: camera loss / low-band / zero-frame gaps produce
   `showUnknownWarning`, never `raiseCurtain`.
2. Nothing protective fires during `launchGuard`: neither before `launchGuardSeconds` has
   elapsed NOR before the first confirmed PRESENT of this process lifetime.
3. Walk-away requires an observed PRESENT→ABSENT transition while armed: after
   confirmed absence lasting `graceSeconds`, emit `raiseCurtain` + `logEvent(.curtainRaised)`.
   Absence shorter than grace → return to present, `cancelGraceCountdown`, no curtain.
4. `restoreAuthenticated` from `protected` → `cooldown`, emit `dismissCurtain`; during
   cooldown no protective action may fire even if zero-person detections arrive.
5. `wake`/`displayChange`/`sessionActive` from any non-paused state → `awaitingPresence`;
   arming requires ≥3 s confirmed presence; a stale "absent" inherited across these events
   never triggers.
6. `pause` → `paused` from any state (dismissing curtain if raised is NOT done here —
   pause during protected keeps the curtain; document in a comment); `resume` → `awaitingPresence`.
7. `manualProtect` → `protected` + `raiseCurtain` immediately (user-invoked, bypasses grace,
   still respects `paused`).
8. Additional viewer (config-gated): personCount ≥ minPersons sustained ≥ sustainSeconds
   while armed/present → `raiseCurtain` + `logEvent(.additionalViewer)`. Flicker below
   sustain → nothing.
9. A motionless user with steady detections stays `present` indefinitely (no motion logic).

`Sources/PresenceCore/Constants.swift` — all defaults with one-line comments naming why
each value was chosen.

`Sources/Checks/StateMachineChecks.swift` (called from main.swift; refactor main.swift so
suites register cleanly but KEEP the `check(_:_:)` style and the exit-code contract):
Scripted event sequences asserting the EXACT effect lists for every rule above, plus:
walk-away happy path; lean-away (absence < grace); low-confidence flicker; camera covered
mid-armed; second-person flicker below sustain; second person sustained; cooldown retrigger
attempt with zero frames after restore; wake with stale absence; manualProtect; pause/resume;
launch-guard violation attempts (early absence, absence-before-first-present).
Name every check clearly (e.g. "walkaway-raises-curtain-after-grace").

## Output contract
When finished, print a summary of files created/changed and the `swift run Checks` result.
