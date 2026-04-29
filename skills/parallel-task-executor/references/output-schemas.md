# Output Schemas

Emit a single JSON object when every task has terminated. Task-level outcomes live in TASKS.md `[Result]` blocks — the evaluator re-reads them. The JSON carries only the top-level outcome.

**done** — every task reached DONE:

```json
{ "outcome": "done", "session_id": "2026-04-19-..." }
```

**blocked** — one or more tasks are wrong in their description, **including** TASKS.md-level validation failures (cycles, typos in `Depends:`, empty Acceptance, empty or missing TASKS.md). Re-dispatching will not help; the task text needs upstream revision.

```json
{ "outcome": "blocked", "session_id": "2026-04-19-..." }
```

**failed** — one or more tasks exhausted the 3-attempt retry cap.

```json
{ "outcome": "failed", "session_id": "2026-04-19-..." }
```

**error** — infrastructure or tool-layer failure (Task tool errored, filesystem denied, TDD reference missing, TASKS.md not found):

```json
{ "outcome": "error", "session_id": "2026-04-19-...", "reason": "TDD reference file missing at <path>" }
```

Output is consumed by the main thread to dispatch the next skill per the SKILL.md 'Required next skill' section.

Never emit prose alongside the JSON. If partial progress was made, leave TASKS.md `[Result]` blocks reflecting reality — the main thread may re-dispatch the executor and it will resume per Step 1's resume rules.
