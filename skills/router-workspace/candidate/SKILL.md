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

A resume cue requires **both** a resume verb and a reference to prior work. See "Anaphoric resume signals" below for what counts as a prior-work reference and why bare resume verbs without anaphor don't qualify.

If both signals are present:

1. Read `.planning/`. If the directory doesn't exist, there are no sessions — fall through to fresh-session flow.
2. For each subdirectory, read `ROADMAP.md`. Keep only sessions with at least one `- [ ]` unchecked item.
3. Match the request against candidates using slug similarity plus overlap with the session's goal/title.
4. **One match** → load that session. Route = `plan` with `session_id` set and `resume: true`. Downstream skips classification and jumps to the next incomplete phase.
5. **Multiple matches** → ask the user to pick. Format: `{slug} — {one-line goal}`.
6. **No match, or user rejects the proposed match** → fall through to fresh-session flow.

### Step 2 — casual / clarify / plan classification

Apply the heuristics in "Classification signals" and "False-positive traps" below. The keyword catalogue at the end lists narrow regex hints that match unambiguous cases; everything else relies on reading the definitions and applying judgment.

When ambiguous between **plan** and **clarify**, choose **clarify**.

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

## Classification signals

### casual

**Positive signals** — at least one must hold:

- Greeting or small talk (`hi`, `hello`, `hey`, `안녕`).
- Meta-question about the harness itself ("what can you do", "how do I use this").
- Pure factual lookup with no execution request ("what's a closure in JS?", "what does NOT NULL mean").
- Yes/no confirmation of the router's own last question.
- A question *about* an action verb ("how do I add …", "why does fix fail") — asking for information, not issuing a command.

**Negative signals** — presence suggests not casual:

- Imperative verb with named target pointing at this codebase.
- Explicit acceptance criteria ("should …", "must …").
- Reference to an error, failing test, or broken state expecting repair.

### plan

**Positive signals** — at least one must hold:

- Imperative verb + named target in this codebase ("add 2FA to login", "fix src/auth.ts:42", "refactor the DB layer").
- Explicit acceptance criteria phrased as "should …" / "must …" / "해야 한다".
- Reference to a failing test, error message, or stack trace paired with repair intent.

**Negative signals** — presence suggests not plan:

- Question form ("how do I", "what happens if") → casual.
- Past or subjunctive tense ("I already added …", "we would fix it if …") → casual or clarify.
- No named target paired with vague evaluation ("make it better") → clarify.

### clarify

**Positive signals** — at least one must hold:

- Work verb with no clear object ("make it better", "clean it up", "improve the code").
- Conflicting or underspecified requirements ("fast but also thorough", "simple but full-featured").
- Reference to "the bug", "that feature", "the issue" with no prior context pinning it down.
- Imperative present but target is ambiguous between multiple plausible referents.

**Negative signals** — presence suggests not clarify:

- Target is unambiguous in the conversation context → plan.
- No execution intent at all → casual.

### Boundary cases

| Input | Route | Why |
|-------|-------|-----|
| `fix the login bug`                                   | plan    | Named target + imperative |
| `fix the bug`                                         | clarify | Target unpinned, no prior context |
| `how do I fix a login bug?`                           | casual  | Question form, no execution intent |
| `add JWT auth to /login in src/api.ts`                | plan    | Imperative + named file + named feature |
| `make the auth code better`                           | clarify | Vague evaluation, no concrete criterion |
| `I already added 2FA, what's next?`                   | casual  | Status report, no execution intent |
| `what's the difference between JWT and sessions?`     | casual  | Pure factual question |
| `the spec says "add 2FA", what do you think?`         | casual  | Discussing a reference, not issuing it |

## False-positive traps

Action words (`add`, `fix`, `refactor`, `implement`, `migrate`) inside the following contexts do **not** count as user intent. A keyword that appears only in these positions should not move the classification toward `plan`.

1. **Fenced code blocks** — ```` ``` ```` or inline `` `…` ``. Code examples contain action verbs as identifiers or sample code, not commands.
2. **Block quotes** — lines starting with `>`. The user is referencing someone else's text.
3. **Quoted strings** — `"add 2FA"` inside a larger sentence like `the spec says "add 2FA"` is a reference, not a command.
4. **File paths and identifiers** — `src/add-user.ts` contains "add" but isn't a command.
5. **Echoed instruction text** — if two or more review-outcome labels (approve / request-changes / blocked / merge-ready) appear in the first 20 lines, the prompt is reviewing instructions, not issuing them.
6. **Slash command echoes** — `run /fix` mentions a command rather than invoking it.
7. **Past or subjunctive tense** — "I already added …", "we would refactor if …" are status reports, not requests.
8. **Question forms** — "how do I add …", "why does fix fail?" ask about a verb, they don't invoke it.

Principle: the signal is **action intent directed at this turn**, not mention of an action word. When unsure, ask: "If I treat this as a plan, does the user actually want work to start now?" If no, downgrade to `casual` or `clarify`.

## Anaphoric resume signals

A resume verb (`resume`, `continue`, `pick up where`, `keep going on`, `go back to`) requires a **reference to prior work** to count as a resume cue. Prior-work references take these forms:

1. **Explicit slug** — the user names an existing session id or a close variant.
2. **Named feature** — "the 2FA work", "the auth migration", "the profile page" — a noun phrase that matches a past session's goal or title.
3. **Temporal anaphor** — "yesterday's …", "this morning's …", "last session's …", "the one we started Monday".
4. **Demonstrative anaphor** — "that bug", "that feature", "that thing we were doing", "the one where login broke".
5. **Process anaphor** — "where we left off", "what I was working on", "the paused phase".

When any of these co-occurs with a resume verb, treat it as a resume cue and run the `.planning/` match.

Bare resume verbs with **no** anaphor default to current-turn continuation. Example: after the assistant says "I'll refactor this now", the user's "continue" means "go ahead with that", not "reopen a prior session".

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

The patterns below are hints — they mark unambiguous cases for fast classification. Anything they miss (and anything that appears in a false-positive-trap context) falls to the heuristics above. Patterns are English-only by design; non-English inputs rely on the LLM layer applying the same definitions.

**Resume verb** (must co-occur with anaphor per "Anaphoric resume signals"):

- `\b(resume|continue|pick\s+up\s+where|keep\s+going\s+on|go\s+back\s+to)\b`

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
