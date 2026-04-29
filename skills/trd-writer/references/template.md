# TRD.md template

Err on the side of brevity — a reader should finish the TRD in under 3 minutes. If a section wants to grow beyond its range, that's usually a signal to split an Open question out, not to pad. Sections 4–6 (Interfaces, Data model, Dependencies) may legitimately be `N/A — <one-line reason>` when the change has none; do not pad them with unrelated content.

```markdown
# TRD — {one-line title from PRD or request}

Session: {session_id}
Created: {ISO date}
PRD: {relative path to PRD.md, or "(none)"}

## 1. Context

{1–3 sentences. If PRD exists, summarize the goal in TRD-relevant terms and
 cite the relevant PRD sections by heading name (not section number — headings
 are stable, numbering is positional and silently breaks if the PRD template
 is reordered). If no PRD, state the technical motivation drawn from the
 user request.}

## 2. Approach

{2–5 bullets describing the shape of the solution — the key design decisions,
 not implementation steps. Each bullet should answer "why this shape".}

- {Decision 1 + one-line rationale}
- {Decision 2 + one-line rationale}

## 3. Affected surfaces

{Files/modules that will be created or modified. Group by subsystem if
 crossing boundaries. 1-line note per entry on what changes.}

- `path/to/file.ext` — {what changes}
- `path/to/other.ext` — {what changes}

## 4. Interfaces & contracts

{Concrete signatures, request/response shapes, event names, CLI flags —
 anything that forms a contract with code outside this change. Use code
 blocks for signatures. "N/A — <reason>" if truly nothing added/changed.}

## 5. Data model

{Schemas, tables, persisted structures, message formats — any durable shape.
 "N/A — <reason>" if no persistence or schema change.}

## 6. Dependencies

{External libraries, services, feature flags, other in-flight work this
 depends on. "N/A — <reason>" if self-contained.}

## 7. Risks

{Specific failure modes and how the design mitigates or accepts them.
 Every auth/security/migration concern surfaced during exploration needs an
 entry — downstream phases (task-writer, evaluator) cannot recover those
 requirements from code alone, so a skipped risk fails silently.}

- {Risk 1}: {mitigation or explicit acceptance}
- {Risk 2}: {mitigation or explicit acceptance}

## 8. Open questions

{Every unresolved design decision that affects implementation. Empty if none.
 Format: "- Q: … (impact: …)".}
```
