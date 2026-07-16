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
