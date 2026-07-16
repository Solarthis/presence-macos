# Flow E mode decision (decided once — never revisit)

Date: 2026-07-16. Preflight results:
- OPENAI_API_KEY: ABSENT from environment and shell config. Absence is authoritative → **Rung 1 permanently closed**.
- `codex login status`: "Logged in using ChatGPT"; model gpt-5.6-sol, reasoning high → **Rung 2 OPEN**.

**Selected: RUNG 2 — CodexPolicyCompiler.**
- The app compiles natural-language policies by spawning `codex exec --sandbox read-only` with a strict
  JSON-only prompt (fixed system-prompt string checked into the repo).
- Output is treated as UNTRUSTED input through the identical 9-step validation pipeline.
- Hard cap: 10 live invocations for the entire build (≤5 fixture captures, 1 smoke check, remainder
  reserved for demo rehearsal). Every live call logged to logs/live-calls.log.
- All automated checks use committed fixture responses — zero live calls in Checks.
- TemplatePolicyCompiler + 3 bundled example policies ship regardless; the app is fully functional
  with no network and no Codex CLI (honest UI label: "AI compiler unavailable — using built-in templates").
- Demo beat: live codex-exec compile with narration "this runs through my ChatGPT plan, takes about
  N seconds" over real measured latency.
