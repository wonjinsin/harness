# PRD.md template

Err on the side of brevity — a reader should finish the PRD in under 2 minutes. If a section wants to grow beyond its range, that's usually a signal to split an Open question out, not to pad.

```markdown
# PRD — {one-line title from request}

Session: {session_id}
Created: {ISO date}

## 1. Problem

{1–3 sentences. Why we are doing this. User-perceivable, not implementation-framed.}

## 2. Goal

{1–3 bullets, each a verifiable outcome after the change.}

- {Outcome bullet 1}
- {Outcome bullet 2}

## 3. Non-goals

{1–4 explicit exclusions — things that could reasonably be scoped in but are not.}

- {Explicit exclusion 1}
- {Explicit exclusion 2}

## 4. Users & scenarios

{One short paragraph — who is affected and in what moment. Add personas only if
 multiple user types behave differently.}

## 5. Acceptance criteria

{2–6 checkboxes. Each must be independently verifiable.}

- [ ] {Verifiable condition 1}
- [ ] {Verifiable condition 2}
- [ ] ...

## 6. Constraints

{Enumerate every signal hit (`auth/` → security, `migrations/` → backward-compat)
 with a 1-line rationale. Empty only if no signals matched.}

## 7. Open questions

{Every unresolved decision that affects the spec. Empty if none.
 Format: "- Q: … (impact: …)".}
```
