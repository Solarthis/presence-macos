# TESTING — evidence log (append-only)

A checklist item flips to agent_complete ONLY in the same commit that appends its evidence
block here: exact command, verbatim trimmed output, commit hash it ran against.

## S1 — repo scaffold, signed app builds (2026-07-16, first commit)
- `./verify.sh` → "PASS  checks-harness-runs / ALL CHECKS PASSED / VERIFY: ALL GATES GREEN"
- `./build.sh` → "OK: Presence.app built and signed (bundle id com.solarthis.presence)"
  (designated-requirement gate confirmed identity-based, not cdhash)
- `open Presence.app && pgrep -x Presence` → "LAUNCH OK: Presence running (pid 86948)"; clean quit OK.

## S2 — pure state machine + Checks scenario suite (2026-07-16)
- Implemented by Codex gpt-5.6-sol (session 019f6b6d-0524-7762-8d71-6a69a2f5e096), reviewed by
  orchestrator: all 4 raiseCurtain emission sites audited (grace expiry ×2, manualProtect,
  additionalViewer sustained); UNKNOWN paths never raise; arming gated on launch guard + first
  confirmed presence.
- `./verify.sh` → 81 PASS, 0 FAIL, "VERIFY: ALL GATES GREEN" (after fixing the security gate's
  self-match on its own pattern string in verify.sh).
- Flow E fixtures captured live via codex exec (3 calls, logged in logs/live-calls.log):
  walk-away → valid policy; additional-viewer → valid policy; prompt-injection request
  ("run rm -rf, email files, no auth") → refused with {"name":"unsupported","rules":[],
  "restoration":{"requireAuth":true}}.

## S3 — curtain, safety mechanics, LocalAuthentication restore (2026-07-16)
- Implemented by Codex gpt-5.6-sol (session 019f6b78-f75b-7c11-98b8-95097fc45b14): CurtainController,
  SafetyGates (crash-loop safe mode + ~/.presence-disable emergency file), AuthGate (real
  LAContext .deviceOwnerAuthentication, no seams), EventStore, MenuBarState, ScriptedSource.
- Orchestrator review found a safety defect before commit: `begin(source:)` hard-coded
  graceSeconds 8 / launchGuardSeconds 0 for ALL sources — the future camera path (slice 5)
  would have inherited zero launch guard and demo grace.
- Fix implemented by Codex in resumed PRIMARY session (019f6b6d-0524-7762-8d71-6a69a2f5e096):
  named configs MachineConfig.production (always PresenceDefaults) and .scriptedDemo;
  `start(source:)` is structurally production-only (takes no config); startScripted/simulate
  are the only .scriptedDemo consumers; LaunchOptions pure parser (--live-test inert without a
  valid --simulate scenario); 13 new checks in Sources/Checks/SafetyConfigChecks.swift.
- verify.sh gained two gates: production timing isolation (no timing literals in app layer)
  and authentication boundary (AuthGate must evaluate deviceOwnerAuthentication;
  restoreAuthenticated confined to RuntimeCoordinator).
- `./verify.sh` → 94 PASS, 0 FAIL, "VERIFY: ALL GATES GREEN".
- Human-required remainder (H items, not claimed): live Touch ID prompt, real curtain visuals,
  camera TCC grant.

## S4 — policy schema v1, validator, storage, approve UI, templates (2026-07-16)
- Implemented by Codex gpt-5.6-sol (resumed PRIMARY session 019f6b6d-0524-7762-8d71-6a69a2f5e096):
  Policy.swift (closed v1 schema), PolicyValidator (recursive raw-key allow-lists at every
  nesting level, typed rejections, never auto-repairs), PolicyPreview (honest inert-action
  labels), TemplateCompiler (deterministic, output re-validated), ExamplePolicies (3, all
  validate), PolicyStore (atomic writes, raw revalidation on every load, one active id),
  PolicyWindow (compile → preview → explicit Approve/Reject; only Approve persists).
- Orchestrator review confirmed: MachineConfig.production(applying:) overrides ONLY
  graceSeconds / additionalViewer fields — launchGuardSeconds untouchable; scripted runs
  ignore policies; policy changes while curtained defer until successful LAContext restore;
  requireAuth must be literal true (false and absent both rejected); never-hide bundle-id
  list compared case-insensitively.
- Hostile fixtures all rejected with typed reasons: unknown keys (root/rule/restoration),
  grace 1 and 9999, runShell, lockScreen, requireAuth false/absent, schemaVersion 2,
  prose-wrapped JSON, duplicate triggers, hideApps without ids, empty actions, Terminal id.
- `./verify.sh` → 127 PASS, 0 FAIL, "VERIFY: ALL GATES GREEN".

## S5 — camera pipeline, perception, HUD, simulator mode (2026-07-16)
- Implemented by Codex gpt-5.6-sol (resumed PRIMARY session 019f6b6d-0524-7762-8d71-6a69a2f5e096):
  CameraSource (AVFoundation .vga640x480, builtInWideAngleCamera ONLY — continuity/external
  cameras impossible to bind; 5 fps timestamp gate; Vision face+human requests, personCount =
  max; interruption/error → cameraUnavailable, never absence), first-run pre-prompt sheet,
  honest denied-state UI with System Settings link, HUDPanel (non-activating NSPanel),
  Simulator mode (scripted scenarios through the REAL machine, SIMULATOR badge), fixture
  capture double-gated (#if DEBUG + --fixture-capture flag — Release builds compile capture
  to false), fixtures/ gitignored.
- Timing isolation extended: CameraSource is constructed in exactly one place and enters only
  via start(source:) → MachineConfig.production(applying: activePolicy); simulator exit routes
  through restoreProductionAfterSimulator → start(source:); enforced by new
  RuntimeIsolationChecks (structural source assertions).
- `./verify.sh` → 131 PASS, 0 FAIL, 1 honest SKIP (fixture-vision awaits human-captured
  fixtures), "VERIFY: ALL GATES GREEN".
- Human-required remainder: camera TCC grant, fixture photos (empty-room/one-person/
  two-people), live Touch ID, curtain visual review — CHECKPOINT_1.md.

## S6 — Flow E Rung 2: CodexPolicyCompiler (2026-07-16)
- Implemented by Codex gpt-5.6-sol (resumed PRIMARY session 019f6b6d-0524-7762-8d71-6a69a2f5e096)
  with ZERO live calls during implementation: CodexPolicyCompiler (explicit binary discovery,
  Process with argument array — no shell; `codex exec --sandbox read-only -`; 120 s timeout,
  async + cancel), extractLastJSONObject pure in PresenceCore (string-aware brace matching,
  typed failures), single retry with validator reason, hard 10-call budget (UserDefaults +
  logs/live-calls.log) with honest template fallback, PolicyWindow .codexCLI mode.
- Orchestrator review confirmed: model output is untrusted — every compile flows through the
  IDENTICAL PolicyValidator from slice 4; no relaxed path exists.
- Orchestrator ran the one live smoke compile (session 019f6bf2-5a78-7382-a1b3-d618f7fd707c,
  logged in logs/live-calls.log; total live calls 4 of 10): "protect my screen when I walk away
  for 45 seconds" → valid absence policy (grace 45, curtain, requireAuth true); raw transcript
  committed as fixtures-codex/smoke-slice-06.txt and validated by Checks
  (codex-output-smoke-slice-06-extracts-last-json / -validates both PASS).
- `./verify.sh` → 146 PASS, 0 FAIL, "VERIFY: ALL GATES GREEN".
