# Fix spec — confine live-test to its session phase; honest displaysOff preview

Independent review confirmed two defects. Patch narrowly.

## Defect 1 (high): live-test auth bypass survives into real camera monitoring
`--simulate <scenario> --live-test` → scenario ends → restoreProductionAfterSimulator →
startCameraMonitoring() starts a REAL CameraSource in the same session, while
`liveTestEnabled` (set once in init, never cleared) keeps arming the 10 s auto-dismiss on
EVERY subsequent .raiseCurtain (RuntimeCoordinator.swift:267 → 363-374) — genuine
production curtains dismiss via synthetic .restoreAuthenticated with no LocalAuthentication.
Also: the path is not #if DEBUG gated, so `swift build -c release` binaries honor it,
contradicting the PresenceApp.swift:21-22 comment.

### Required changes
1. `Sources/Presence/RuntimeCoordinator.swift` — a live-test session may NEVER bind the
   camera: in `startCameraMonitoring()`, `guard !liveTestEnabled else { start(source: nil); return }`
   (live-test sessions end in the paused no-camera state; menu keeps the " — LIVE TEST" label).
   The auto-dismiss behavior itself stays — the directive REQUIRES live-test to auto-dismiss
   any real curtain (e.g. manual Protect Now during a live test) so an unattended test can
   never lock the machine. The defect is only the camera transition.
2. `Sources/Presence/PresenceApp.swift` — gate the flag at compile time:
   ```swift
   #if DEBUG
   let liveTestEnabled = options.liveTestEnabled
   #else
   let liveTestEnabled = false
   #endif
   ```
   and rewrite the comment to state what is now true: DEBUG builds only, requires both
   flags, and a live-test session can never enter camera monitoring.
3. `Sources/Checks/RuntimeIsolationChecks.swift` — add structural checks:
   - `live-test-session-never-binds-camera`: startCameraMonitoring's block contains the
     liveTestEnabled guard before constructing CameraSource.
   - `live-test-flag-is-debug-gated`: PresenceApp.swift contains the #if DEBUG gate around
     the liveTestEnabled assignment.

## Defect 2 (high, honesty): PolicyPreview labels displaysOff as inert while the executor is live
Slice 7 shipped DisplaysOffExecutor but the slice-4 preview still appends
" (not active in this build yet)" to displaysOff lines.

### Required changes
4. `Sources/PresenceCore/PolicyPreview.swift` — displaysOff line becomes honest and exact:
   "Turn off displays (requires the 'Allow turning displays off' setting; your Mac locks
   only if 'Require password immediately' is enabled)". hideApps keeps its
   "(not active in this build yet)" suffix — it IS still inert.
5. Update/add checks: preview output for a displaysOff policy contains the new wording and
   does NOT contain "not active in this build yet"; hideApps preview still does.

## Constraints
- No other refactors. PresenceCore frozen except PolicyPreview.swift.
- Do not weaken any existing check or verify.sh gate; timing isolation untouched.
- `swift build && swift run Checks` green; report results + file-change summary.
