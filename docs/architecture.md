# Architecture

## Two layers, one gate

```
┌─────────────────────────────────────────────────────────────┐
│ Presence (app target — AppKit/SwiftUI/AVFoundation/Vision)  │
│  PresenceApp · RuntimeCoordinator · CameraSource            │
│  CurtainController · AuthGate (LocalAuthentication)         │
│  PolicyStore/PolicyWindow · CodexPolicyCompiler             │
│  EventStore/EventHistoryWindow · HUDPanel · MenuBarState    │
│  SafetyGates · DisplaysOffExecutor                          │
├─────────────────────────────────────────────────────────────┤
│ PresenceCore (pure — Foundation only, enforced by verify.sh)│
│  StateMachine · MachineConfig/PresenceDefaults              │
│  Policy · PolicyValidator · PolicyPreview                   │
│  TemplateCompiler · JSONExtractor · EventRecords            │
│  LaunchOptions                                              │
└─────────────────────────────────────────────────────────────┘
```

`verify.sh` fails the build if PresenceCore imports AVFoundation, Vision, AppKit, or
SwiftUI. Everything in PresenceCore is deterministic and covered by the Checks executable
(assert-based; XCTest is unavailable on a CLT-only machine by design).

## The state machine

Pure, synchronous, event-in/effects-out:

```
launchGuard ──(guard elapsed + confirmed presence ≥3s)──▶ present
present ──(absence)──▶ grace ──(grace elapsed)──▶ protected
grace ──(return)──▶ present
present ──(2+ people sustained, if enabled)──▶ protected
protected ──(LAContext success only)──▶ cooldown ──▶ awaitingPresence
any ──(low confidence / camera loss)──▶ unknownWarning (warn only, NEVER protects)
any ──(pause)──▶ paused
```

Events carry timestamps (`ProcessInfo.systemUptime`); the machine holds no timers. The
coordinator feeds it a 1 Hz tick plus source events and executes the returned effects
(`raiseCurtain`, `dismissCurtain`, `requestAuthUI`, `logEvent`, …). This is what makes 169
deterministic checks possible.

## Timing isolation (the safety invariant)

Two named configurations exist, and the type system decides who gets which:

- `MachineConfig.production` — always derived from `PresenceDefaults` (30 s launch guard,
  30 s grace, additional-viewer off). `RuntimeCoordinator.start(source:)` — the ONLY entry
  point for nil-source and camera monitoring — takes no config parameter and always
  applies this, plus at most the four policy-controllable fields
  (`production(applying:)`: grace, additional-viewer enable/min-persons/sustain — never
  the launch guard).
- `MachineConfig.scriptedDemo` (8 s grace, 0 s guard) — reachable only from
  `startScripted(scenario:)` (requires a valid `--simulate` argument) and the
  DEBUG-labeled menu Simulator, whose exit routes back through `start(source:)`.

Enforced by `SafetyConfigChecks`, `RuntimeIsolationChecks` (structural source
assertions), and two verify.sh gates (no timing literals in the app layer; auth boundary).

## Perception

`CameraSource`: AVCaptureSession @ 640×480 on a dedicated serial queue, ≤5 fps via
timestamp gate, `VNDetectFaceRectanglesRequest` + `VNDetectHumanRectanglesRequest` per
processed frame, `personCount = max(faces, humans)`, confidence band from max observation
confidence (<0.5 low, <0.8 medium, else high). Interruptions, runtime errors, and Vision
failures all surface as `cameraUnavailable` — UNKNOWN territory, never absence. Frames
are dropped, never queued; the main thread never touches the pipeline.

## Policy pipeline (the model trust boundary)

```
user text ─▶ TemplateCompiler (offline, deterministic)
         └▶ CodexPolicyCompiler ─ codex exec --sandbox read-only (≤10 calls, logged)
                    │ stdout
                    ▼
        extractLastJSONObject (pure, string-aware brace matching)
                    ▼
        PolicyValidator  ── recursive unknown-key rejection, closed action
                    │        allow-list, bounds, literal requireAuth:true,
                    │        never-hide bundle-id list, never auto-repairs
                    ▼
        PolicyPreview (plain language + raw JSON) ─▶ human Approve/Reject
                    ▼
        PolicyStore (atomic writes; re-validates raw JSON on every load)
```

Both compilers feed the identical validator; there is no relaxed path. Stored policies
are revalidated from raw JSON at load, so a hand-edited policies.json cannot smuggle
unknown keys past the pipeline either.

## Event system

`EventStore` persists a ring buffer of closed-schema records (kind, timestamp, confidence
band, action, policy id) in Application Support. The Flow F payload builder maps typed
records to an allow-listed wire struct (policy *names* substituted for ids) — it cannot
transmit fields that aren't in the struct. Delete All truncates the store.

## Verification

`./verify.sh` = build + Checks (169 assertions: state-machine scenarios, hostile policy
fixtures, launch-option parsing, structural isolation, recorded Codex-output fixtures)
+ five source gates (layer purity, security-bypass markers, timing isolation, auth
boundary, login-path mechanisms). It is the commit gate: no checklist item flips without
it exiting 0.
