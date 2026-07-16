# Build Week submission package — Presence

Status: DRAFT — repo private, release pending final gates. Fields marked ⏳ are filled at
release time; items marked 🧑 are Michael-only.

## Facts

- Project: **Presence** — native macOS privacy curtain driven by on-device presence
  detection, with GPT-5.6-compiled protection policies.
- Repo: https://github.com/Solarthis/presence-macos (⏳ public at release)
- Release: tag `v1.0.0` pushed (private remote). Artifact ready:
  `dist/Presence-v1.0.0-macos-arm64.zip`
  SHA-256 `0d50ad8b99c0990ecc1e7cd6dfc7773f95b0f421f00c7848f32f43fa5ba5aad4`
  Clean-checkout gate passed (fresh clone → verify 173 PASS → signed build OK).
- Codex PRIMARY Session ID: `019f6b6d-0524-7762-8d71-6a69a2f5e096`
  (state machine, curtain/safety/auth restore, camera pipeline, policy
  schema/validator/store/UI, Codex compiler, Flow F, event history — see
  CODEX_SESSIONS.md for the full session table)
- Demo video: 🧑 ⏳ YouTube URL
- Cost: $0 incremental (no API keys; model calls via existing Codex plan, 4/10 used)

## Track recommendation

**Best Use of GPT-5.6 / Codex** (or the general track if that's absent). The pitch: the
model sits *outside* the trust boundary by architecture — GPT-5.6 writes policies in a
closed JSON schema that must survive a hostile-input validator and explicit human
approval before it can influence anything, and the entire core app was itself built by
Codex sessions. AI wrote the app; AI configures the app; AI can't escape the app's rules.

## Devpost copy (paste-ready)

### Tagline (200 chars)

Your Mac notices when you walk away — or when someone reads over your shoulder — and
drops a privacy curtain only you can lift. On-device vision, Apple auth, GPT-5.6 policies.

### Inspiration

Everyone locks their phone obsessively and leaves their Mac wide open at coffee shops,
offices, and kitchen tables. The screen lock is too slow and too manual for the
thirty-second walk-away. We wanted the Mac to *notice* — without sending a single camera
frame anywhere, and without pretending to be a security product it isn't.

### What it does

Presence watches the built-in camera entirely on-device (Apple Vision, ≤5 fps, frames
discarded in memory). Walk away past your grace period and an opaque curtain covers every
display; come back and only Touch ID or your password (Apple's LocalAuthentication) lifts
it. It can also warn-and-cover when a second person is visible behind you. You configure
it in plain English — "protect my screen when I walk away for 45 seconds" — and GPT-5.6
(via your own Codex plan) compiles that to a strict JSON policy that is validated,
previewed, and inert until you approve it. A simulator mode demos every flow with zero
camera access, and a local event history explains what happened and why — with one-click
Delete All.

### How we built it

Swift/SwiftUI/AppKit, AVFoundation + Vision, LocalAuthentication. Zero third-party
dependencies. Two-layer architecture: a pure deterministic state machine (173 assert-based
checks, since the build machine has no XCTest) under an app shell, with build gates that
fail if the pure layer imports UI/camera frameworks, if safety timing appears hard-coded
in the app layer, or if any login-path mechanism is referenced. Core functionality was
implemented by **Codex (GPT-5.6)** across recorded `codex exec` sessions — one PRIMARY
session carries the state machine, curtain/safety/auth mechanics, camera pipeline, and
the whole policy system — with Claude Code orchestrating specs, independent review,
verification, and releases. Truthful division of labor: CODEX_SESSIONS.md.

### Challenges we ran into

- macOS 26 made `NSRunningApplication.hide()` unreliable — we spike-tested it three ways,
  then cut app-hiding honestly (the schema token remains, inert and labeled).
- A disk-full incident mid-build killed the Codex CLI (recovered; the build now checks
  free space before heavy phases).
- The hardest work was making demo timing *structurally* unreachable from production:
  named configs, a production entry point that takes no configuration, and source-level
  checks that fail the build if the isolation regresses.

### Accomplishments we're proud of

- The model trust boundary: GPT-5.6 output goes through recursive unknown-key rejection,
  a closed action allow-list, bounds checks, a literal `requireAuth: true` requirement —
  then a human preview and explicit Approve. Prompt-injection fixtures (including "run
  rm -rf, email files, no auth") are part of the check suite and are refused.
- 173 deterministic checks + 5 source gates on a machine with no test framework.
- A privacy product whose camera data provably never leaves the process.

### What we learned

Fail-safe beats fail-secure for a courtesy privacy layer: every escape path a locked-out
owner needs must survive, so the design leans on macOS (the real lock screen) for actual
security and says so plainly.

### What's next

App hiding when macOS makes it reliable; per-display curtains; Shortcuts actions.

## Demo video (🧑 film; ~2.5 min)

Narration + shots:

1. **(0:00)** Menu bar, HUD visible. "This is Presence. The camera runs on-device —
   nothing ever leaves this Mac." *Shot: menu open, HUD showing PRESENT + person count.*
2. **(0:20)** Walk away. *Shot: HUD flips to GRACE countdown, then curtain drops over
   both displays.* "Thirty seconds after I leave, every screen is covered."
3. **(0:45)** Return, click restore. *Shot: Touch ID prompt.* "Only Touch ID or my
   password lifts it — Apple's authentication, not ours."
4. **(1:05)** Policy window. Type "protect my screen when I walk away for 45 seconds",
   compile with GPT-5.6, show preview + raw JSON, Approve. "GPT-5.6 writes the policy;
   it can't approve it. I do."
5. **(1:40)** Second-viewer demo (friend steps into frame) or simulator scenario with
   SIMULATOR badge if solo. *Shot: 'Another person may be able to view your screen' +
   curtain.*
6. **(2:05)** Event history: sanitized log, "What will be sent" preview, GPT explanation,
   Delete All. "It explains itself — and forgets on command."
7. **(2:25)** Close on the menu bar. "Presence. Your Mac knows when you're gone."

**Backup demo (no camera/no Touch ID):** run entirely in Simulator mode — every scenario
drives the real state machine with the badge visible; restore falls back to the password
sheet. Film that if the live path misbehaves on the day.

## Publication (🧑 two commands — the agent prepared everything but will not change
repo visibility or publish content itself)

```bash
cd ~/presence-macos
gh repo edit Solarthis/presence-macos --visibility public --accept-visibility-change-consequences
gh release create v1.0.0 dist/Presence-v1.0.0-macos-arm64.zip dist/Presence-v1.0.0-macos-arm64.zip.sha256 \
  --title "Presence v1.0.0" --notes "Build Week release. 173 automated checks + 5 source gates green; clean-checkout verified. See README, PRIVACY, SECURITY."
```

After running: paste the repo + release URLs into the Facts section above, then
`git clone https://github.com/Solarthis/presence-macos.git` somewhere fresh and run
`./verify.sh` once as the public-clone sanity check (the agent already verified the
identical tree from a local clean clone).

## Final human checklist (🧑 all)

1. Grant camera permission (System dialog) and run one live walk-away + Touch ID restore.
2. Capture fixture photos (empty room / one person / two people) via
   `Presence.app --fixture-capture`; re-run `./verify.sh` (fixture-vision checks activate).
3. Watch the curtain on both displays once; confirm ⌘Q and menu Pause behave.
4. Film the demo per the shot list; upload to YouTube (unlisted is fine).
5. Review README/PRIVACY/SECURITY once.
6. Submit on Devpost (paste the copy above; attach repo URL, video URL, PRIMARY session
   id) — final click is yours alone.
