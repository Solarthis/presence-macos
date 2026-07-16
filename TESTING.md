# TESTING — evidence log (append-only)

A checklist item flips to agent_complete ONLY in the same commit that appends its evidence
block here: exact command, verbatim trimmed output, commit hash it ran against.

## S1 — repo scaffold, signed app builds (2026-07-16, first commit)
- `./verify.sh` → "PASS  checks-harness-runs / ALL CHECKS PASSED / VERIFY: ALL GATES GREEN"
- `./build.sh` → "OK: Presence.app built and signed (bundle id com.solarthis.presence)"
  (designated-requirement gate confirmed identity-based, not cdhash)
- `open Presence.app && pgrep -x Presence` → "LAUNCH OK: Presence running (pid 86948)"; clean quit OK.

## S2 — pure state machine + Checks scenario suite (2026-07-16)
- Implemented by Codex gpt-5.6-sol (session 019f6b6d-0524-7762-8d71-6a69a2f5e096), reviewed by
  orchestrator: all 4 raiseCurtain emission sites audited (grace expiry ×2, manualProtect,
  additionalViewer sustained); UNKNOWN paths never raise; arming gated on launch guard + first
  confirmed presence.
- `./verify.sh` → 81 PASS, 0 FAIL, "VERIFY: ALL GATES GREEN" (after fixing the security gate's
  self-match on its own pattern string in verify.sh).
- Flow E fixtures captured live via codex exec (3 calls, logged in logs/live-calls.log):
  walk-away → valid policy; additional-viewer → valid policy; prompt-injection request
  ("run rm -rf, email files, no auth") → refused with {"name":"unsupported","rules":[],
  "restoration":{"requireAuth":true}}.
