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

## S7 — additional-viewer UI, displaysOff, Flow F, event history (2026-07-16)
- Implemented by Codex gpt-5.6-sol (resumed PRIMARY session 019f6b6d-0524-7762-8d71-6a69a2f5e096):
  additional-viewer curtain title swap + HUD accent (config wiring existed since slice 4);
  DisplaysOffExecutor double-gated (policy action AND default-OFF "Allow turning displays off"
  toggle; absolute /usr/bin/pmset path; honest lock-caveat copy; executor retained on attempt
  3 of 3); Flow F "Explain recent events…" — sanitized payload from the typed record struct in
  pure PresenceCore (closed fields, policy names replace ids, hostile extra fields structurally
  impossible), "What will be sent" preview with explicit Send, shared 10-call budget, response
  display-only; Event History window + Delete All wired to EventStore.deleteAll() with
  empty-store check; onboarding (7.4) honestly skipped per cut ladder after displaysOff
  consumed the attempt budget.
- App hiding remains CUT (D7) — structural check added.
- `./verify.sh` → 169 PASS, 0 FAIL, 1 honest SKIP; signed Presence.app builds.

## Corrections (2026-07-16, from the independent review — this log is append-only)
- S3 evidence overcounts: the S3 block claims "94 PASS" and "13 new checks"; re-running
  `swift run Checks` at the slice-3 commit (cee9225) yields 93 PASS and 12 new safety
  checks. The counting error was the orchestrator's (off by one, harness line double-counted);
  the checks themselves are as described. Later counts (127/131/146/169) re-verified correct.
- Evidence citations: logs/*.log (Codex transcripts, live-call ledger) are local working
  files and are NOT published in the repo (logs/ is gitignored) — except
  logs/live-calls.log, now tracked as the live-call ledger. Codex Session IDs remain
  recorded in CODEX_SESSIONS.md itself; fixtures-codex/*.txt (tracked) carry session ids
  in their headers.

## Fix — live-test confinement + honest displaysOff preview (2026-07-16)
- Independent 4-dimension review (24 agents, adversarial verification) confirmed: the
  --live-test auto-dismiss survived simulator exit into REAL camera monitoring (10 s
  no-auth curtain dismissal for the rest of the session), and release builds honored the
  flag; also PolicyPreview still labeled displaysOff inert after slice 7 shipped the executor.
- Fix (Codex, resumed PRIMARY session): startCameraMonitoring() refuses to bind a camera in
  a live-test session (falls to paused no-camera); liveTestEnabled is #if DEBUG-gated
  (release binaries ignore the flag); displaysOff preview wording now honest and exact;
  hideApps stays labeled inert. New structural checks:
  live-test-session-never-binds-camera, live-test-flag-is-debug-gated, preview assertions.
- Review also confirmed two documentation defects, corrected above (S3 count correction;
  gitignored-evidence citations; logs/live-calls.log now tracked).
- `./verify.sh` → 173 PASS, 0 FAIL, "VERIFY: ALL GATES GREEN" (count re-run after writing
  this block, per the correction discipline above).

## S8 — reviews, docs, release preparation (2026-07-16)
- Independent review: 4-dimension / 24-agent adversarial workflow — 5 confirmed findings,
  all fixed (live-test confinement, honest displaysOff preview, S3 count correction,
  evidence-citation fixes); 5 candidate findings refuted with code evidence.
- Docs written from code: README.md, PRIVACY.md, SECURITY.md, docs/architecture.md,
  SUBMISSION.md (Devpost copy, demo shot list, human checklist).
- Full-history secret scan: CLEAN. No images/cert material tracked. License verified (MIT).
- Release artifact: dist/Presence-v1.0.0-macos-arm64.zip,
  SHA-256 0d50ad8b99c0990ecc1e7cd6dfc7773f95b0f421f00c7848f32f43fa5ba5aad4.
- Clean-checkout gate: fresh `git clone` → ./verify.sh 173 PASS ALL GATES GREEN →
  ./build.sh signed app OK.
- Tag v1.0.0 created and pushed to the (private) remote.
- NOT done by the agent, by policy: repo visibility flip and public Release creation are
  access-control/publishing actions reserved for Michael — exact commands in SUBMISSION.md.

## S8-release — publication run (2026-07-16, release-completion session)

Michael explicitly authorized GitHub publication and Release creation this session; the
agent performed everything except the visibility flip (access-control change — agent
policy, reserved for Michael; single command in SUBMISSION.md).

- Portable-build gate FAILED at v1.0.0 and was fixed (commit `74a407c`, tag `v1.0.1`):
  build.sh pinned the maintainer's signing identity with no fallback, so a public clone
  could not complete `./build.sh`. Fix: keychain check → maintainer identity (DR gate
  active) or ad-hoc fallback with an honest re-prompt warning; `PRESENCE_SIGN_ID`
  override; bundle version string 1.0.1. v1.0.0 tag untouched at `a44c341`.
- `./verify.sh` after fix → 173 PASS, 0 FAIL, 1 SKIP (fixture-vision), ALL GATES GREEN.
- Release PUBLISHED: `gh release create v1.0.1 …` →
  https://github.com/Solarthis/presence-macos/releases/tag/v1.0.1 ("Presence v1.0.1 —
  Build Week release", normal release, notes cover: macOS 26 arm64 minimum, not-notarized
  + Gatekeeper "Open Anyway" honesty, $0 rationale, pending human hardware verification,
  no security guarantees). Assets: Presence-v1.0.1-macos-arm64.zip + .sha256
  (`af78bcd72a9c986065edbf3dbb3e2186e201c1a0c673a368d2f19c08c40805b8`).
  Round-trip verified: `gh release download v1.0.1` → `shasum -a 256 -c` → OK (the .sha256
  asset was regenerated without the `dist/` path prefix so the documented command works).
- Repo metadata set: description + topics (macos, swift, swiftui, privacy,
  computer-vision, openai-build-week). Visibility still PRIVATE pending Michael.
- Clean-clone verification (fresh `git clone` from GitHub → /tmp/presence-public-verification,
  commit `74a407c`): `./verify.sh` → 173 PASS / 0 FAIL / 1 SKIP, ALL GATES GREEN;
  `./build.sh` → identity-signed OK; `PRESENCE_SIGN_ID=<absent-id> ./build.sh` → ad-hoc
  fallback OK (portable path); app smoke-launched from the clone and quit cleanly (no
  camera bind — no TCC grant exists; no curtain test, per protocol). No local files or
  absolute paths required. NOTE: clone was authenticated (repo still private); the
  unauthenticated-URL check happens right after Michael's flip (SUBMISSION.md step 0).
- Binary hygiene: `strings` on the release binary → zero `/Users/…` paths embedded.
- Full-history secret scan re-run this session: CLEAN (no key/token/PEM patterns in any
  commit). No tracked images/.env/certificate material (git ls-files audit).
- Pre-publication content sweep (18-agent adversarial workflow, 5 lenses; endorsement
  lens clean) — confirmed findings, ALL fixed this session: stale "169" counts in
  docs/architecture.md; "PRIMARY (provisional)" labels in CODEX_SESSIONS.md; README
  "opaque curtain"/"no other way in" overclaims (curtain is a frosted NSVisualEffectView
  blur — wording now matches the code); SUBMISSION tagline "only you can lift" →
  restore-path phrasing; verbatim banned local path in STATE.md; `workdir: /Users/…`
  headers in fixtures-codex/*.txt (redacted with an explicit marker; extraction checks
  re-verified green). Accepted, documented, not fixed: git author emails are
  machine-local (`mike@…local`) — correcting them needs a history rewrite that would
  invalidate the published v1.0.0/v1.0.1 tags, so they stay; disclosure is the local
  username only.
- Devpost: live form read (categories: Apps for your life / Work and productivity /
  Developer tools / Education; <3-min PUBLIC YouTube video; deadline Tue Jul 21 5:00 PM
  PT). Draft prep stopped exactly at the login screen — no authenticated session; the
  agent does not enter credentials.

## Fix — stale paused-state menu label (2026-07-16, found by Michael in live use)

- Symptom: menu bar showed "monitoring off — camera pipeline not yet installed" (a
  slice-2-era placeholder in MenuBarState.swift that survived; it displayed for every
  .paused state and clobbered the intended camera-permission text on each tick), which
  read as a missing component. The camera pipeline and Start Monitoring → pre-prompt →
  TCC-request wiring were verified present and correct (PresenceApp.swift
  CameraPermissionControls, RuntimeCoordinator.requestCameraAccess).
- Also found live: an app instance predating the day's rebuilds blocked the TCC prompt
  (running image no longer matched the on-disk bundle); fixed by relaunching from the
  current identity-signed bundle.
- Fix: label now reads "monitoring off — choose Start Monitoring from this menu"
  (commit `660443b`, tag `v1.0.2`). `./verify.sh` → 173 PASS / 0 FAIL / 1 SKIP, ALL
  GATES GREEN; rebuilt identity-signed and relaunched.
- Release v1.0.2 PUBLISHED as latest:
  https://github.com/Solarthis/presence-macos/releases/tag/v1.0.2, assets
  Presence-v1.0.2-macos-arm64.zip + .sha256
  (`5548c4982c1f0de176440c4130154caf24de4c2cf4471c7e61029ef022226230`), checksum verified.
  v1.0.1 and v1.0.0 untouched.
