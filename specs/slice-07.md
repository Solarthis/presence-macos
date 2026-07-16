# Slice 7 spec — Tier 2, strictly in order (calendar-gated; cut ladder applies)

Read STATE.md first — note D7: app hiding is CUT (spike-failed); skip it entirely.
Work in `Sources/Presence/` (+ Checks where noted). PresenceCore may gain ONLY pure logic
if additional-viewer wiring needs it (it should not — slice 2 already implements the
additionalViewer trigger). All gates stay green.

## 7.1 Additional-viewer flow (reuse, don't build)
- Config wiring only: when the active policy has an additionalViewer rule, set
  MachineConfig additionalViewerEnabled/minPersons/sustainSeconds from it (slice 4 wired
  absence; mirror it). The curtain raised by an additionalViewer event shows the message
  "Another person may be able to view your screen" (title swap on the existing curtain —
  no bespoke warning UI). HUD shows personCount ≥2 in an accent color.

## 7.2 displaysOff action (optional, default-OFF, honest copy)
- Policy action displaysOff executes `/usr/bin/pmset displaysleepnow` via Process — ONLY
  when the active policy contains it AND Settings has the master toggle
  "Allow turning displays off" enabled (default OFF).
- UI copy exactly: "Turns off displays. Your Mac locks only if 'Require password
  immediately' is enabled — Presence cannot verify this setting."
- Budget: max 3 build-run attempts; any friction → delete the executor (keep schema token
  inert like hideApps), one line in FUTURE.md, move on.

## 7.3 Flow F — event explanations (same trust rules as Flow E)
- "Explain recent events…" menu item: builds a sanitized payload of the LAST ≤20 event-log
  records (closed schema fields ONLY; policy names replace bundle ids — verify nothing else
  can leak by constructing the payload from the EventStore record struct, never raw file text).
- A "What will be sent" preview sheet shows the exact JSON; the user must click "Send" —
  never automatic. Uses the same codex-exec path and live-call budget as Flow E (shared
  counter, same cap of 10). Response is displayed as plain text — it triggers NOTHING.
- If budget exhausted or codex unavailable → honest label + a local deterministic summary
  (count by eventType, first/last timestamps) instead. Checks: payload builder emits only
  allow-listed fields (hostile record with extra field is dropped — add one check).

## 7.4 Onboarding polish (only if calendar allows)
- First-launch window (one screen, native): what Presence does, what it never does
  (3 bullets: camera stays local · GPT never authenticates or acts · quit/escape always works),
  [Enable camera] [Explore with simulator]. Reduced-motion friendly, light+dark checked.

Print a file-by-file summary when done.
