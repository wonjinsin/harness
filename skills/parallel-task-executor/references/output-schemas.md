# Output Schemas

Emit a single JSON object when every task has terminated. Task-level outcomes live in TASKS.md `[Result]` blocks — the evaluator re-reads them. The JSON carries only the top-level outcome plus the resolved `next`.

**done** — every task reached DONE:

```json
{ "outcome": "done", "session_id": "2026-04-19-...", "next": "evaluator" }
```

**blocked** — one or more tasks are wrong in their description, **including** TASKS.md-level validation failures (cycles, typos in `Depends:`, empty Acceptance, empty or missing TASKS.md). Re-dispatching will not help; the task text needs upstream revision.

```json
{ "outcome": "blocked", "session_id": "2026-04-19-...", "next": "evaluator" }
```

`harness-flow.yaml` advances `executor → evaluator` unconditionally — the evaluator skill detects `[Result: blocked]` blocks and escalates.

**failed** — one or more tasks exhausted the 3-attempt retry cap.

```json
{ "outcome": "failed", "session_id": "2026-04-19-...", "next": "evaluator" }
```

**error** — infrastructure or tool-layer failure (Task tool errored, filesystem denied, TDD reference missing, TASKS.md not found):

```json
{ "outcome": "error", "session_id": "2026-04-19-...", "reason": "TDD reference file missing at <path>", "next": "evaluator" }
```

## Error cascade

Even on `error`, `next: "evaluator"` is emitted because `evaluator`'s edge in `harness-flow.yaml` has no `when:` filter — it fires on any executor outcome. The evaluator will then surface the missing `[Result]` blocks as its own `error`, which is the intended cascade. Main thread may override on `error` if it decides to halt early; the emitted `next` is a hint, not a directive.

Never emit prose alongside the JSON. If partial progress was made, leave TASKS.md `[Result]` blocks reflecting reality — the main thread may re-dispatch the executor and it will resume per Step 1's resume rules.
