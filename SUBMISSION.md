# Build Week submission package — Presence

Status: RELEASE PUBLISHED (2026-07-16) — GitHub Release v1.0.1 is live with artifacts and
honest notes; repo description/topics set; clean-clone verification green. The ONE
remaining publication step is Michael's visibility flip (Publication section). Items
marked 🧑 are Michael-only.

## Facts

- Project: **Presence** — native macOS privacy curtain driven by on-device presence
  detection, with GPT-5.6-compiled protection policies.
- Repo: https://github.com/Solarthis/presence-macos (private until Michael's one-command
  flip; description + topics already set)
- Release: https://github.com/Solarthis/presence-macos/releases/tag/v1.0.1 —
  "Presence v1.0.1 — Build Week release", published 2026-07-16 (becomes publicly visible
  with the flip). Tag `v1.0.1` = commit `74a407c` (portable-build fix; app functionally
  identical to the reviewed `v1.0.0` source tag, which remains untouched at `a44c341`).
  Assets: `Presence-v1.0.1-macos-arm64.zip` +
  SHA-256 `af78bcd72a9c986065edbf3dbb3e2186e201c1a0c673a368d2f19c08c40805b8` (.sha256
  attached; download → `shasum -a 256 -c` round-trip verified OK).
  Verification: **173 PASS / 0 FAIL / 1 honest SKIP** (fixture-vision, until Michael
  captures local fixtures) + 5 source gates — re-confirmed from a fresh GitHub clone,
  including both build paths (maintainer identity-signed and no-identity ad-hoc portable).
- Codex PRIMARY Session ID: `019f6b6d-0524-7762-8d71-6a69a2f5e096`
  (state machine, curtain/safety/auth restore, camera pipeline, policy
  schema/validator/store/UI, Codex compiler, Flow F, event history — see
  CODEX_SESSIONS.md for the full session table)
- Demo video: 🧑 ⏳ YouTube URL
- Cost: $0 incremental (no API keys; model calls via existing Codex plan, 4/10 used)

## Track recommendation

Live Devpost categories (checked 2026-07-16 on openai.devpost.com): *Apps for your life /
Work and productivity / Developer tools / Education*. **Recommended: Apps for your life**
(consumer app for everyday privacy). Live-form requirements: a **<3-minute PUBLIC YouTube
demo** whose audio covers how Codex AND GPT-5.6 were used; the repo URL public (or private
but shared with testing@devpost.com and build-week-event@openai.com); a README with setup
instructions. Submissions close **Tue Jul 21, 5:00 PM PT**. The pitch: the
model sits *outside* the trust boundary by architecture — GPT-5.6 writes policies in a
closed JSON schema that must survive a hostile-input validator and explicit human
approval before it can influence anything, and the entire core app was itself built by
Codex sessions. AI wrote the app; AI configures the app; AI can't escape the app's rules.

## Devpost copy (paste-ready)

### Tagline (200 chars)

Your Mac notices when you walk away — or when someone reads over your shoulder — and
drops a privacy curtain that lifts only through Touch ID or your password. On-device
vision, Apple auth, GPT-5.6 policies.

### Inspiration

Everyone locks their phone obsessively and leaves their Mac wide open at coffee shops,
offices, and kitchen tables. The screen lock is too slow and too manual for the
thirty-second walk-away. We wanted the Mac to *notice* — without sending a single camera
frame anywhere, and without pretending to be a security product it isn't.

### What it does

Presence watches the built-in camera entirely on-device (Apple Vision, ≤5 fps, frames
discarded in memory). Walk away past your grace period and a frosted curtain obscures every
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

## Publication (🧑 ONE command — everything else is done)

The GitHub Release v1.0.1 (artifacts + notes), repo description, and topics are already
published. Changing repository visibility is an access-control action the agent will not
perform, so the single remaining publication step is Michael's:

```bash
gh repo edit Solarthis/presence-macos --visibility public --accept-visibility-change-consequences
```

Afterwards (~2 min): open https://github.com/Solarthis/presence-macos in a private
browser window — README, the v1.0.1 release, and both assets should be visible logged
out; `gh repo view Solarthis/presence-macos --json visibility` should say "PUBLIC".
The agent already verified a fresh GitHub clone end-to-end (verify 173 PASS, both build
paths, checksum round-trip), so no further clone test is needed.

## Final human checklist (🧑 all, in order — the single consolidated list)

0. **Publish**: run the one visibility command above; spot-check the public URL logged out.
1. **Camera permission**: launch Presence (release zip or `./build.sh && open
   Presence.app`), start monitoring, click **Allow** on the macOS camera dialog — approve
   camera only, nothing else. Confirm the menu bar leaves "camera unavailable" and shows
   MONITORING.
2. **Touch ID / device-owner auth**: trigger the safe live curtain test, confirm the
   genuine macOS LocalAuthentication sheet appears, authenticate with Touch ID — the
   curtain must lift only on success. Cancel once to confirm the curtain stays. Confirm
   ⌘⌥⇧Q quit and relaunch recovery.
3. **Fixture capture**: run with `--fixture-capture` → empty room / one person / two
   people. Fixtures stay local and gitignored, excluded from release artifacts. Re-run
   `./verify.sh` — the fixture-vision SKIP activates; if the PASS count changes, update it
   everywhere in this file and README.
4. **Manual hardware checks**: walk-away; return; additional viewer; camera covered; low
   light; external display (if available); escape sequence; force quit; emergency-disable
   file (`~/.presence-disable`); relaunch safety; no-network mode.
5. **Film + upload**: follow the demo shot list above (<3 min, audio must cover how Codex
   AND GPT-5.6 were used); upload to YouTube as **Public** (Devpost requires public);
   paste the URL here and into the Devpost draft.
6. **Devpost**: sign in at openai.devpost.com (the agent stopped exactly at the login
   screen — it cannot enter credentials), open the Build Week submission flow, create the
   draft, paste the copy above plus repo URL, category "Apps for your life", video URL,
   and the PRIMARY Codex Session ID `019f6b6d-0524-7762-8d71-6a69a2f5e096` in the required
   field. Review, then the final Submit click is yours alone (or explicitly authorize the
   agent to submit the completed draft).
