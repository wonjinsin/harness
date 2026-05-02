---
name: using-harness
description: Loaded at session start as the meta-skill. Mandates that every user turn begin by invoking `harness-flow:router` — router itself classifies casual / clarify / plan / resume, so the meta-skill never tries to short-circuit that decision. Defines the 'Required next skill' chain (each downstream skill names its successor) and points at `harness-contracts/` for the shared execution-modes, payload, and file-ownership contracts.
model: haiku
---

# Using Harness

The harness is a chained planning + execution flow that turns a feature/bug request into PRD/TRD/TASKS, executes, evaluates, and updates docs. Each skill's SKILL.md declares its own next skill in a "Required next skill" section — follow those markers in order.

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, skip this skill. The harness chain runs in the main context; subagents act on their dispatch prompt.
</SUBAGENT-STOP>

## Entry rule

<EXTREMELY-IMPORTANT>
**Every user turn — your first action MUST be `Skill("harness-flow:router")`.**

Do not pre-classify the message yourself. Classifying casual / clarify / plan / resume is exactly what the router exists to do; skipping it is the single failure mode that causes the harness to silently disengage. Greetings, factual questions, "quick fixes," and meta-questions all enter through router — router replies inline when the verdict is `casual`, and emits a `## Status` for the chain otherwise.

The only legitimate skip: another harness skill is already mid-flow and its `## Required next skill` section names a different next dispatch.
</EXTREMELY-IMPORTANT>

## Red flags — STOP if any of these cross your mind

| Thought | Reality |
|---------|---------|
| "This is just a simple question, I'll answer inline." | The router decides what counts as casual. Invoke it. |
| "This is just a quick fix, I'll edit the file directly." | Quick fixes still route through the harness. Invoke router. |
| "Let me read a few files first to understand the request." | Orientation comes after routing. Invoke router first. |
| "The user is mid-conversation, I don't need to re-route." | Every user turn re-enters at router unless another harness skill named a next skill. |
| "I already know what to do here." | Knowing the answer ≠ skipping the chain. Invoke router. |

## Skill priority

When a harness skill's "Required next skill" section names a follow-up, run it before any other skill the conversation might also match. Treat the chain as load-bearing — skipping a step (e.g., going straight from brainstorming to executor) breaks the per-edge handoff contract. The full graph lives in `harness-contracts/payload-contract.md`.

## Execution mode

Each SKILL.md declares its own `## Execution mode` — either "Main context" (run inline) or "Subagent (isolated context)" (dispatch via Task tool with the procedure as the prompt). Honor that declaration when invoking. Full contract: `harness-contracts/execution-modes.md`.

## Session artifacts

`.planning/{session_id}/` (relative to user CWD): `ROADMAP.md`, `STATE.md`, `brainstorming.md`, `PRD.md`, `TRD.md`, `TASKS.md`, `findings.md`.
