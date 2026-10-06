# Secret scan reliability plan

Scope: repair the portable pre-push scanner without touching camera, authentication, runtime policy or Mac settings. No live model calls.

1. Reproduce false CLEAN when Git fails or history is shallow; require successful repository/history inspection.
2. Reproduce omissions of secrets on other local refs and in staged/unstaged tracked files; scan all reachable refs, index and tracked worktree.
3. Reproduce disclosure of matched values in scanner output; emit only scope and redacted summary.
4. Preserve optional gitleaks use, require redaction and all-ref history, distinguish tool failure from findings, never fall back after scanner failure.
5. Test real isolated Git repositories with synthetic strings, add fault-injected dependency failures, then run Bash syntax and full-history scan. Native Swift verification remains blocked by absent Swift/macOS in this cloud environment; keep PR draft.

No network, credentials or application launch is needed for these tests. Heuristic fallback is explicitly limited; it cannot certify absence of secrets.
