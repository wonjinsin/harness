# Brainstorming — Conversation Examples

Additional dialogue patterns referenced from `SKILL.md`. The trd-only auth-refactor case is kept inline in the skill body; this file holds the rest.

## Good — explore path, ideation → intake → prd-only

> User: "AI로 뭔가 만들어보고 싶은데 뭘 할지 모르겠어"
> Brainstorming: [A1(a) yields no intent or target → A1.5 picks A-explore]
> Brainstorming: "어떤 문제를 풀고 싶으세요? 일상 작업 자동화 / 데이터 분석 / 콘텐츠 생성 같은 큰 방향 중에 끌리는 게 있나요?"
> User: "음, 일상 자동화 쪽인 듯. 이메일 답장 같은 거"
> Brainstorming: "이메일 답장이라면 — 받은 메일에 초안을 만들어주는 보조인지, 자동 발송까지 가는 건지?"
> User: "초안만 만들어주는 거"
> Brainstorming: [A1(a) re-extract: intent=add (new tool), target=이메일 답장 초안 보조 — both pinned]
> Brainstorming: "Sounds like we're building an email-reply draft assistant. Let me pin down the rest."
> [Transitions to A2]
> Brainstorming: "범위는 — 단일 메일 클라이언트 통합(예: Gmail)으로 시작할까요, 여러 클라이언트 지원이 필요한가요?"
> User: "Gmail 만"
> Brainstorming: "확인 — add (new tool) email-reply draft assistant on Gmail, subsystem 범위. 이제 경로를 고르겠습니다."
> User: "ok"
> Brainstorming: "Recommend **prd-only** (PRD → Tasks). Estimated 3 files, no security signals. Proceed?"
> User: "네"
> Brainstorming: [commits, emits `{"outcome": "prd-only", ...}`]

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

## Bad — explore mode crossing into implementation

> User: "AI로 뭔가 만들어보고 싶어"
> Brainstorming: "OpenAI API vs Anthropic API vs 로컬 Ollama 중 어디로 갈까요?" ← implementation choice; that's prd-writer / trd-writer's job. Stay in problem-space ("어떤 문제를 풀고 싶으세요?") until intent + target are pinned, then hand off.

## Bad — re-asking what the request already said

> User request: "fix the login timeout bug in src/auth/session.ts"
> Brainstorming: "What kind of change is this?"
> (intent, target, and scope are all obvious from the request — skip straight to acceptance or route recommendation)

## Bad — silent commit (Gate 1 must be explicit)

> Brainstorming: [writes ROADMAP without asking user]

## Bad — arguing with user override

> User: "just do tasks-only"
> Brainstorming: "Are you sure? It's touching auth/, I recommend prd-trd. Shall I reconsider?" ← the user has already decided; log `user_overrode: true` and move on
