# Brainstorming — Full Procedure

The complete Q&A protocol referenced from `SKILL.md`. Step 0 → Phase A (A1–A4) → Phase B (B1–B7).

## Step 0 — Resume short-circuit

If `resume: true`, read `.planning/{session_id}/ROADMAP.md`. If it contains a `Complexity: X` line (X ∈ prd-trd / prd-only / trd-only / tasks-only) **and** the `brainstorming` phase is `[x]`, do **not** re-intake. Emit a route payload that points downstream to the next incomplete phase per `harness-flow.yaml` and end. Rationale: re-asking the user "which route?" when they already decided it last session wastes a turn and erodes trust.

If `resume: true` but classification is missing (e.g., session was interrupted mid-Gate-1), proceed normally — skip Phase A (router only picks `resume` when prior signal is sufficient) and start Phase B.

## Phase A — Clarify (only when `route == "clarify"`)

If `route == "plan"` or `route == "resume"`, **skip Phase A entirely** and start at B1. Router decided the request had enough signal; re-asking would duplicate work.

### A1 — Extract, then assess scope

Before asking anything, do both in order:

**(a) Fill from what the request already gives you.** Read `request` and tentatively fill the actionability checklist (`intent`, `target`, `scope_hint`, `constraints`, `acceptance`) from what the user already said. Ask only about genuine gaps. Asking a question whose answer is already in the request is the most common failure mode of a clarifying step. If the user wrote "refactor the DB layer for clarity", `intent=refactor` and `target=DB layer` are already filled — don't re-ask.

**(b) Assess scope — one session or many?** If the request describes multiple independent subsystems (e.g., "build a platform with chat, file storage, billing, and analytics"), **flag this immediately** before spending field questions on it. Propose decomposition:

> "This looks like several distinct sub-projects: {list}. One session should own one coherent piece. Which one do you want to start with? The others can be separate sessions."

If the user picks one, update `request` in the payload to describe just that sub-project and proceed. The other sub-projects become future sessions — router will fire fresh on each one.

If the user insists on tackling all of it as one session, proceed but record `constraints: ["deliberately-wide-scope"]` so Phase B leans toward `prd-trd`.

Skip the scope check for obviously single-scope requests — don't ask "is this one project?" for "fix the login timeout bug".

### A2 — Ask the missing fields, one at a time

Priority order — **first unfilled field wins, but only after re-running A1(a) on the latest answer.** A single user reply often fills multiple fields at once (e.g., "refactor session handling for clarity" fills intent + target + partial scope). After every user turn, re-extract from the whole conversation before choosing the next question. Don't walk the list top-to-bottom blindly.

1. **intent** — usually inferable, but when ambiguous: "Sounds like this is about {candidate}. Which fits best?" Offer MC: add / fix / refactor / migrate / remove / other. If the user's verb genuinely fits none of the five, record `intent: "other"` **and** append `"intent-freeform: <verb>"` to `constraints` so Phase B can see the original verb.
2. **target** — "Which part of the codebase does this touch?" Open-ended, or MC if plausible candidates are visible.
3. **scope_hint** — "Is this contained to one place, one subsystem, or does it ripple across systems?" MC: single-file / subsystem / multi-system.
4. **constraints** — ask *only* when there is a plausible constraint you can name from context. Example for auth changes: "Any backward-compat requirement for existing sessions?" Do not fish for constraints with generic prompts.
5. **acceptance** — "How will we know this is done?" Open-ended.

Rules:

- **One question per turn.** Never batch. A wall of questions is the anti-pattern we are avoiding.
- **Prefer multiple choice** when plausible options exist. Users answer MC faster and more precisely than open-ended.
- **Mirror the user's language** in questions and confirmations — the skill's rules and field names stay English, but the conversation follows the user. If they write Korean, ask in Korean.
- **YAGNI on questions.** Only ask what's needed to classify and draft. If an answer wouldn't change the route or the writer's first draft, don't ask it.
- **Stop when required fields are filled.** Optional fields empty is fine.

### A3 — Early exit

If the user says anything like "just start", "go ahead", "skip it", "whatever, you decide" — stop asking immediately and proceed to Phase B with whatever is filled. Record skipped fields in `STATE.md` under `Last activity` so downstream knows the payload is thin:

```
Last activity: 2026-04-19 13:44 — brainstorming clarify exit (user-skip); missing: acceptance
```

Thin payload is not a failure — it is a user signal that they want velocity over precision. Phase B and writers handle thin payloads by asking their own narrow questions at the moment the missing info becomes blocking.

### A4 — Confirm, then proceed

When the required checklist is complete, send **one short confirmation** in the user's language:

> "Got it — {intent} {target}, {scope_hint}. {constraint summary if any}. {acceptance if stated}. Now picking a route."

The confirmation is its own message — do not bundle the route recommendation with it. On the **next** user turn:

- Accept ("yes", "looks good", silence/no correction) → proceed to Phase B (start at B1).
- Correct a field → loop back to A2 for *that field only* and re-confirm. Revising ≠ restarting; do not re-ask fields they already answered correctly.
- Pivot or reveal it was a question → emit `pivot` / `exit-casual` payload (see Edge cases) and end.

## Phase B — Classify + Gate 1

### B1 — Signal detection

Two kinds of signals:

**(a) Path signals — literal, language-agnostic.** Scan `request`, `target`, and `constraints` for these file-path patterns:

- `auth/`, `security/` — authentication/authorization
- `schema.*`, `*/schema/` — DB or API schemas
- `migrations/` — DB migrations
- `package.json`, `*/package.json` — dependency/version changes
- `config.ts`, `*.config.*` — global configuration

Paths are filesystem literals — match them the same in any language. Record hits as `signals_matched: ["path:auth/", ...]`.

**(b) Keyword signals — semantic, multilingual.** Detect whether the request semantically refers to any of these concepts: authentication, login, password, session, database, schema, migration, configuration, dependency. These are concepts, not literal strings — "로그인", "認証", "authentification" all count as the auth/login concept. Use judgment, not a fixed keyword table. Record hits as `signals_matched: ["keyword:login", "keyword:dependency", ...]`.

**(c) `deliberately-wide-scope` constraint** (Phase A's flag when the user insisted on multi-subsystem scope): implicit `prd-trd` signal. Record as `signals_matched: ["constraint:deliberately-wide-scope"]`.

### B2 — File-count estimate

Produce a single integer N — best-guess total of modified + newly created files.

Calibration:

- Typo / format / comment-only → 1
- Single-subsystem bug fix → 1–3
- One new endpoint or page → 2–4
- Feature across multiple layers → 5–12
- Cross-cutting migration or framework swap → 10–30+

Don't overthink this. One rough integer is enough — the user can override in B6. If the request is too vague to estimate at all (and Phase A didn't run to pin `target`), pick 3 as a neutral default and flag low confidence in the Gate 1 message.

### B3 — Tier determination

Apply in order:

1. Any entry in `signals_matched` → **prd-trd candidate** regardless of file count.
2. Otherwise, by intent:
   - `add` / `create` + N ≥ 5 → **prd-trd**
   - `add` / `create` + N < 5 → **prd-only**
   - `refactor` / `migrate` / `remove` → **trd-only**
   - `fix` + N ≤ 2 → **tasks-only candidate** (must pass B4)
   - `other` with `intent-freeform` in constraints → parse the freeform verb: refactor-ish → trd-only, fix-ish → tasks-only candidate, create/add-ish → prd-trd if N ≥ 5 else prd-only. Unparseable → prd-only.
   - `other` or intent missing (no freeform hint) → **prd-only** (conservative — lightweight PRD costs less than wrong route).

### B4 — tasks-only self-verification

Only runs when B3 yielded a tasks-only candidate. Check all four:

- [ ] Clearly a bug fix, typo, formatting, or comment-level change?
- [ ] Estimated files ≤ 2?
- [ ] No security/architecture signal matched?
- [ ] No "design needed" cues in the request (new terminology, ambiguous intent, mention of a new concept)?

**Any fail → promote to prd-only** (a minimal PRD is cheap insurance). All pass → tasks-only stays. Rationale: "simple" projects are where unexamined assumptions cause the most wasted work. This gate exists to stop the model from rationalising its way past design.

### B5 — Gate 1 — present recommendation

Send **one** user-facing message as its own turn, in the user's language, with this shape:

> "Recommend **{route}** ({expansion}). Estimated {N} files. {signals summary or 'no security/architecture signals.'} Proceed?"

Examples:

- `"Recommend prd-only (PRD → Tasks). Estimated 3 files, no security signals. Proceed?"`
- `"Recommend prd-trd (PRD → TRD → Tasks). Estimated 4 files, touches auth/ (security-sensitive). Proceed?"`
- `"Recommend tasks-only. Typo fix, 1 file, no signals. Skip design and go straight to tasks?"`

This message is standalone — do **not** bundle the output JSON with it. Offer MC implicitly: accept / change route / adjust file count. Do not batch more than this — signals + file count + route is the whole decision surface. Then wait for the user's next turn.

### B6 — Handle the response (next user turn)

On the **next** user turn, classify the response into one of four actions:

- **Accept** ("yes", "proceed", silence/no-correction) → go to B7 with the current route. `user_overrode: false`.
- **Route override** ("make it prd-trd" / "just do tasks-only") → go to B7 with the user's route. `user_overrode: true`. Do not argue — the user is the final authority.
- **File-count override** ("more like 10 files") → re-run B3 with the new N and loop back to B5 **once only** with the new recommendation. This is the only loop allowed; a second file-count change uses the second value without another recomputation-then-ask.
- **Pivot or casual** — see Pivot handling below.

Do **not** ask clarifying questions about `intent` / `target` / `scope_hint` here — that was Phase A's job. If those fields are missing and feel load-bearing, pick the conservative route (prd-only for add-like, trd-only for refactor-like) and hand off; the writer will surface gaps at its own layer.

**Pivot handling.** If the user asks about an unrelated topic or drops this request entirely, emit `{"outcome": "pivot", ...}` as the terminal payload and end the skill with one sentence: "This looks like a new request; stepping back to routing." Do **not** update ROADMAP/STATE. If instead the user's response reveals they were asking a question about tiers rather than requesting classified work, emit `{"outcome": "exit-casual", ...}` and end with a one-line acknowledgement.

### B7 — Commit + emit (route outcome path only)

On acceptance (including override):

1. **Update `ROADMAP.md`**:
   - Add / update the line `Complexity: {route} ({expansion})` near the top.
   - Mark `- [ ] brainstorming` → `- [x] brainstorming    → {route} (approved)`. If `user_overrode`, use `→ {route} (overridden from {recommended-route})` instead. The user_overrode bit lives on this single row — there is no separate `gate-1-approval` checkbox (Gate 1 is absorbed into brainstorming, so a second row would be redundant).
2. **Update `STATE.md`**:
   - `Current Position: {next phase per harness-flow.yaml}`
   - `Last activity: {ISO timestamp} — classified as {route}{, user-overrode if applicable}`
3. **Resolve `next`** — perform the next-node lookup per `using-harness § Core loop` steps 3–5 against this skill's outgoing edges. The resolution table is fixed by the route → first-listed-candidate rule:
   - `prd-trd` / `prd-only` → `prd-writer`
   - `trd-only` → `trd-writer`
   - `tasks-only` → `task-writer`
   - `pivot` / `exit-casual` → `null` (no edge matches)
4. **Emit the route payload** as the final message — `outcome` is the route name (`prd-trd`/`prd-only`/`trd-only`/`tasks-only`) and `next` is the resolved downstream node id. Main thread evaluates `when:` expressions in `harness-flow.yaml` and dispatches the correct writer agents (cross-checking against `next`).
