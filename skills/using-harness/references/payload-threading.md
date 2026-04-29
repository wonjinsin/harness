### Threading upstream outcomes through payloads

A downstream `when:` expression may reference an upstream node's output (e.g., `task-writer`'s `when:` reads `$brainstorming.output.outcome`). For a dispatched skill to evaluate its own outgoing edges, it needs those upstream values in its payload.

Convention: when dispatching a node, include in the payload every upstream `outcome` referenced by that node's downstream edges in `harness-flow.yaml`. Today this means:

- `prd-writer` payload includes `brainstorming_outcome` (its downstream `trd-writer` / `task-writer` `when:` both reference `$brainstorming.output.outcome`).
- `trd-writer` payload includes `brainstorming_outcome` (its downstream `task-writer` `when:` references it).
- All other skills' downstream edges either have no `when:` or reference only the immediate upstream's outcome (which the skill already has as its own `outcome`), so no extra payload field is needed.

If you add a new edge whose `when:` references an upstream outcome the dispatched skill doesn't currently receive, update both the flow file and the payload schema in the skill's SKILL.md.
