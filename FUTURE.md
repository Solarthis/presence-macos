# FUTURE — designated home for every idea outside the tier list (one line each)

- Notification-preview concealment: impossible via public API; users can set "Show Previews: When Unlocked".
- Focus-mode / time-range / location contexts in the policy schema.
- Per-display configuration.
- Launch-at-login (SMAppService) — deliberately out of this run for startup safety.
- Bespoke additional-viewer warning UI (v1 reuses the curtain).
- Settings sync.
- ChatGPT copy-paste compile mode (zero-cost live-GPT alternative to Rung 2).
- Per-window minimization via AX APIs (needs Accessibility permission — out of scope v1).
- App hiding via NSRunningApplication.hide() — spike showed unreliable behavior on macOS 26
  (spurious false returns, intermittent no-op); needs a robust retry/verify design.
- Product rename ("Presence" collides heavily on the App Store, incl. a camera-security app).
