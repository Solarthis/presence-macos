#!/bin/bash
# Pre-push gate: scan the FULL history for key-shaped strings. Must print CLEAN and exit 0
# before any push. If a hit is real: STOP — history rewrite before publication + revoke key.
set -uo pipefail
cd "$(dirname "$0")/.."
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks detect --source . --no-banner && echo "SECRET SCAN: CLEAN (gitleaks)" && exit 0
  echo "SECRET SCAN: FINDINGS (gitleaks)"; exit 1
fi
hits=$(git log -p | grep -inE "sk-[A-Za-z0-9]{20}|api[_-]?key[[:space:]]*[:=][[:space:]]*['\"][A-Za-z0-9]|BEGIN (RSA|OPENSSH) PRIVATE|password[[:space:]]*=[[:space:]]*['\"]" | grep -v "secret-scan.sh" || true)
if [ -n "$hits" ]; then echo "$hits"; echo "SECRET SCAN: REVIEW THE HITS ABOVE"; exit 1; fi
echo "SECRET SCAN: CLEAN (grep fallback over full history)"
