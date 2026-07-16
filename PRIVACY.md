# Privacy

Presence's entire purpose is privacy, so its own data handling is deliberately boring.

## Camera

- Frames are captured from the **built-in camera only** (`.builtInWideAngleCamera` is the
  only device type the discovery session can return — Continuity/iPhone cameras cannot
  bind), at 640×480, processed at most 5 per second.
- Each frame is analyzed **in memory** by Apple Vision (face + human rectangles) and then
  discarded. What survives is three numbers: a timestamp, a person count, and a confidence
  band (low/medium/high).
- No frame, thumbnail, embedding, or any camera-derived image data is written to disk or
  transmitted anywhere, ever, in a release build. (Debug builds have a fixture-capture
  mode for the test suite; it is compiled out of release builds *and* requires an explicit
  `--fixture-capture` launch flag, and its output directory is gitignored.)
- Camera permission is requested once, with a plain explanation, only when you choose to
  start monitoring. If you decline, Presence says monitoring is off and never re-prompts
  on its own.

## What GPT-5.6 sees (and doesn't)

GPT-5.6 is invoked only through your own local Codex CLI, only for two flows, and never
automatically:

- **Policy compiling (Flow E):** it receives the fixed schema prompt plus the sentence you
  typed. Nothing else. Its output is validated, previewed, and inert until you approve it.
- **Event explanations (Flow F):** it receives a sanitized payload of at most 20 event
  records — closed schema fields only (event type, timestamp, confidence band, action
  taken, policy *name*). The exact JSON is shown to you first, and nothing is sent until
  you click Send.

It never receives camera frames, screenshots, file contents, app names, bundle
identifiers, or anything it could use to identify you. Its responses are displayed as
plain text and can trigger nothing.

## Event log

- Stored locally in Application Support as a closed, sanitized schema (the fields above —
  never free text, never images), capped as a ring buffer.
- **Delete All** in the Event History window empties it immediately.

## Network

Presence makes no network connections of its own. The only network activity happens
inside your own Codex CLI when *you* explicitly compile a policy or send an event
explanation. The app is fully functional offline (template compiler, curtain, simulator,
history all work with networking disabled).

## Analytics, accounts, telemetry

None. No accounts, no telemetry, no crash reporting, no third-party SDKs — the project
has zero third-party dependencies.
