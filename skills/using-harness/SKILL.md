---
name: using-harness
description: Harness bootstrap — you interpret the harness DAG file and dispatch the next node after every skill completes. The DAG file is the single source of truth; this skill teaches you how to read it. Loaded at session start via hook, not invoked manually.
---

# Using Harness

**Harness DAG file**: `${CLAUDE_PLUGIN_ROOT}/docs/harness/harness-flow.yaml`. The SessionStart hook injects the resolved path into context — use whichever absolute path the hook surfaced. **You = interpreter.** No runtime engine. Read the YAML, dispatch the next node yourself.

> The plugin root is wherever Claude Code mounted this plugin (e.g. `~/.claude/plugins/marketplaces/<mp>/plugins/harness-flow/`). Never read `docs/harness/harness-flow.yaml` as a relative path — the user's project CWD won't have it.

## Core loop

After any skill completes (or a user message arrives):

1. **Re-read the harness DAG file** at `${CLAUDE_PLUGIN_ROOT}/docs/harness/harness-flow.yaml` (~60 lines, cheap).
2. **Identify current position** — which node just finished? What was its output JSON?
3. **Find candidate next nodes** — any node whose `depends_on` includes the node you just ran.
4. **Substitute & evaluate `when:`** — replace `$<id>.output.<field>` with actual values from recent outputs, evaluate the boolean (`==`, `||`, `&&`).
5. **Apply `trigger_rule`** — default requires every `depends_on` to have completed; `one_success` fires as soon as one dep produced a matching output.
6. **Invoke the first matching node.** Skills are registered by name when the plugin loads — prefer the `Skill` tool with the bare command name (e.g. `Skill("router")`). If the registry lookup fails, fall back to `Read` on `${CLAUDE_PLUGIN_ROOT}/skills/<command>/SKILL.md`.
7. **No match → flow terminates.** Report final outcome to the user.

## Starting the flow

On the first user message of a session:

- **Casual chat / question** (no planning or building intent) → respond normally. Do not engage the harness.
- **Feature / bug / project / "help me build X" request** → invoke `router` (entry node — no `depends_on` in `harness-flow.yaml`).

At flow start, generate `session_id = "YYYY-MM-DD-{slug}"` where slug is a 2-4 word kebab-case summary of the request. Thread this through every subsequent skill invocation.

## Output contract

Every harness skill emits a single JSON object as its final message:

- Success: `{"outcome": "<value>", "session_id": "<id>", ...}`
- Error: `{"outcome": "error", "session_id": "<id>", "reason": "<one line>"}`

Use this JSON to evaluate downstream `when:` expressions. Never invent output fields — read what the skill actually emitted.

## Context isolation

Nodes marked `context: fresh` should run in an isolated subagent when possible:

- If `Task` / `Agent` tool is available → dispatch via subagent (clean context, heavy skill doesn't pollute main thread).
- Otherwise → run inline, knowing context bleed is a cost.

## Session artifacts

All session state lives under `.planning/{session_id}/`:

- `STATE.md` — main-thread progress ledger
- `PRD.md` / `TRD.md` / `TASKS.md` — writer outputs
- `findings.md` — doc-updater audit log

Skills own their own artifacts; `STATE.md` is main-thread responsibility.

## Rules

- **Strict `==`** in `when:` expressions (exact string match, not fuzzy).
- **Multiple candidates match** → pick the first listed in `harness-flow.yaml`.
- **Missing `outcome` field** in a skill's output → treat as flow termination, report to user.
- **Don't recurse endlessly** — if you've invoked the same node twice in a session without making progress, stop and ask the user.

## Files

- Flow: `${CLAUDE_PLUGIN_ROOT}/docs/harness/harness-flow.yaml` (plugin root, **not** user CWD)
- Skills: registered by name on plugin load — `Skill("<command>")`. Fallback: `${CLAUDE_PLUGIN_ROOT}/skills/<command>/SKILL.md` via `Read`.
- Artifacts: `.planning/{session_id}/` (relative — written into the **user's project**, not the plugin)
