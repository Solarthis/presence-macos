# Slice 4 spec — policy schema v1, validation pipeline, storage, approve UI, templates

Read STATE.md, ACCEPTANCE.md, docs/flow-e-mode.md, and existing Sources/ first. PresenceCore
gains PURE policy logic (validation, preview text); Presence gains storage + UI + enforcement
wiring. No new dependencies. `swift build && swift run Checks` must stay green; verify.sh gates
must stay green (PresenceCore stays free of AppKit/SwiftUI/AVFoundation/Vision).

## PresenceCore (pure)

`Sources/PresenceCore/Policy.swift` — the ENTIRE v1 schema, Codable structs, actions as enums:
{ schemaVersion: 1 (exact), name: String, rules: [ { trigger: absence|additionalViewer,
graceSeconds: Double (2–600), minPersons: Int? (≥2, additionalViewer only), minConfidence:
Double (0.3–1.0, default 0.6), actions: [curtain|hideApps|displaysOff] non-empty,
hideAppBundleIds: [String]? (required iff hideApps) } ], restoration: { requireAuth: true } }.
Do NOT add fields for focus modes, time ranges, locations, displays, notifications.

`Sources/PresenceCore/PolicyValidator.swift` — steps 1–7, any failure = typed rejection with a
human-readable reason; never partial-apply, never auto-repair:
1. Input must be a single JSON object, no surrounding prose (trim + reject if extra tokens).
2. JSONSerialization parse; RECURSIVELY check every key at every nesting level against
   hardcoded per-object allow-lists (JSONDecoder ignores unknown keys — this step is the guard).
3. Decode into the Codable structs; actions must decode as enum cases.
4. schemaVersion == 1 exactly.
5. Every action in the hardcoded capability allow-list.
6. Semantic bounds: graceSeconds 2–600; minConfidence 0.3–1.0; minPersons ≥2;
   hideAppBundleIds present iff hideApps in actions; actions non-empty; no duplicate trigger
   across rules; hideAppBundleIds must never include Terminal/iTerm/IDE bundle ids
   (com.apple.Terminal, com.googlecode.iterm2, com.microsoft.VSCode) — hardcoded never-hide list.
7. restoration.requireAuth must be LITERAL true.

`Sources/PresenceCore/PolicyPreview.swift` — pure function Policy → [String]: plain-language
lines ("When nobody is visible for 30 seconds → raise the privacy curtain", "Unlocking always
requires Touch ID or your password"). Actions not yet enforceable in this build (hideApps,
displaysOff) get the suffix " (not active in this build yet)".

`Sources/PresenceCore/TemplateCompiler.swift` — deterministic phrasing→policy mapping
(lowercase keyword matching, boring): recognize grace durations ("30 seconds", "2 minutes"),
absence vs "someone else/another person" triggers. Unrecognized input → .unrecognized result
listing the 3 bundled examples. Output goes through PolicyValidator like ANY compiler output.

`Sources/PresenceCore/ExamplePolicies.swift` — 3 bundled examples as JSON strings (simple
absence 30 s; absence 60 s + hideApps with placeholder bundle id; additionalViewer 5 s
sustain) — they must pass the validator (that IS one of the checks).

## Presence (app)

`Sources/Presence/PolicyStore.swift` — policies.json (array) in Application Support; atomic
writes; at most ONE active policy id persisted in UserDefaults.
`Sources/Presence/PolicyWindow.swift` — SwiftUI window from the menu ("Policies…"):
list + activate/deactivate + delete; "New Policy…" flow: TextField (plain English) → Compile
(TemplateCompiler for now; the compile call site takes an enum PolicyCompilerMode so slice 6
adds .codexCLI without redesign) → PREVIEW step (PolicyPreview lines + collapsible raw JSON)
→ explicit Approve / Reject buttons. Only Approve persists + activates.
`RuntimeCoordinator` wiring: active policy's absence rule sets MachineConfig.graceSeconds;
additionalViewer rule sets additionalViewerEnabled/minPersons/sustainSeconds. Enforcement in
this slice executes CURTAIN only; hideApps/displaysOff actions are stored but inert (the
preview already says so — never pretend).

## Checks (hostile fixtures — every one must be REJECTED with the right reason)
unknown key at root / in rules[0] / in restoration; graceSeconds 1 and 9999; action "runShell";
action "lockScreen" (not in v1 schema!); requireAuth false; requireAuth absent; schemaVersion 2;
prose-wrapped JSON ("Sure! Here is your policy: {...}"); duplicate absence triggers; hideApps
without hideAppBundleIds; empty actions; hideAppBundleIds containing com.apple.Terminal.
Plus positive checks: all 3 bundled examples validate; TemplateCompiler("protect my screen
when I walk away for 30 seconds") produces a valid absence policy; preview lines non-empty.

Print a file-by-file summary when done.
