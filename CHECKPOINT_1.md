# CHECKPOINT 1 — consolidated human-validation file (accumulating)

The agent never asks for anything outside this file and CHECKPOINT_2.md. Items get finalized
when the slice-5 build exists; do them in one sitting. Format per step: action → why →
what appears → what NOT to approve → how to confirm.

## Do now (independent of the build)
0. **URGENT — free 5–10 GB of disk space.** The startup disk is at 98% (~0.6 GB free); the failed
   Codex upgrade and build stalls were caused by ENOSPC. → Why: Swift builds + the Codex CLI need
   ~1–2 GB of working headroom; at zero free the whole machine wedges. → Candidates (YOUR choice —
   I will not delete your data): Downloads (5.4 GB), Pictures (6.9 GB), old workspaces
   (liyah_new 3.7 GB, BK 2.3 GB), Trash. → Do NOT delete ~/presence-macos or ~/.codex. → Confirm:
   `df -h /` shows ≥5 GB available.
1. **Open a Devpost draft** — go to openai.devpost.com, sign in as `Solarthis`, click Join/Submit
   and save a DRAFT submission. → Why: protects against deadline-day form surprises; costs nothing.
   → You'll see a draft project page. → Do NOT publish/submit anything yet. → Confirm: draft
   visible in your Devpost dashboard.

## When the slice-5 build exists (I will announce it)
2. **Grant camera access once** — I will have launched `Presence.app` via `open`; click **Allow**
   on the macOS camera dialog. → Why: TCC dialogs cannot be clicked by an agent; the grant
   persists across rebuilds because every build is signed with your Apple Development identity.
   → A standard macOS permission dialog naming Presence. → Do NOT approve any other permission
   (Presence must never ask for Accessibility in this build). → Confirm: menu-bar state leaves
   "camera unavailable".
3. **One real Touch ID unlock** — trigger the curtain from the app's DEBUG menu, then press the
   visible Unlock button and authenticate. → Why: LocalAuthentication needs a human finger.
   → The system Touch ID sheet. → Nothing else. → Confirm: curtain dismisses; event log shows
   restoreApproved.
4. **Fixture photos** — use the app's fixture-capture button to save three frames: empty room /
   you alone / you plus a second person (if available — also tell me now whether a second person
   will be available for filming on July 19–21, so the demo script can branch).
5. **Reply CONTINUE** — I resume at the first unchecked checklist item.
