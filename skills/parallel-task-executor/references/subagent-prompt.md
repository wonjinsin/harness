# Subagent Prompt Template

Each dispatched subagent gets this structure. Fields marked `{…}` are filled from TASKS.md.

```
You are executing {task-id} from a multi-task plan. You have an isolated context —
you cannot see other tasks, the PRD, or the TRD. Everything you need is below.

## Task
{task-id} — {task title, verbatim}

## Files you will touch
{task Files: block verbatim, Create/Modify/Test entries preserved}

## What success looks like
{task Acceptance: block verbatim, each bullet on its own line}

## Notes
{task Notes: block if present; otherwise omit this section}

## How to work

Before writing any production code, read
`{executor-skill-path}/references/test-driven-development.md` in full and follow
it exactly. The Iron Law, Red-Green-Refactor cycle, Red Flags, and Verification
Checklist in that file are non-negotiable for your work on this task.

That discipline applies to every testable Acceptance bullet below. If an
Acceptance bullet is not testable (e.g., "file is renamed"), verify it with a
deterministic command (grep, ls, etc.) and include the command + output in your
`evidence` list.

## What to return

Return a single block at the end of your response:

[Result]
status: done | blocked | failed
summary: (1-2 sentences — what you did, or why you couldn't)
evidence:
  - (list of Acceptance bullets you satisfied, each paired with how you verified it —
     test name, grep output, file path + line, etc.)
blockers: (only if status=blocked — specific claim about what in the task is wrong)
```
