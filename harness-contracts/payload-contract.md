# Harness payload contract

Single source of truth for what flows between skills. Each skill emits its own JSON status (defined in that skill's `SKILL.md`); the **main thread** constructs the downstream skill's payload by combining the emission with session-wide context fields. This file documents every edge so all three sources of truth (skill emissions, "Required next skill" sections, main-thread dispatch logic) can be checked against one place.

## Node graph

```
                      router
                        │
                        ▼ (clarify | plan | resume)
                   brainstorming
                        │
       ┌────────────────┼─────────────────┬──────────────┐
       ▼                ▼                 ▼              ▼
   (prd-trd)        (prd-only)        (trd-only)     (tasks-only)
       │                │                 │              │
       ▼                ▼                 ▼              ▼
   prd-writer       prd-writer        trd-writer     task-writer
       │                │                 │              │
       ▼                ▼                 │              │
   trd-writer       task-writer ──────────┤              │
       │                │                 ▼              │
       └───────┬────────┴───────────► task-writer ◄──────┘
               ▼
       parallel-task-executor
               │
               ▼ (done)
           evaluator
               │
               ▼ (pass)
          doc-updater
               │
               ▼ (terminal)
              END
```

Non-pass terminals: `router → casual` (no JSON, inline reply), `brainstorming → pivot|exit-casual`, `*-writer → error`, `executor → blocked|failed|error`, `evaluator → escalate|error`. Each ends the session — main thread reports to the user and stops.

## Session-wide fields

The main thread carries these forward across the chain. They are not part of any single skill's emission.

| Field | Source | Lifetime |
|---|---|---|
| `session_id` | router (Step 3) | Whole session |
| `request` | user's original turn, captured at router | Whole session |
| `brainstorming_output` | brainstorming emission `brainstorming_output` | From brainstorming onward |
| `brainstorming_outcome` | brainstorming emission `outcome` (`prd-trd`/`prd-only`/`trd-only`/`tasks-only`) | From brainstorming onward |

## Per-edge payloads

Each entry: **emission** (what the upstream skill writes) → **payload** (what the main thread sends downstream). Renames and additions are called out explicitly so drift is detectable.

### router → brainstorming

- Trigger: emission `outcome ∈ {clarify, plan, resume}`. (`casual` ends inline; no downstream.)
- Emission: `{ outcome, session_id }`.
- Payload: `{ session_id, request, route, resume? }`.
  - `route` = emission `outcome`. Renamed because `brainstorming` uses `route` semantically (the requested intake mode), reserving `outcome` for its own emission.
  - `resume` = `true` iff emission `outcome == "resume"`; absent otherwise.
  - `request` = the user's verbatim turn (session-wide).

### brainstorming → prd-writer

- Trigger: emission `outcome ∈ {prd-trd, prd-only}`.
- Emission: `{ outcome, session_id, request, brainstorming_output }`.
- Payload: `{ session_id, request, brainstorming_outcome, brainstorming_output }`.
  - `brainstorming_outcome` = emission `outcome`. Renamed so prd-writer's own `outcome` field can carry its terminal status without collision.

### brainstorming → trd-writer

- Trigger: emission `outcome == "trd-only"`.
- Emission: same shape as above.
- Payload: `{ session_id, request, brainstorming_outcome: "trd-only", brainstorming_output, prd_path: null }`.

### brainstorming → task-writer

- Trigger: emission `outcome == "tasks-only"`.
- Emission: same shape as above.
- Payload: `{ session_id, request, brainstorming_output, prd_path: null, trd_path: null }`.

### prd-writer → trd-writer

- Trigger: prd-writer emission `outcome: "done"` AND `brainstorming_outcome: "prd-trd"`.
- Emission: `{ outcome, session_id, brainstorming_outcome, path }`.
- Payload: `{ session_id, request, prd_path, brainstorming_outcome: "prd-trd", brainstorming_output }`.
  - `prd_path` = emission `path` (rename: the writer reports its written file; downstream consumes it as the upstream PRD).

### prd-writer → task-writer

- Trigger: prd-writer emission `outcome: "done"` AND `brainstorming_outcome: "prd-only"`.
- Emission: same as above.
- Payload: `{ session_id, request, prd_path, trd_path: null, brainstorming_output }`.

### trd-writer → task-writer

- Trigger: trd-writer emission `outcome: "done"`.
- Emission: `{ outcome, session_id, path }`.
- Payload: `{ session_id, request, prd_path, trd_path, brainstorming_output }`.
  - `trd_path` = emission `path`. `prd_path` is whatever the trd-writer received (may be `null` for trd-only routes).

### task-writer → parallel-task-executor

- Trigger: task-writer emission `outcome: "done"`.
- Emission: `{ outcome, session_id, path }`.
- Payload: `{ session_id }`.
  - The executor reads `.planning/{session_id}/TASKS.md` from disk; it does not need `path` in the payload.

### parallel-task-executor → evaluator

- Trigger: executor emission `outcome: "done"`. (`blocked`/`failed`/`error` terminate.)
- Emission: `{ outcome, session_id }`.
- Payload: `{ session_id, tasks_path, rules_dir?, diff_command? }`.
  - `tasks_path` = `.planning/{session_id}/TASKS.md` (deterministic; main thread constructs).
  - `rules_dir`, `diff_command` come from main-thread configuration; both are optional.

### evaluator → doc-updater

- Trigger: evaluator emission `outcome: "pass"`. (`escalate`/`error` terminate.)
- Emission: `{ outcome, session_id }` (plus optional `reason` on non-pass).
- Payload: `{ session_id, tasks_path, diff_command? }`.

### doc-updater (terminal)

- Emission: `{ outcome, session_id }` (plus `reason` on `error`).
- No downstream — the harness reports to the user and stops.

## Conventions

- **Skill `outcome` is universal.** Every skill's emission has an `outcome` field naming its terminal state. The next skill receives any *payload* the main thread builds; it never reads the upstream's `outcome` directly under that name.
- **Path → typed name on rename.** When a writer emits `path`, the downstream payload renames it to `prd_path` / `trd_path` so receivers can tell which document they are getting at field-name level (the receiver may have multiple upstream docs).
- **`null` is preferred over absent fields** for documents that are conceptually expected but not produced this session (e.g., `prd_path: null` on the trd-only route). This lets receivers branch on `payload.prd_path === null` rather than `'prd_path' in payload`.

## See also

- `execution-modes.md` — Subagent vs Main context contract.
- `output-contract.md` — Writer-family payload/output/error shape.
- Each skill's `## Required next skill` section — the per-skill view of the same edges.
