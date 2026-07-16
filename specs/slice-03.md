# Slice 3 spec — curtain, safety mechanics, LocalAuthentication restore

Read STATE.md, ACCEPTANCE.md, and Sources/PresenceCore/ first (the state machine API from
slice 2 is the contract — consume it, do not modify PresenceCore). Work ONLY in
`Sources/Presence/`. No new dependencies. `swift build && swift run Checks` must stay green.

## Components (boring, explicit)

`Sources/Presence/PresenceSource.swift`
- `protocol PresenceSource: AnyObject { func start(emit: @escaping (PresenceEvent) -> Void); func stop() }`
  — this is the project's ONE allowed protocol-with-multiple-conformers.
- `final class ScriptedSource: PresenceSource` — replays named fixture scenarios as timed
  event sequences (real wall-clock pacing, timestamps from ProcessInfo.processInfo.systemUptime):
  `walkAway` (present 5 s → absent → grace → curtain), `leanAway` (present 5 s → absent 3 s →
  present), `secondViewer` (present → 2 persons sustained), `cameraLoss` (present → cameraUnavailable).
  Grace for scripted scenarios: use a 8 s override config so demos are watchable.

`Sources/Presence/RuntimeCoordinator.swift`
- Owns `Machine` (PresenceCore), the active `PresenceSource`, and a 1 Hz tick timer feeding
  `tick(t:)` events. All time = `ProcessInfo.processInfo.systemUptime`.
- Subscribes NSWorkspace.didWakeNotification, screensDidWakeNotification,
  sessionDidBecomeActiveNotification + NSApplication.didChangeScreenParametersNotification →
  forwards wake/displayChange/sessionActive events to the machine.
- Executes effects: raiseCurtain/dismissCurtain → CurtainController; requestAuthUI → auth flow;
  grace countdown + unknown warning → MenuBarState; logEvent → EventStore.

`Sources/Presence/CurtainController.swift`
- One borderless NSWindow per NSScreen at `NSWindow.Level.screenSaver`,
  `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`,
  NSVisualEffectView (hudWindow material) full-bleed, SF Symbol lock icon, title
  "Presence protected this workspace", subtitle "Unlock with Touch ID or your password",
  a prominent Unlock button, and a small hint line "Hold Esc to unlock · ⌘⌥⇧Q quits Presence".
- Re-covers screens on display reconfiguration while raised.
- FORBIDDEN (acceptance-blocking): CGDisplayCapture/CGCaptureAllDisplays, CGEventTap,
  secure input mode, any NSApplication.presentationOptions.
- Key handling via the curtain window's own keyDown/flagsChanged (local, in-process only):
  Esc held 3 s → auth flow; Cmd+Opt+Shift+Q → NSApp.terminate(nil).

`Sources/Presence/AuthGate.swift`
- `LAContext().evaluatePolicy(.deviceOwnerAuthentication, ...)` (NEVER biometrics-only).
- Success → post `restoreAuthenticated(t:)` to the coordinator.
- Track consecutive LAError SYSTEM failures (not .userCancel / .authenticationFailed);
  after 3, surface a Quit button directly on the curtain.

`Sources/Presence/EventStore.swift`
- Append-only JSONL at ~/Library/Application Support/Presence/events.jsonl.
- Closed record: {eventType (EventKind rawValue), timestamp ISO8601, policyId (String?),
  confidenceBand (String?), actionTaken (String?), schemaVersion 1}. NOTHING else — no window
  titles, paths, images, bounding boxes, usernames. Ring buffer: rewrite file when >1000 lines,
  drop entries older than 7 days on launch. `deleteAll()` empties the file.

`Sources/Presence/SafetyGates.swift` + wiring in `PresenceApp.swift`
- FIRST thing at launch (before any source/curtain init): if
  `UserDefaults.standard.bool(forKey: "emergencyDisabled")` under suite of the app OR
  FileManager exists `~/.presence-disable` → SAFE MODE: menu bar shows "Presence — safe mode
  (disabled)", only Settings/Quit menu items, detection and curtain classes are never
  instantiated.
- Crash-loop breaker: marker file in Application Support written at launch, removed in
  applicationWillTerminate; keep last-3 unclean timestamps; 3 unclean exits within 5 min →
  SAFE MODE with notice "Presence started in safe mode after repeated crashes".
- Protected/curtain state is NEVER persisted; machine always constructed fresh (launchGuard).

`Sources/Presence/MenuBarState.swift` + rework `PresenceApp.swift`
- MenuBarExtra shows state icon + text: MONITORING / PRESENT / GRACE (live countdown seconds) /
  PROTECTED / PAUSED / UNKNOWN ("camera unavailable — monitoring suspended").
- Menu items: Pause/Resume monitoring; Protect Now (manualProtect); Simulate ▸ (walkAway,
  leanAway, secondViewer, cameraLoss — each labeled "DEBUG"); Quit Presence.
- Without a camera source (until slice 5) the default state is PAUSED with text
  "monitoring off — camera pipeline not yet installed".

## Command-line arguments (parsed in PresenceApp/AppDelegate)
- `--simulate <scenario>`: start the named ScriptedSource scenario immediately at launch.
- `--live-test`: any raised curtain auto-dismisses after 10 s (bypasses auth, logs
  restoreApproved with actionTaken "live-test-autodismiss"). This flag exists so an automated
  agent can test on the machine it is running on; it is DEBUG-only and must be stated in the
  menu bar text while active.

## Verification contract (I will run these; make them true)
1. `swift build && swift run Checks` green; verify.sh gates green (no forbidden symbols).
2. `open Presence.app --args --simulate walkAway --live-test` → within ~25 s
   events.jsonl gains graceStarted → curtainRaised → restoreApproved(live-test-autodismiss),
   and the process is still alive with no curtain visible.
3. `open Presence.app --args --simulate leanAway --live-test` → NO curtainRaised in events.jsonl.
4. kill -9 while curtained (I run this manually) leaves no residual screen state.

Print a file-by-file summary when done.
