# Codex sessions (submission-blocking: Devpost requires a Codex Session ID)

Orchestration: Claude Code (Claude Fable 5) specifies slices, verifies, and commits.
Core implementation: Codex CLI, model gpt-5.6-sol, reasoning effort high, via `codex exec`.
The session carrying the majority of core functionality will be marked PRIMARY, and its
/feedback Session ID copied into SUBMISSION.md before the freeze.

| Date | Session/thread id | Scope | Primary? |
|------|-------------------|-------|----------|
| 2026-07-16 | 019f6b41-2d77-70f1-a14e-7fa1558448ec | slice-2 attempt (failed: CLI 0.139.0 too old for gpt-5.6-sol; no code produced) | no |
| 2026-07-16 | 019f6b6d-0524-7762-8d71-6a69a2f5e096 | slice-2: presence state machine + 80-check scenario suite (core functionality) | PRIMARY (provisional) |
| 2026-07-16 | (3 micro-sessions, ids in fixtures-codex/*.txt headers) | Flow E fixture captures incl. injection-refusal | no |
| 2026-07-16 | 019f6b78-f75b-7c11-98b8-95097fc45b14 | slice-3: curtain, safety mechanics, LocalAuthentication restore (core functionality) | no |
| 2026-07-16 | 019f6b6d-0524-7762-8d71-6a69a2f5e096 (resumed) | fix: isolate production safety timing from simulator paths (MachineConfig.production/.scriptedDemo, LaunchOptions, safety checks) | PRIMARY (provisional) |
| 2026-07-16 | 019f6b6d-0524-7762-8d71-6a69a2f5e096 (resumed) | slice-4: policy schema v1, validator, preview, template compiler, store, approve UI (core functionality) | PRIMARY (provisional) |
| 2026-07-16 | 019f6b6d-0524-7762-8d71-6a69a2f5e096 (resumed) | slice-5: camera/perception pipeline, HUD, simulator mode (core functionality) | PRIMARY (provisional) |
| 2026-07-16 | 019f6b6d-0524-7762-8d71-6a69a2f5e096 (resumed) | slice-6: CodexPolicyCompiler + JSON extractor + fixtures (core functionality) | PRIMARY (provisional) |
| 2026-07-16 | 019f6bf2-5a78-7382-a1b3-d618f7fd707c | slice-6 live smoke compile (1 call; fixtures-codex/smoke-slice-06.txt) | no |
| 2026-07-16 | 019f6b6d-0524-7762-8d71-6a69a2f5e096 (resumed) | slice-7: additional-viewer UI, displaysOff, Flow F explanations, event history (core functionality) | PRIMARY (provisional) |
