# `[Result]` Block Format

After each group, append or replace a `[Result]` block under each task in TASKS.md. This file is the executor's durable state — the next executor invocation reads these blocks and applies the resume rules.

## Canonical format (using `done` as the reference)

```markdown
[Result]
Status: done
Attempt: 1
Summary: Added POST /auth/totp/verify handler; all 4 Acceptance bullets verified.
Evidence:
- rate-limit bullet → tests/auth/totp.test.ts::"three consecutive failures yield 429"
- intermediate-token consumption → grep "jti.*consumed" src/auth/totp.ts:142
Updated: 2026-04-19T14:23:00Z
```

## Status deltas

Other statuses use the same block with these deltas:

- **failed**: `Status: failed`, bump `Attempt: N` each retry, replace `Evidence` with a single `Reason:` line. `Summary:` is the subagent's summary or `"Task tool errored: <type>"`.
- **blocked**: `Status: blocked`, drop `Attempt` and `Summary`, replace `Evidence` with `Reason:` (one-line cause).
- **skipped** (set in Step 3 without dispatching): `Status: skipped`, drop `Attempt` and `Summary`, `Reason: depends on task-N which {blocked|failed}`.

Always include `Updated:` (ISO-8601). Do **not** modify any other section of TASKS.md (Goal, Architecture, task bodies, Self-Review) — only append or replace the `[Result]` block per task.
