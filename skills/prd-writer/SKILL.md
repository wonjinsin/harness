---
name: prd-writer
description: Use when a planning session needs a PRD drafted in an isolated subagent context, before TRD or task decomposition.
---

# PRD Writer

## Purpose

Produce **`PRD.md`** — the product-level spec downstream writers expand into design or tasks. One PRD per session, one shape regardless of tier. Solo-developer lens: enough signal to make implementation decisions, no corporate ceremony. A reader should finish in under 2 minutes.

See `references/contract.md` for the payload schema, output JSON, error taxonomy, and shared anti-patterns.

This skill receives `session_id`, `request`, `brainstorming_outcome` (`"prd-trd"` or `"prd-only"` — required), and optional `brainstorming_output`. If `brainstorming_output` is null, recover intent from the verb in `request` (first-verb rule, default `add`).

## Execution mode

**Subagent (격리 컨텍스트).** 메인 thread 가 Skill 툴로 SKILL.md 를 로드한 뒤 Task 툴로 별도 dispatch. 서브에이전트는 payload 외 메인 대화 히스토리에 접근 불가.

## Procedure

### Step 1 — Read the payload

Re-read `request` in full. Extract intent, target, and visible constraints from the payload. Note what is missing — anything you cannot answer from the payload alone becomes a candidate for Step 2 exploration or Open questions.

### Step 2 — Scoped codebase exploration (budget-capped)

Tool budget: **~15 Read/Grep/Glob calls**. The goal is to ground the PRD in the actual codebase — not to audit it. Stop as soon as the question is answered.

Target-directed: use `target` (if present) to locate the file/module first, then decide width:

- `scope_hint: multi-system` → expand to direct callers and sibling modules.
- Otherwise → stay within the target file/module.

Stop when you can answer: (1) where does the change land? (2) what existing code/concepts does it interact with? (3) are there code-visible constraints (existing schemas, auth flows, config shape) that shape requirements?

If the request is genuinely unknowable from code (pure UX decision, external integration), skip this step and note it in Open questions.

### Step 3 — Draft the PRD using the template

See `references/template.md` for the exact structure and `references/example.md` for a worked example. Fill each section — placeholder ranges (e.g., "1–3 sentences") are sanity checks, not quotas.

**Writing rules**:

- Mirror the user's language in body content; headers stay English.
- Use concrete nouns the user wrote — paraphrasing breaks PRD ↔ TASKS ↔ evaluator traceability.
- Acceptance criteria are checkboxes, each independently verifiable.
- Don't restate the user's request as Goal verbatim. Goal is the *outcome* — "after this change, X is true" — not the ask.
- Tag assumptions in Open questions with `(assumed)`.

PRD-specific anti-pattern (in addition to those in `references/contract.md`): no engineering approach detail (library, interface) — that's TRD/TASKS.

### Step 4 — Write the file

Create `.planning/{session_id}/` if it doesn't exist. Write `PRD.md`. If the file already exists, halt and emit `error` per `references/contract.md`.

### Step 5 — Emit the final JSON

Emit a single JSON object as your entire final message. Required fields:

- `outcome: "done" | "error"`.
- `session_id`.
- `brainstorming_outcome` — echo it back from the payload (the main thread reads it to pick the next skill).
- `path: ".planning/{session_id}/PRD.md"` on `done`.
- `reason: "<short>"` on `error`.

## Required next skill

The next skill depends on `brainstorming_outcome` (echoed in this skill's output):

- `brainstorming_outcome == "prd-trd"` → **REQUIRED SUB-SKILL:** Use harness-flow:trd-writer
  Payload: `{ session_id, request, prd_path, brainstorming_outcome: "prd-trd", brainstorming_output }`
- `brainstorming_outcome == "prd-only"` → **REQUIRED SUB-SKILL:** Use harness-flow:task-writer
  Payload: `{ session_id, request, prd_path, brainstorming_output }`
- On `outcome: "error"` → flow terminates. Report to the user and stop.

## Edge cases

- **Request references files that don't exist**: investigate with Glob to confirm. If truly absent, add an Open question rather than inventing structure.
- **User requested one feature but payload implies multiple**: payload is authoritative (brainstorming may have scoped down). If the mismatch is large, add an Open question.
- **Signals matched `auth/` or `security/`**: Constraints section *must* have an entry — downstream phases cannot recover security requirements from code alone, and skipped constraints fail silently.
- **>2 open questions after drafting**: note them and emit `done`. The next writer surfaces blocking questions; do not self-escalate.

## Boundaries

- Writes only to `.planning/{session_id}/PRD.md`. Do not touch ROADMAP.md or STATE.md.
- Do not invoke other agents or skills. Do not dispatch trd-writer or task-writer — the 'Required next skill' section above dispatches downstream.
- Do not modify source code, even if you spot bugs. Note them in Open questions if load-bearing.
- Tool budget: ~15 Read/Grep/Glob calls. If you need more, halt and emit `error` with a `reason` describing the exhaustion.
