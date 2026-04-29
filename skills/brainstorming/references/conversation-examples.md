# Brainstorming — Conversation Examples

Additional dialogue patterns referenced from `SKILL.md`. The trd-only auth-refactor case is kept inline in the skill body; this file holds the rest.

## Good — plan path (skip Phase A), signal promotion to prd-trd

> Router output: `{outcome: "plan", request: "add 2FA to login", session_id: "..."}`
> Brainstorming: [skips Phase A; B1 hits `auth/` + `keyword:login`]
> Brainstorming: "Recommend **prd-trd** (PRD → TRD → Tasks). Estimated 4 files, touches `auth/` (security-sensitive). Proceed?"
> User: "yeah"
> Brainstorming: [commits, emits `{"outcome": "prd-trd", ...}`]

## Good — tasks-only self-check fails, demoted to prd-only

> Request: "fix the expired-session bug in login"
> intent: fix, N=2 — tasks-only candidate → B1 hits `auth/` → promoted to prd-only
> Brainstorming: "Initially looked like a tasks-only fix, but it touches `auth/` — recommending **prd-only** (PRD → Tasks) instead. 2 files. Proceed, or escalate to prd-trd?"

## Good — user overrides route

> Brainstorming: "Recommend prd-only …"
> User: "Nah, just tasks-only, it's one line"
> Brainstorming: "Got it — tasks-only, user override. Skipping design. Proceeding to task-writer."
> [commits with `user_overrode: true`]

## Good — catching multi-project scope before drilling into fields

> User: "build a complete CRM — leads, deals, reporting, email integration, and mobile app"
> Brainstorming: "This looks like several distinct sub-projects: leads/deals management, reporting, email integration, mobile app. One session should own one coherent piece — which do you want to start with? The others can be separate sessions."

## Bad — batched questions

> Brainstorming: "I need to know: (1) intent, (2) target, (3) scope, (4) constraints, (5) acceptance criteria. Please provide all five."

## Bad — proposing approaches (not this skill's job)

> Brainstorming: "Here are three approaches: A) rename only, B) extract functions, C) rewrite from scratch. Which do you prefer?"

## Bad — re-asking what the request already said

> User request: "fix the login timeout bug in src/auth/session.ts"
> Brainstorming: "What kind of change is this?"
> (intent, target, and scope are all obvious from the request — skip straight to acceptance or route recommendation)

## Bad — silent commit (Gate 1 must be explicit)

> Brainstorming: [writes ROADMAP without asking user]

## Bad — arguing with user override

> User: "just do tasks-only"
> Brainstorming: "Are you sure? It's touching auth/, I recommend prd-trd. Shall I reconsider?" ← the user has already decided; log `user_overrode: true` and move on
