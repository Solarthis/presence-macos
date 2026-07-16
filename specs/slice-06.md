# Slice 6 spec — Flow E Rung 2: CodexPolicyCompiler

Read STATE.md, docs/flow-e-mode.md, and the slice-4 policy code first. Work in
`Sources/Presence/` (+ fixture files under `Sources/Checks/`). PresenceCore FROZEN except:
if the compile call-site enum needs a new case, the enum lives app-side anyway. No new deps.
All gates stay green. ZERO live codex calls from Checks or builds — parsing is tested against
recorded fixtures only.

## CodexPolicyCompiler (`Sources/Presence/CodexPolicyCompiler.swift`)
- Extends the slice-4 compile flow with mode .codexCLI (UI label: "Compile with GPT-5.6
  (via your Codex plan)").
- Binary discovery, boring and explicit: first existing of
  (1) UserDefaults override "codexPath", (2) `~/.nvm/versions/node/v24.15.0/bin/codex`,
  (3) `/opt/homebrew/bin/codex`, (4) `/usr/local/bin/codex`. If none: honest UI error
  "Codex CLI not found — using built-in templates" and fall back.
- Invocation: Process spawning `codex exec --sandbox read-only -` with stdin =
  COMPILER_PROMPT + "\n\nUSER REQUEST:\n" + userText. COMPILER_PROMPT is ONE fixed string
  constant checked into the repo: states the full v1 JSON schema, "output ONLY a single JSON
  object, no prose, no markdown fences", and 2 worked examples. 120 s timeout; async with a
  spinner sheet + Cancel; never blocks the main thread.
- Output handling: take stdout, extract the LAST balanced top-level {...} JSON object
  (codex exec prefixes banner lines), then feed the raw extracted string through the IDENTICAL
  PolicyValidator pipeline from slice 4 — the model's output is untrusted input, always.
  Validation failure → one single retry with the validator's reason appended to the request;
  second failure → show the reason, keep the previous policy (same rule as slice 4).
- Live-call budget: hard cap 10 for the entire project. Persistent counter in UserDefaults
  ("codexLiveCalls") AND an append line per call to logs/live-calls.log (timestamp, purpose,
  chars in/out). At the cap: UI says "live compile budget reached — using built-in templates"
  and the mode silently falls back to templates. No override switch.

## Fixtures (`Sources/Checks/CodexOutputFixtures.swift` + checks)
- Raw captured `codex exec` outputs live as plain text files in `fixtures-codex/` at the repo
  root (committed — they contain only JSON/prose, no images). Checks reads them via relative
  path from the working directory and SKIPs cleanly if the directory is absent.
- Implement `extractLastJSONObject(from:)` in PresenceCore (pure string logic — allowed there)
  so both the app and Checks use the identical extractor.
- Checks cases: extractor pulls the JSON out of each fixture (with banners, with markdown
  fences, with trailing prose); extracted JSON passes/fails the validator as expected;
  a fixture with NO JSON object yields a typed failure (never a crash).

## Verification contract
1. `swift build && swift run Checks` green with fixtures present or absent (SKIP cleanly).
2. Template mode still works end-to-end unchanged.
3. One live smoke compile (I run it manually, counted against the budget): plain-English →
   JSON → preview → approve, with the live-call logged.

Print a file-by-file summary when done.
