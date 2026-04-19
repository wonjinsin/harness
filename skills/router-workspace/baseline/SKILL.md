---
name: router
description: Trigger at the start of every user turn to classify the request into casual / clarify / plan, detect natural-language resume intent, and allocate a session slug. All downstream skills assume router has run first. Based on oh-my-claudecode/scripts/keyword-detector.mjs — deterministic keyword detection adapted for three-way classification and session allocation.
---

# Router

## Purpose

Every user request enters the harness through this skill. The router answers three questions, in order:

1. **Is this a resume of prior work?** If yes → hand off to the matching session's ROADMAP.
2. **Is this trivial chat or a direct factual question?** → classify as `casual`, reply inline, end.
3. **Is this actionable work?** → classify as `clarify` (requirements unclear) or `plan` (requirements clear).

The router never writes code and never executes tasks. It only decides **where the request goes next**.

All internal reasoning, keyword matching, and user-facing prompts produced by this skill are in English, regardless of the language the user writes in. The LLM still understands non-English input and classifies it correctly — but the skill does not maintain per-language rule tables, and it asks its own clarifying questions (e.g. slug confirmation) in English. Keeping the skill monolingual means one set of rules to maintain and one surface to debug.

## Why three routes

- **casual** exists so small talk and meta-questions don't drag through session allocation, planning, and downstream skills. A user saying "hi" or "what can you do" shouldn't create a `.planning/` directory.
- **plan** is the normal path for work requests with enough signal to proceed — a verb, a target, and enough criteria for `complexity-classifier` to pick a tier.
- **clarify** is the release valve for requests where the user clearly wants work done but the router cannot tell *what work* without asking. The router does not ask those questions itself; `clarifier` owns that conversation.

When in doubt between **plan** and **clarify**, prefer **clarify** — one extra round-trip is cheaper than a plan built on guessed requirements.

## When to use

Trigger this skill as the very first step of every user turn. Skip only when another skill has already handed control off explicitly via `flow.yaml`.

## Procedure

### Step 1 — Resume detection

A resume cue requires **both** signals to co-occur:

- A resume verb: `resume`, `continue`, `pick up where`, or a clear equivalent in the user's language.
- A reference to prior work: an existing slug, a named feature from a past session, or an anaphoric phrase like "that 2FA thing", "yesterday's migration".

Bare "continue" on its own is **not** a resume signal — it usually means "keep going on what you just said in this turn". Without the prior-work reference, treat the message as continuation of the current turn, not session resumption. This discrimination matters because a false positive pulls the user into an old session they didn't ask to reopen.

If both signals are present:

1. Read `.planning/`. If the directory doesn't exist, there are no sessions — fall through to fresh-session flow.
2. For each subdirectory, read `ROADMAP.md`. Keep only sessions with at least one `- [ ]` unchecked item.
3. Match the request against candidates using slug similarity plus overlap with the session's goal/title.
4. **One match** → load that session. Route = `plan` with `session_id` set and `resume: true`. Downstream skips classification and jumps to the next incomplete phase.
5. **Multiple matches** → ask the user to pick. Format: `{slug} — {one-line goal}`.
6. **No match, or user rejects the proposed match** → fall through to fresh-session flow.

### Step 2 — casual / clarify / plan classification

Apply the deterministic regex catalogue first. If nothing fires, make the judgment yourself using the definitions below.

**casual** — classify, reply inline, end the turn:

- Greeting or small talk.
- Tool/meta questions about what the harness can do.
- Pure factual lookup with no code output expected.
- Yes/no confirmation of the router's own last question.

**plan** — hand to `complexity-classifier`:

- An imperative verb acting on this codebase (add, fix, refactor, implement, migrate, build, create, remove, replace, …).
- A named target (file, module, feature).
- Explicit acceptance criteria ("should …", "must …").

**clarify** — hand to `clarifier`:

- A work verb with no clear object ("make it better", "clean it up").
- Conflicting or underspecified requirements.
- A reference to "the bug" or "that feature" with no prior context pinning it down.

The deterministic layer is narrow by design — it only catches unambiguous cases. Everything else relies on the LLM reading the definitions above. When ambiguous between **plan** and **clarify**, choose **clarify**.

### Step 3 — Session slug (fresh sessions only)

Format: `YYYY-MM-DD-{slug}`.

1. Extract a concept from the request. Prefer the direct object of the main verb (e.g., "add 2FA to login" → `add-2fa-login`).
2. Lowercase, ASCII-only, hyphens between words, ≤ 40 chars.
3. Confirm with the user, in English: `Use session id "{date}-{slug}"?`
4. On silence → proceed with the proposal. On rejection → use the user's edit verbatim (re-slug if needed).
5. **Collision**: if `.planning/{date}-{slug}/` already exists, append `-v2`, `-v3`, … until free.

### Step 4 — Scaffold (fresh sessions only)

Create the session directory with skeletons:

```
.planning/{session-id}/
├── ROADMAP.md      ← from templates/roadmap.md, phase count TBD
└── STATE.md        ← from templates/state.md, position = Phase 1 ready to plan
```

Leave the files empty of task content. Downstream skills (`prd-writer`, `trd-writer`, `task-writer`) fill them in.

### Step 5 — Hand off

Emit a structured classification; `flow.yaml` consumes it.

| Route | Next skill | Payload |
|-------|------------|---------|
| `casual` | (END — router replies inline) | — |
| `clarify` | `clarifier` | `{ request, session_id }` |
| `plan` (fresh) | `complexity-classifier` | `{ request, session_id }` |
| `plan` (resume) | `complexity-classifier` (skipped if already classified) → next incomplete phase | `{ request, session_id, resume: true }` |

## Output

Return a single JSON object as the final router payload. Do not surround it with prose.

Schema:

- `route`: `"casual"`, `"clarify"`, or `"plan"`
- `session_id`: `"YYYY-MM-DD-slug"` for `clarify` and `plan`, `null` for `casual`
- `resume`: `true` only when Step 1 matched an existing session, else `false`
- `reply`: full user-facing response string for `casual`; `null` otherwise

### Examples

Input: `hi claude, what can you build?`

```json
{"route":"casual","session_id":null,"resume":false,"reply":"I'm a task-oriented harness — you describe a change, I plan it, break it into tasks, and help you execute. What would you like to work on?"}
```

Input: `add 2FA to login`

```json
{"route":"plan","session_id":"2026-04-19-add-2fa-login","resume":false,"reply":null}
```

Input: `make the auth code better`

```json
{"route":"clarify","session_id":"2026-04-19-improve-auth","resume":false,"reply":null}
```

Input: `let's continue the 2FA work from yesterday` (match found in `.planning/2026-04-18-add-2fa-login/`)

```json
{"route":"plan","session_id":"2026-04-18-add-2fa-login","resume":true,"reply":null}
```

## Keyword catalogue (reference)

The deterministic layer uses the patterns below. Anything they miss falls through to the LLM judgment in Step 2. Patterns are English-only by design — non-English inputs are handled by the LLM layer using the same definitions.

**Resume verb** (must co-occur with a prior-work reference):

- `\b(resume|continue|pick\s+up\s+where|keep\s+going\s+on)\b`

**casual:**

- `^(hi|hello|hey|yo|sup)\b`
- `\b(what\s+can\s+you\s+(do|build)|how\s+does\s+this\s+work|who\s+are\s+you)\b`

**plan (verbs):**

- `\b(add|fix|implement|refactor|migrate|build|create|remove|replace)\b`

**clarify (vague):**

- `\b(make\s+it\s+(better|good|nice)|clean\s+it\s+up|improve\s+the\s+code)\b`

Keep these in sync with `flow.yaml`.

## Boundaries

- Do not plan, decompose, or write code here. Those belong to `complexity-classifier`, `prd-writer`, `trd-writer`, `task-writer`.
- Do not ask clarifying questions beyond session-slug confirmation and multiple-match disambiguation. Any other ambiguity is for `clarifier`.
- Do not modify `ROADMAP.md` / `STATE.md` after creating the skeletons. Downstream skills own those files.
