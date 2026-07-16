# Presence

A native macOS menu-bar app that notices when you step away from your Mac and raises a
privacy curtain over your screens until you come back and confirm it's you — using the
camera entirely on-device, and Apple's own authentication to restore.

Built for OpenAI Build Week 2026. Core functionality implemented by **Codex (GPT-5.6)**;
see [AI collaboration](#ai-collaboration).

## What it does

- **Presence detection** — the built-in camera (never an iPhone/Continuity camera) runs
  Apple Vision face + human detection locally at ≤5 fps. No frame ever leaves your Mac.
- **Privacy curtain** — when you're away past a grace period (default 30 s), an opaque
  curtain covers every display. Restoring it requires **Touch ID or your password** via
  Apple's LocalAuthentication — there is no other way in.
- **Additional-viewer warning** — optionally raises the curtain when a second person is
  visible behind you for a sustained interval.
- **Policies in plain English** — type "protect my screen when I walk away for 45 seconds"
  and compile it to a policy. With the Codex CLI installed, GPT-5.6 does the compiling
  (via your existing Codex plan — no API key, no cost); otherwise a built-in deterministic
  template compiler handles common phrasings. Either way the output is **untrusted input**:
  it passes a strict schema validator, you see a plain-language preview plus the raw JSON,
  and nothing takes effect until you explicitly approve it.
- **Event history** — a closed-schema local log (state changes only, never images), with
  one-click Delete All. "Explain recent events" can send the sanitized log — previewed
  verbatim first, sent only when you click Send — to GPT-5.6 for a plain-English summary.
- **Simulator mode** — scripted scenarios (walk away, lean away, second viewer, camera
  loss) run through the real state machine with a visible SIMULATOR badge, so you can see
  the whole flow with no camera access at all.
- **Status HUD** — an optional floating panel showing live state, person count, and
  confidence, legible from across the room.

## What it never does

- **It is not a login replacement.** Presence never touches loginwindow, PAM, the
  authorization database, or FileVault, and never stores or replays your password. It is
  not "Face ID for Mac" — restoration is Apple's LocalAuthentication prompt, nothing else.
- **Camera data never leaves the device.** No frames, embeddings, or identity data are
  ever written to disk¹ or sent anywhere, including to GPT-5.6. Flow E sends only the text
  you typed; Flow F sends only the sanitized event schema you previewed.
- **The model is outside the trust boundary.** GPT-5.6 output is text that must survive
  validation and your explicit approval. It cannot execute anything, and a response can
  trigger nothing.
- **You always have an exit.** Pause from the menu bar, quit with ⌘Q, `kill -9` recovers
  cleanly (protected state never persists), repeated crashes trigger safe mode, and
  creating `~/.presence-disable` disables the app entirely.

¹ Except a developer fixture-capture mode that is compiled out of release builds and also
requires an explicit `--fixture-capture` launch flag.

## Requirements & build

- macOS 26 (Tahoe) on Apple silicon; built-in camera for live monitoring
  (simulator mode works without one).
- Xcode Command Line Tools (Swift 6.3). No Xcode, no third-party dependencies.

```bash
git clone https://github.com/Solarthis/presence-macos.git
cd presence-macos
./verify.sh     # build + 169-check suite + safety gates
./build.sh      # produces signed Presence.app
open Presence.app
```

`verify.sh` is the single verification entry point: it builds, runs the assert-based
check suite (state machine scenarios, hostile policy fixtures, timing-isolation and
authentication-boundary structural checks), and enforces source-level gates (PresenceCore
stays free of camera/UI frameworks; no hard-coded safety timing in the app layer; no
login-path mechanisms anywhere).

## Architecture (short version)

Two layers, enforced by a build gate:

- **PresenceCore** — pure logic, no AppKit/AVFoundation/Vision: the deterministic state
  machine (launch guard → awaiting presence → present → grace → protected → restore),
  policy schema + validator, JSON extractor, template compiler.
- **Presence** (app) — AVFoundation camera source, Vision perception, curtain windows,
  LocalAuthentication gate, menu bar, policy store/UI, event store.

Production timing is structurally isolated from demo timing: the production entry point
takes no configuration and always derives from safe defaults (30 s launch guard, 30 s
grace); compressed demo timing exists only behind explicit scripted-run entry points and
`--simulate`/`--live-test` flags. Automated checks and source gates enforce this.

See `docs/` and `TESTING.md` for details and evidence.

## Known limitations

- **App hiding is cut.** `NSRunningApplication.hide()` proved unreliable on macOS 26
  (spike-tested, 3 attempts). The `hideApps` policy action is stored but inert, and the
  preview says so. The curtain is the protective action.
- **Displays-off is honest about locking:** turning displays off locks your Mac only if
  "Require password immediately" is enabled in System Settings — Presence cannot verify
  that setting, and the UI says exactly that. Off by default.
- Presence is a privacy *courtesy* layer against shoulder-surfing and walk-away exposure.
  It is not a security boundary against a determined local attacker — your locked screen is.

## AI collaboration

This project was built for OpenAI Build Week with an explicit AI division of labor:

- **Codex (GPT-5.6, `gpt-5.6-sol`)** implemented the core functionality — state machine,
  curtain/safety mechanics, LocalAuthentication restore, camera/perception pipeline,
  policy schema/validator/compiler, and event system — across recorded `codex exec`
  sessions, primarily one PRIMARY session. Session IDs and scopes: `CODEX_SESSIONS.md`.
- **Claude (Claude Fable 5, via Claude Code)** orchestrated: wrote slice specifications,
  reviewed every diff independently, ran verification, managed git/GitHub, and wrote the
  documentation.
- At runtime, GPT-5.6 (via the user's own Codex CLI plan) optionally compiles
  plain-English policy text and summarizes event history — always behind validation,
  preview, and explicit human approval.

## License

MIT — see [LICENSE](LICENSE).
