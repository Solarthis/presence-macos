# ACCEPTANCE — Tier-1 gate checks

Every check below must pass on this machine, with command + output pasted into TESTING.md,
before ANY Tier-2 work begins. Human-only checks are marked [HUMAN] and live in CHECKPOINT files.

A1. `./verify.sh` exits 0 from a clean checkout (build + Checks + purity/security gates).
A2. `./build.sh` produces a signed Presence.app; designated requirement is identity-based (not cdhash).
A3. `open Presence.app` shows the menu-bar item with visible state: MONITORING / PRESENT / GRACE
    (countdown) / PROTECTED / PAUSED / UNKNOWN-warning.
A4. First-run camera flow: permission request with honest one-line explanation; on denial the app
    stays alive in a visible "camera unavailable" state. [HUMAN clicks the dialog once]
A5. State machine scenario suite green in Checks (full list in Sources/Checks — walk-away, lean-away,
    UNKNOWN never triggers, cooldown, wake/display disarm, emergency-disable, hostile policies).
A6. Curtain covers every attached display at level .screenSaver; Esc-hold → auth prompt; visible
    Unlock button → LocalAuthentication; Cmd+Opt+Shift+Q quits; kill -9 while curtained → curtain gone.
A7. Curtain never appears within 30 s of launch nor before first confirmed PRESENT this process.
A8. Restore requires LAContext .deviceOwnerAuthentication success. [HUMAN performs one real Touch ID]
A9. Policy pipeline: all 9 validation steps; hostile fixtures rejected whole; preview + explicit
    approval before activation; bundled example policies flow through the identical path.
A10. Simulator mode replays fixture scenarios through the REAL state machine with on-screen HUD.
A11. Emergency disable: ~/.presence-disable or defaults flag → settings-only mode, curtain code never
     initialized (Checks case asserts this).
A12. Event log: closed schema only (eventType, timestamp ISO8601, policyId, confidenceBand enum,
     actionTaken, schemaVersion); ring buffer 1000/7d; Delete-all leaves store empty (Checks case).
A13. App fully functional with no network and no API key (Rung-2/template fallback path).
