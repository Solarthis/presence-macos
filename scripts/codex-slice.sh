#!/bin/bash
# Run a Codex implementation slice with failure detection.
# Usage: scripts/codex-slice.sh <spec-file> <log-name>
# codex exec can exit 0 even when the model call errors, so we grep the log for
# streamed ERROR lines and require a non-empty git diff under Sources/.
set -uo pipefail
cd "$(dirname "$0")/.."
SPEC="$1"; LOG="logs/$2"
mkdir -p logs

codex exec --cd "$(pwd)" --sandbox workspace-write - < "$SPEC" > "$LOG" 2>&1
rc=$?

sid=$(grep -im1 "^session id:" "$LOG" | awk '{print $NF}')
echo "session id: ${sid:-UNKNOWN}"

if grep -qE '^ERROR: \{"type":"error"' "$LOG"; then
  echo "CODEX SLICE FAILED: API error (see $LOG)"; exit 1
fi
if [ "$rc" -ne 0 ]; then
  echo "CODEX SLICE FAILED: exit $rc (see $LOG)"; exit 1
fi
if git status --short -- Sources/ | grep -q .; then
  echo "CODEX SLICE OK: Sources/ changed"
else
  echo "CODEX SLICE FAILED: no changes under Sources/ (see $LOG)"; exit 1
fi
