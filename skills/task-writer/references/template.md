# TASKS.md template + Self-Review

````markdown
# TASKS — {one-line title from PRD/TRD or request}

Session: {session_id}
Created: {ISO date}
PRD: {relative path to PRD.md, or "(none)"}
TRD: {relative path to TRD.md, or "(none)"}

## Goal

{1–2 sentences typically. If PRD exists, restate its Goal in executor-facing terms
 (what the implementer needs to accomplish, not what the user wants).
 If no PRD, extract the goal from TRD Context or `request`.}

## Architecture

{2–3 sentences typically. If TRD exists, distill its Approach into what physically
 changes: which modules, how they connect, what's new vs. modified.
 If no TRD, state the minimum technical picture from Step 2 exploration.}

## Conventions

- Task IDs are stable (`task-1`, `task-2`, ...). Evaluator and executor reference by ID.
- A task is complete when every `Acceptance:` checkbox is satisfied with evidence.
- **Bold terms** are quoted verbatim from PRD/TRD. Do not rename them in code, tests, or commit messages.

---

### task-1 — {imperative verb + object, PRD/TRD vocabulary verbatim}

**Depends:** (none)
**Files:**
- Create: `exact/path/to/new.ext`
- Modify: `exact/path/to/existing.ext:start-end`
- Test: `exact/path/to/test.ext`

**Acceptance:**
- [ ] {Verifiable criterion with **bold** PRD/TRD term, ending with source cite — e.g., "(PRD §Acceptance criteria)"}
- [ ] {Criterion 2}

**Notes:** {1-2 sentences, only if non-obvious. Omit the field entirely otherwise.}

---

### task-2 — ...

**Depends:** task-1
**Files:** ...
**Acceptance:** ...

---

## Self-Review

Performed by task-writer before emitting. Evaluator re-checks these claims.

- [ ] Every PRD Acceptance criterion maps to at least one task's Acceptance bullet (or is deferred to Non-goals).
- [ ] Every TRD Risks entry is referenced in the Notes of the task that creates the risk (or explicitly accepted as out-of-scope for this session).
- [ ] No placeholder strings: "TBD", "similar to task N", "handle edge cases", "add error handling", "write tests for the above".
- [ ] PRD/TRD vocabulary consistency: terms used in one task appear in the same form across all other tasks (no `TOTP` → `2FA` drift).
- [ ] DAG is acyclic; no task depends transitively on itself.
- [ ] No orphan task: every task is reachable from the set of root tasks (`Depends: (none)`), and every task either has a dependent or is a natural leaf.
````

Before writing the Self-Review at the bottom of the file, actually perform each check and only check (`[x]`) the boxes you can honestly certify. Leaving a box unchecked is fine — it signals a known gap the evaluator must scrutinize. Checking a box falsely is worse than missing a task: it directs the evaluator's attention away from a real problem.
