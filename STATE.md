# STATE — Presence build (session anchor; read this FIRST on any resume)

## The Ten Invariants (restated at every phase transition)
1. Zero new spending — never touch billing, paid programs, trials, or OpenAI account settings.
2. Not a login replacement — no stored passwords, no loginwindow/PAM/root, never "Face ID for Mac".
3. GPT outside the trust boundary — compiles text→JSON through validation + human approval only.
4. Fail safe — every protective state has an escape; protected state never persists; kill -9 recovers.
5. Camera data never leaves the device; event log is a closed sanitized schema.
6. No fakery — features exist only when run and observed here; evidence required; human items never self-marked done.
7. Deadline discipline — agent freeze 23:59 Guyana 2026-07-19; cut ladder applies without asking.
8. Boring implementations, zero third-party dependencies; ideas go to FUTURE.md.
9. Durability — commit every green slice; session ritual on resume; never rewrite green code.
10. Two human checkpoints only; agent never clicks TCC dialogs, does Touch ID, films, or submits.

## Phase / position
- Phase: SLICE 5 complete (camera pipeline + HUD + simulator mode). 131 checks green, 1 honest
  SKIP (fixture-vision awaits human fixtures).
- Next concrete action: delegate slice 6 (Codex policy compiler integration, Flow E Rung 2) to
  Codex PRIMARY session.

## Verified environment (preflight 2026-07-16 09:51 -04)
- macOS 26.4 (25E246) arm64; CLT-only, Swift 6.3; NO Xcode/xcodebuild/XCTest.
- Signing identity FCD7116289F2B86E3CA5477065F9172129AA68E6 "Apple Development: (MB77Q6TVVS)" present; non-interactive.
- OPENAI_API_KEY: ABSENT (authoritative — Flow E Rung 1 permanently closed).
- Codex CLI 0.139.0, logged in via ChatGPT, model gpt-5.6-sol, reasoning effort high.
- gh authenticated as Solarthis; repo name presence-macos available; git identity configured.
- Camera: FaceTime HD present (pin builtInWideAngleCamera; never bind "Mike's iPhone Camera").
- Working dir for repo: ~/presence-macos (never "/Users/mike/MACBOOK FACE ID" — space + banned phrase).

## Decision log (immutable)
- D1 2026-07-16: Governing directive = V1 build prompt (authored 2026-07-16) + user's message-level
  authorizations (GitHub release/tags/artifacts, Devpost draft prep, resource management). The referenced
  PRESENCE_FINAL_AUTONOMOUS_NATIVE_MACOS_PROMPT_V2.md does NOT exist on disk (Spotlight + deep search
  empty). If V2 surfaces, reconcile and record diffs here.
- D2 2026-07-16: Orchestrator is Claude Fable 5 (Claude Code). Core implementation is delegated to
  Codex (model gpt-5.6-sol, high reasoning) via `codex exec` per slice; Claude specifies, verifies,
  commits. Attribution documents this truthfully. Rationale: Build Week rules require core functionality
  built with Codex/GPT-5.6 + a Codex Session ID.
- D3 2026-07-16: Flow E mode = RUNG 2 (CodexPolicyCompiler via `codex exec`, ≤10 live calls total,
  fixtures for all checks). Decided once; never revisit. See docs/flow-e-mode.md.
- D4 2026-07-16: No background applications will be closed — the V2 "resource-management rules" were
  never delivered; conservative default is hands-off.
- D5 2026-07-16: All `codex exec` invocations use explicit sandbox flags (workspace-write for
  implementation slices, read-only for policy compiles). Never danger-full-access.
- D8 2026-07-16: GitHub repo Solarthis/presence-macos created PRIVATE early (post secret-scan)
  and pushed per green slice — off-machine durability after the disk incident. Public flip
  happens ONLY at slice 8 after all release checks. Publication intent unchanged.
- D7 2026-07-16: Spike S3 (NSRunningApplication.hide() without TCC) — 3 attempts, UNRELIABLE
  (worked once via observed isHidden, silently failed once; return values spurious on macOS 26).
  Pre-authorized fallback taken: APP HIDING CUT from this run. hideApps stays schema-valid but
  inert ("not active in this build" in preview). Curtain is the protective action. Never revisit.
- D6 2026-07-16: DISK CRITICAL — startup disk 98% full (~0.6 GB free). ENOSPC killed the codex CLI
  upgrade (binary lost; reinstall pending) and blocks heavy builds. Mitigations: npm cache purged;
  .build deleted between heavy phases when needed; df checked before heavy steps; debug builds
  preferred until release. Freeing 5-10 GB is HUMAN item 0 in CHECKPOINT_1.md (only Michael decides
  what personal data goes). No Trash-emptying, no personal-data deletion by the agent.

- D9 2026-07-16: Safety timing is structurally isolated: MachineConfig.production (always
  PresenceDefaults; launch guard 30 s, grace 30 s) vs .scriptedDemo (8 s/0 s, DEBUG scripted runs
  only). start(source:) takes no config and always uses .production; only startScripted/simulate
  use .scriptedDemo; --live-test inert without a valid --simulate scenario (LaunchOptions).
  Enforced by 13 Checks + verify.sh timing-isolation and auth-boundary gates. Never regress.

## Blocked / human items (accumulating into CHECKPOINT_1.md)
- Devpost: open a draft submission at openai.devpost.com TODAY (5 min, human).
- Camera TCC grant + Touch ID live test + fixture photos → Checkpoint 1 when slice-5 build exists.

## Codex session log
- See CODEX_SESSIONS.md.
