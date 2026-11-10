# Portable secret scanner review — 6 October 2026

Baseline: c61d5efa27b87223462032f2e1ba2bb6de69708b.

## Fixed
1. Git failures no longer become a false CLEAN result; non-repositories and shallow history fail closed.
2. History scanning covers all reachable local refs, rather than only the current branch.
3. Staged and tracked working files are scanned, including a staged candidate subsequently removed only from the working copy.
4. Candidate values are never printed. Optional gitleaks output is suppressed and redaction requested.
5. Scanner failures are distinguished from candidate findings; a failed gitleaks run cannot silently fall through to a heuristic clean result.

## Evidence
The initial 12-test harness exposed 10 failures in the original script. The final expanded suite contains 15 passing tests using temporary local Git repositories and synthetic strings. Bash syntax and whitespace checks pass. The repository's full locally reachable history and staged/tracked contents pass the limited heuristic scanner.

Run: `python3 -m unittest discover -s tests -v`, `bash -n scripts/secret-scan.sh`, `bash scripts/secret-scan.sh`.

## Not verified
`bash verify.sh` was attempted and stopped at `swift: command not found` (exit 127). Native Swift checks, builds, signing, camera, Touch ID and hardware behavior were not run. No application/runtime code changed. Actual gitleaks is not installed here; its invocation, failure handling and redaction boundary are tested with an offline executable stub. Keep this PR draft until native verification.

The fallback remains a narrow pattern heuristic, not a security guarantee. Untracked/ignored files, unreachable Git objects, refs absent from the clone, binary content and secret formats outside its patterns are not covered. Do not commit secrets based only on this result. False positives require review; the script does not delete data, rewrite history, revoke credentials or weaken its checks automatically.
