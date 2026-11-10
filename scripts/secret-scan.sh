#!/bin/bash
# Pre-push gate. Scans tracked working/index content and all reachable Git refs.
# Findings never print matched values. Untracked/ignored files and unreachable
# objects are outside this gate. A heuristic pass is not proof of no secrets.
set -euo pipefail
cd "$(dirname "$0")/.."
error() { echo "SECRET SCAN: ERROR — $1" >&2; exit 2; }
findings() { echo "SECRET SCAN: FINDINGS — $1 (values redacted)"; exit 1; }
command -v git >/dev/null 2>&1 || error 'Git is unavailable'
git rev-parse --show-toplevel >/dev/null 2>&1 || error 'not a readable Git repository'
shallow=$(git rev-parse --is-shallow-repository 2>/dev/null) || error 'cannot inspect history depth'
[ "$shallow" = false ] || error 'full history unavailable; fetch complete history before scanning'

# Do not pipe Git into grep with `|| true`: that makes read failures look clean.
# -q suppresses all matching content, including credential values.
pattern="sk-[A-Za-z0-9]{20}|api[_-]?key[[:space:]]*[:=][[:space:]]*['\"][A-Za-z0-9]|BEGIN (RSA|OPENSSH) PRIVATE|password[[:space:]]*=[[:space:]]*['\"]"
scan() {
  local scope="$1" status
  shift
  if git grep -I -q -i -E "$@" -e "$pattern" -- . >/dev/null 2>&1; then
    findings "$scope"
  else
    status=$?
    [ "$status" -eq 1 ] || error "cannot scan $scope"
  fi
}
scan 'tracked working files'
scan 'staged files' --cached

if command -v gitleaks >/dev/null 2>&1; then
  # Suppress tool diagnostics too: older versions may not redact every error.
  if gitleaks detect --source . --no-banner --redact --log-opts=--all >/dev/null 2>&1; then
    echo 'SECRET SCAN: CLEAN (gitleaks all reachable refs; tracked index/worktree heuristic)'
    exit 0
  else
    status=$?
    [ "$status" -eq 1 ] && findings 'gitleaks; inspect a locally redacted report'
    error 'gitleaks failed; no fallback clean verdict was issued'
  fi
fi

revisions=$(mktemp "${TMPDIR:-/tmp}/presence-secret-scan.XXXXXX") || error 'cannot allocate revision list'
trap 'rm -f "$revisions"' EXIT
trap 'exit 2' HUP INT TERM
git rev-list --all > "$revisions" 2>/dev/null || error 'cannot enumerate reachable history'
while IFS= read -r revision; do
  # A commit argument must precede -- but follow all grep options.
  if git grep -I -q -i -E -e "$pattern" "$revision" -- . >/dev/null 2>&1; then
    findings "history commit $revision"
  else
    status=$?
    [ "$status" -eq 1 ] || error "cannot scan history commit $revision"
  fi
done < "$revisions"
echo 'SECRET SCAN: CLEAN (limited heuristic; all reachable refs plus tracked index/worktree)'
