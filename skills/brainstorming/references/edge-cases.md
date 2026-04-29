# Brainstorming — Edge Cases

Edge-case handling referenced from `SKILL.md`.

- **User pivots mid-conversation** to an unrelated request (e.g., was clarifying auth refactor, suddenly asks about dashboard UI): emit `{"outcome": "pivot", ...}` as the terminal payload and end with one sentence — "This looks like a new request; stepping back to routing." Router will fire on the next user turn and allocate a fresh session.
- **User answers Phase A with new ambiguity** (e.g., "touches auth, but also something in billing"): absorb it into `scope_hint: multi-system` without a follow-up question — the ambiguity itself is informative.
- **User gives irrelevant Phase A answer** (e.g., answering the "scope" MC with a code snippet): quote the question once and re-ask. If the second answer is also off, set `scope_hint: multi-system` as the conservative default and move on — over-asking is worse than over-escalating scope.
- **Request is actually casual** (becomes clear after one round that the user was asking a question, not requesting work): emit `{"outcome": "exit-casual", ...}` and end with a one-sentence acknowledgment. Log `Last activity: brainstorming exit (reclassified-casual)`.
- **User decomposes voluntarily** (e.g., "yeah, let's start with leads, do deals next"): acknowledge, capture the chosen sub-project as `request`, and note the follow-ups in `constraints` as `"followup-sessions: deals, reporting"`.
- **Router → plan direct** (Phase A skipped): infer `intent` from the first verb in `request`. If none obvious, default to `add`. Don't ask the user — keep the flow terse.
- **Resume with existing classification** (Step 0): emit a route payload pointing to the next `[ ]` phase. Do not re-ask Gate 1.
- **Conflicting signals** (e.g., `migrations/` + "one-line typo"): err toward prd-trd. The cost of over-scoping a trivial migration is a 5-minute PRD; the cost of under-scoping one is a broken schema.
- **User gives file count but no route verdict** ("maybe 8 files?"): recompute route silently and present the new recommendation once more.
- **User names a non-existent route** ("prd-tasks, please"): re-ask once with the four options. If still unclear, use the recommended route.
- **`intent: "other"` with `intent-freeform` constraint**: inspect the freeform verb — refactor-ish → trd-only, fix-ish → tasks-only candidate, create-ish → prd-trd/prd-only. Unparseable → prd-only.
