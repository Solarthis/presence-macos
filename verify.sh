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
if git grep -nE "SECURITY-BYPASS|skipValidation|alwaysAllow|sk-[A-Za-z0-9]{20}" -- Sources scripts build.sh verify.sh 2>/dev/null; then
  echo "FATAL: security bypass marker or key-shaped string in tree"
  exit 1
fi

echo "== login boundary gate =="
if git grep -inE "SecurityAgentPlugins|LaunchDaemons|authorizationdb|pam_|SACLockScreen|CGSession" -- Sources scripts build.sh 2>/dev/null; then
  echo "FATAL: forbidden login-path mechanism referenced in code"
  exit 1
fi

echo "VERIFY: ALL GATES GREEN"
