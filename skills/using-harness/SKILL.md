---
name: using-harness
description: Use when any harness skill finishes, when a user message may start a flow, or at session start — explains how to read harness-flow.yaml and dispatch the next node.
---

# Using Harness

**Harness DAG file**: `${CLAUDE_PLUGIN_ROOT}/docs/harness/harness-flow.yaml` (plugin root, **not** user CWD — the SessionStart hook injects the resolved absolute path; never read it as a relative path). **You = interpreter.** No runtime engine: read the YAML, dispatch the next node yourself. Session artifacts live under `.planning/{session_id}/` (relative — written into the user's project).

## Core loop

After any skill completes (or a user message arrives):

1. **Re-read the harness DAG file** at `${CLAUDE_PLUGIN_ROOT}/docs/harness/harness-flow.yaml` (~60 lines, cheap).
2. **Identify current position** — which node just finished? What was its output JSON?
3. **Find candidate next nodes** — any node whose `depends_on` includes the node you just ran.
4. **Substitute & evaluate `when:`** — replace `$<id>.output.<field>` with actual values from recent outputs, evaluate the boolean (`==`, `||`, `&&`).
5. **Apply `trigger_rule`** — default requires every `depends_on` to have completed; `one_success` fires as soon as one dep produced a matching output.
6. **Invoke the first matching node.** Skills are registered by name when the plugin loads — prefer the `Skill` tool with the bare command name (e.g. `Skill("router")`). If the registry lookup fails, fall back to `Read` on `${CLAUDE_PLUGIN_ROOT}/skills/<command>/SKILL.md`.
7. **No match → flow terminates.** Report final outcome to the user.

## Downstream self-lookup (the `next` field)

Every harness skill emits a `next` field resolved by running steps 1–5 of the Core loop on its own outgoing edges. See `references/design-rationale.md` for why every skill performs the lookup itself. See `references/payload-threading.md` for which payload fields each node must thread.

## Starting the flow

On the first user message of a session:

- **Casual chat / question** (no planning or building intent) → respond normally. Do not engage the harness.
- **Feature / bug / project / "help me build X" request** → invoke `router` (entry node — no `depends_on` in `harness-flow.yaml`).

At flow start, generate `session_id = "YYYY-MM-DD-{slug}"` where slug is a 2-4 word kebab-case summary of the request. Thread this through every subsequent skill invocation.

## Output contract

Every harness skill emits a single JSON object as its final message:

```json
{"outcome": "<value>", "session_id": "<id>", "next": "<node-id>" | null, ...}
```

On error: `outcome: "error"`, add `reason: "<one line>"`, `next: null`. Re-derive your dispatch from `outcome`; treat the skill's `next` as a cross-check signal — log if it disagrees.

## Rules

- **Missing `outcome` field** in a skill's output → treat as flow termination, report to user.
- **Don't recurse endlessly** — if you've invoked the same node twice in a session without making progress, stop and ask the user.
- See the schema header at the top of `harness-flow.yaml` for `when:` expression syntax, `context: fresh` semantics, and tiebreak rules.
