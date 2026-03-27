# PR Body Templates

## Non-Trivial PRs (features, refactors, multi-file changes)

Use this structure when the PR changes multiple files, adds a feature, refactors code, or fixes a non-trivial bug:

```
## Problem
What was broken, missing, or inadequate? Include user/team impact.

## Solution
What changed and how it works. Key decisions made.

## Why
Why this approach? What does it unblock?

## Test plan
- [ ] Verification step 1
- [ ] Verification step 2
```

**Guidelines:**
- Problem section: focus on impact, not implementation ("users couldn't log in" not "the auth middleware was missing")
- Solution section: explain the approach, not the diff ("added retry logic with exponential backoff" not "changed lines 42-58")
- Why section: explain tradeoffs ("chose retry over circuit breaker because the failure rate is < 1%")
- Test plan: specific verification steps a reviewer can follow

## Trivial PRs (typo, config tweak, single file)

1-2 sentence summary. Don't force the full structure when it adds no value.

Examples:
- "Fix typo in README installation section."
- "Update CI timeout from 10m to 15m after flaky test investigation."

## Detection Heuristic

A PR is **trivial** when ALL of these are true:
- Single file changed
- Change category is docs, chore, or typo
- No behavioral change

Everything else is **non-trivial** — use the full template.
