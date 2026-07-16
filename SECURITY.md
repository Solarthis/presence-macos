# Security model and limitations

Read this before relying on Presence. Honesty about the boundary is a design goal.

## What Presence is

A privacy *courtesy* layer: it notices when you walk away or when someone appears behind
you, covers your screens, and requires Touch ID or your password (Apple's
LocalAuthentication) before uncovering them.

## What Presence is not

- **Not a login replacement, and not "Face ID for Mac".** Presence never touches
  loginwindow, PAM, the authorization database, FileVault, or any pre-boot component. It
  never stores, reads, or replays your password. Camera presence is used only to decide
  when to *raise* the curtain — a face can never *unlock* anything.
- **Not a security boundary against a determined local attacker.** The curtain is an
  ordinary app's windows. Someone with physical control of your unlocked Mac could
  force-quit Presence (⌘⌥Esc), `kill -9` it, or reboot. The app deliberately does not
  fight this: every escape path a user needs is also available to an attacker, because a
  privacy tool that could lock its owner out of their own Mac would be worse than the
  problem it solves. **Your locked screen (and "Require password immediately") remains
  the real security boundary.** Presence covers the gap before the screen locks, not
  instead of it.

## Authentication boundary

- The only path from PROTECTED back to a visible desktop is a successful
  `LAContext.evaluatePolicy(.deviceOwnerAuthentication, …)` — Touch ID or password,
  evaluated by macOS, not by Presence.
- There is no simulated-success seam reachable from a normal launch. The demo auto-dismiss
  exists only behind `--live-test` *combined with* an explicit `--simulate <scenario>`
  launch, and structural checks plus a verify.sh gate enforce that `restoreAuthenticated`
  is generated nowhere else.
- After repeated LocalAuthentication *system* failures (not wrong-password attempts),
  Presence shows a Quit button rather than trapping you behind a broken prompt.

## Fail-safe behavior

- Protected state never persists: after a crash or `kill -9`, Presence relaunches
  disarmed, with a 30-second launch guard and a confirmed-presence requirement before it
  can arm.
- Three unclean exits within five minutes → safe mode (monitoring disabled, menu bar
  says so).
- `touch ~/.presence-disable` — emergency kill switch checked at every launch.
- Pause and Quit are always in the menu bar.

## Model (GPT-5.6) boundary

Model output is untrusted input, structurally:

- Policy text → strict validator (recursive unknown-key rejection, closed action
  allow-list, bounds, literal `requireAuth: true`) → human preview → explicit Approve.
- The validator never auto-repairs; a failed compile keeps the previous policy.
- Event-explanation responses are rendered as text; there is no code path from model
  output to any action, process, or setting.
- Live model calls are capped at 10 for the project's lifetime, logged, and fall back to
  the offline template compiler honestly (the UI never claims templates are GPT-generated).

## Known limitations (deliberate)

- **App hiding is cut** — `NSRunningApplication.hide()` is unreliable on macOS 26
  (spike-tested). The `hideApps` policy action is stored but inert and the preview says so.
- **displaysOff can't verify locking** — turning displays off locks the Mac only if
  "Require password immediately" is on; Presence cannot read that setting and says so.
  Off by default behind a master toggle.
- **Detection is best-effort** — Vision can miss people in poor lighting or unusual
  angles, and low-confidence frames are treated as UNKNOWN (warn, never protect) to avoid
  false curtains. Do not treat detection as a guarantee.

## Reporting

Security concerns: open a GitHub issue, or email the address on the maintainer's GitHub
profile for anything sensitive.
