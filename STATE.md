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
- Phase: SLICE 1 (scaffold) — in progress.
- Next concrete action: first build + verify + commit, then delegate slice 2 (state machine + Checks) to Codex.

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

## Blocked / human items (accumulating into CHECKPOINT_1.md)
- Devpost: open a draft submission at openai.devpost.com TODAY (5 min, human).
- Camera TCC grant + Touch ID live test + fixture photos → Checkpoint 1 when slice-5 build exists.

## Codex session log
- See CODEX_SESSIONS.md.
