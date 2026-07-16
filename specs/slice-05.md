# Slice 5 spec — camera pipeline, Perception layer, HUD, simulator mode

Read STATE.md, ACCEPTANCE.md, and existing Sources/ first. Work in `Sources/Presence/`
(CameraSource, HUD, simulator UI) and `Sources/Checks/` (fixture suite ONLY — see below).
PresenceCore is FROZEN (no changes). No new dependencies. `swift build && swift run Checks`
and all verify.sh gates must stay green.

## CameraSource (`Sources/Presence/CameraSource.swift`)
- Conforms to `PresenceSource`. AVCaptureSession, preset .vga640x480.
- Device selection: AVCaptureDevice.DiscoverySession with deviceTypes
  `[.builtInWideAngleCamera]`, position .unspecified — NEVER .continuityCamera, NEVER
  .external ("Mike's iPhone Camera" must be impossible to bind).
- Permission: check AVCaptureDevice.authorizationStatus(for: .video); .notDetermined →
  requestAccess (the UI shows a one-sentence honest pre-prompt first — see First-run flow);
  .denied/.restricted → emit cameraUnavailable and set the honest UI state; NEVER loop retries.
- AVCaptureVideoDataOutput on a dedicated serial queue "com.solarthis.presence.camera";
  alwaysDiscardsLateVideoFrames = true; process at most 5 fps via timestamp-delta gate
  (drop frames, never queue). Main thread NEVER touched by the pipeline.
- Per processed frame: VNDetectFaceRectanglesRequest + VNDetectHumanRectanglesRequest on the
  same handler; personCount = max(faceCount, humanCount); band from the max observation
  confidence: <0.5 low, <0.8 medium, else high (constants with comments in Constants.swift
  app-side — do not touch PresenceCore/Constants.swift).
- Emit `detection(t: systemUptime, personCount:, band:)`.
- AVCaptureSession interruption / runtime error / device disconnect → `cameraUnavailable(t:)`;
  interruption ended → `cameraRestored(t:)`. Vision errors → treat as cameraUnavailable-grade
  UNKNOWN (never as absence).

## First-run flow (menu + PresenceApp wiring)
- Menu gains "Start Monitoring" when no camera grant yet: shows a small sheet: "Presence uses
  the camera locally to notice when you step away. No images ever leave this Mac." with
  [Enable camera] [Not now]. Enable → requestAccess → on grant, CameraSource becomes the
  active source (replacing the PAUSED placeholder state).
- On denial: menu state "camera unavailable — monitoring off", with "Open System Settings…"
  item (x-apple.systempreferences:com.apple.preference.security?Privacy_Camera). App never
  crashes, never re-prompts on its own.

## HUD (`Sources/Presence/HUDPanel.swift`)
- Non-activating floating NSPanel, small, top-right of the main screen, toggle via menu
  "Show Status HUD". Shows: state name (PRESENT / GRACE 00:05 / PROTECTED / UNKNOWN / PAUSED),
  live personCount and confidence band, and the active scenario name when the simulator runs.
- Purpose: on-camera cause→effect visibility for the demo video. Keep it legible at phone-camera
  distance (large type, high contrast, both light/dark).

## Simulator mode (product feature, not scaffolding)
- Menu "Simulator ▸" runs the ScriptedSource scenarios (walkAway, leanAway, secondViewer,
  cameraLoss) through the REAL Machine with the HUD forced visible and a small badge
  "SIMULATOR — scripted events, real state machine". While a scenario runs, the live camera
  source is paused and restored afterward. Works with network off and with no camera grant.

## Fixture capture (DEBUG, for Checkpoint 1)
- Menu "DEBUG ▸ Capture fixture frame" saves the CURRENT frame as PNG plus a sidecar JSON
  {faces, humans, band} into `fixtures/` in the repo working directory ONLY when launched with
  `--fixture-capture` (so a shipped build cannot write frames at all — privacy invariant).
- fixtures/ is gitignored: face-containing images NEVER enter the public repo. Add
  `fixtures/` to .gitignore in this slice.

## Checks addition (`Sources/Checks/FixtureVisionChecks.swift`)
- Checks MAY import Vision/AppKit (the purity gate only guards PresenceCore).
- If `fixtures/` contains empty-room.png / one-person.png / two-people.png (+ sidecars), run
  both Vision requests on each and assert personCount 0 / 1 / ≥2 respectively; otherwise print
  "SKIP fixture-vision (no fixtures captured yet)" and do not fail.

## Verification contract
1. `swift build && swift run Checks` green (fixture suite SKIPs cleanly pre-Checkpoint-1).
2. With no camera grant: app launches into the honest "camera unavailable/monitoring off"
   state — no crash, no prompt loop (I can verify pre-grant behavior myself).
3. Simulator scenarios drive the HUD + curtain end-to-end with no camera and no network.
4. After the human grants camera at Checkpoint 1, live detection events appear in the HUD and
   events.jsonl within seconds of launch via `open`.

Print a file-by-file summary when done.
