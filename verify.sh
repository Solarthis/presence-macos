#!/bin/bash
# Single verification entry point. Must exit 0 before any commit that flips a
# checklist item. This is the project's CI (GitHub Actions intentionally unused).
set -euo pipefail
cd "$(dirname "$0")"

echo "== swift build =="
swift build

echo "== Checks =="
swift run Checks

echo "== layer purity gate (PresenceCore must stay camera-free) =="
if grep -rEn "import (AVFoundation|Vision|AppKit|SwiftUI)" Sources/PresenceCore/; then
  echo "FATAL: PresenceCore imports a UI/camera framework — two-layer rule violated"
  exit 1
fi

echo "== security bypass gate =="
# verify.sh and secret-scan.sh legitimately contain these patterns (they ARE the gates) —
# excluded from their own scan; everything else is covered.
if git grep -nE "SECURITY-BYPASS|skipValidation|alwaysAllow|sk-[A-Za-z0-9]{20}" -- Sources build.sh scripts ':!scripts/secret-scan.sh' 2>/dev/null; then
  echo "FATAL: security bypass marker or key-shaped string in tree"
  exit 1
fi

echo "== production timing isolation gate =="
# The app layer may never hard-code safety timing; timing lives only in PresenceCore's
# named configs (MachineConfig.production / .scriptedDemo).
if grep -rEn "(launchGuardSeconds|graceSeconds)[[:space:]]*:[[:space:]]*[0-9]" Sources/Presence/; then
  echo "FATAL: hard-coded safety timing in app layer — use MachineConfig.production/.scriptedDemo"
  exit 1
fi

echo "== authentication boundary gate =="
# Restoration must flow through LocalAuthentication; no alternate success path in the app target.
if ! grep -q "evaluatePolicy(" Sources/Presence/AuthGate.swift \
   || ! grep -q "\.deviceOwnerAuthentication" Sources/Presence/AuthGate.swift; then
  echo "FATAL: AuthGate no longer evaluates deviceOwnerAuthentication"
  exit 1
fi
if grep -rln "restoreAuthenticated" Sources/Presence/ | grep -v "RuntimeCoordinator.swift"; then
  echo "FATAL: restoreAuthenticated injected outside RuntimeCoordinator"
  exit 1
fi

echo "== login boundary gate =="
if git grep -inE "SecurityAgentPlugins|LaunchDaemons|authorizationdb|pam_|SACLockScreen|CGSession" -- Sources scripts build.sh 2>/dev/null; then
  echo "FATAL: forbidden login-path mechanism referenced in code"
  exit 1
fi

echo "VERIFY: ALL GATES GREEN"
