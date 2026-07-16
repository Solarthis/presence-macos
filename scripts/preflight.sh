#!/bin/bash
# Phase-0 environment assertions. Run on every session start; paste output into STATE.md.
# HARD assertions exit 1 (stop and report — do not improvise around them). Soft ones warn.
set -uo pipefail
fail=0
hard() { if eval "$2"; then echo "OK    $1"; else echo "FATAL $1"; fail=1; fi; }
soft() { if eval "$2"; then echo "OK    $1"; else echo "WARN  $1"; fi; }

hard "CLT toolchain (no Xcode expected)" '[ "$(xcode-select -p)" = "/Library/Developer/CommandLineTools" ]'
hard "swift present" 'command -v swift >/dev/null'
hard "signing identity MB77Q6TVVS present" 'security find-identity -v -p codesigning | grep -q FCD7116289F2B86E3CA5477065F9172129AA68E6'
hard "repo not under banned path" '[ "$(pwd -P | grep -c "MACBOOK FACE ID")" = "0" ]'
soft "codex CLI authenticated (Flow E rung 2)" 'codex login status 2>/dev/null | grep -qi "logged in"'
soft "gh authenticated" 'gh auth status >/dev/null 2>&1'
soft "built-in camera present" 'system_profiler SPCameraDataType 2>/dev/null | grep -q "FaceTime HD"'
echo "NOTE  OPENAI_API_KEY $( [ -n "${OPENAI_API_KEY:-}" ] && echo PRESENT || echo 'ABSENT (Rung 1 closed — decided, do not revisit)' )"
now=$(date +%s); freeze=$(date -j -f "%Y-%m-%d %H:%M:%S" "2026-07-19 23:59:00" +%s 2>/dev/null || echo 0)
[ "$freeze" -gt 0 ] && echo "NOTE  time to agent freeze: $(( (freeze - now) / 3600 )) hours"
exit $fail
