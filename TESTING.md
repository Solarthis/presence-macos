# TESTING — evidence log (append-only)

A checklist item flips to agent_complete ONLY in the same commit that appends its evidence
block here: exact command, verbatim trimmed output, commit hash it ran against.

## S1 — repo scaffold, signed app builds (2026-07-16, first commit)
- `./verify.sh` → "PASS  checks-harness-runs / ALL CHECKS PASSED / VERIFY: ALL GATES GREEN"
- `./build.sh` → "OK: Presence.app built and signed (bundle id com.solarthis.presence)"
  (designated-requirement gate confirmed identity-based, not cdhash)
- `open Presence.app && pgrep -x Presence` → "LAUNCH OK: Presence running (pid 86948)"; clean quit OK.
