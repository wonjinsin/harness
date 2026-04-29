# Brainstorming — 대화 예시

`SKILL.md` 에서 참조하는 추가 대화 패턴. trd-only 인증 리팩토링 케이스는 스킬 본문에 인라인으로 유지; 이 파일에는 나머지가 있다.

## 좋은 예 — plan 경로 (Phase A 스킵), 신호 승격

> Router output: `{outcome: "plan", request: "로그인에 2FA 추가", session_id: "..."}`
> Brainstorming: [Phase A 스킵; B1 이 `auth/` + `keyword:login` 히트]
> Brainstorming: "**prd-trd** (PRD → TRD → Tasks) 추천. 예상 4파일, `auth/` 를 건드림 (보안 민감). 진행할까요?"
> User: "좋아"
> Brainstorming: [확정, `{"outcome": "prd-trd", ...}` emit]

## 좋은 예 — tasks-only 자기검증 실패 후 prd-only 로 강등

> 요청: "로그인의 세션 만료 버그 수정"
> intent: fix, N=2 — tasks-only 후보 → B1 이 `auth/` 히트 → prd-only 승격
> Brainstorming: "처음엔 tasks-only 수정으로 보였는데 `auth/` 를 건드립니다 — 대신 **prd-only** (PRD → Tasks) 추천. 2파일. 진행할까요, prd-trd 로 승격할까요?"

## 좋은 예 — 유저 경로 번복

> Brainstorming: "prd-only 추천…"
> User: "아니 그냥 tasks-only 로, 한 줄짜리야"
> Brainstorming: "알겠습니다 — tasks-only, 유저 번복. 설계 건너뛰고 task-writer 로 진행."
> [`user_overrode: true` 로 확정]

## 좋은 예 — 필드 파기 전에 다중 프로젝트를 잡아냄

> User: "리드 / 딜 / 리포팅 / 이메일 통합 / 모바일 앱이 있는 완전한 CRM 을 만들자"
> Brainstorming: "이건 여러 서브 프로젝트로 보입니다: 리드/딜 관리, 리포팅, 이메일 통합, 모바일 앱. 한 세션은 하나의 일관된 조각을 소유해야 합니다 — 어떤 것부터 시작하시겠어요?"

## 나쁜 예 — 질문 폭격

> Brainstorming: "다음을 알려주세요: (1) intent, (2) target, (3) scope, (4) constraints, (5) acceptance — 다섯 개 다 부탁합니다."

## 나쁜 예 — 접근법 제안

> Brainstorming: "세 가지 방법이 있습니다: A) 이름만 바꾸기 B) 함수 추출 C) 전면 재작성. 뭐가 좋을까요?"

## 나쁜 예 — 요청에 이미 있는 걸 되묻기

> User 요청: "fix the login timeout bug in src/auth/session.ts"
> Brainstorming: "어떤 종류의 변경인가요?"
> (intent / target / scope 가 요청에 다 있음 — 바로 acceptance 또는 경로 추천으로)

## 나쁜 예 — 조용한 확정 (Gate 1 은 반드시 명시적)

> Brainstorming: [유저에게 묻지 않고 ROADMAP 에 쓰기]

## 나쁜 예 — 유저 번복에 반박

> User: "그냥 tasks-only 로"
> Brainstorming: "확실한가요? auth/ 를 건드려서 prd-trd 를 권장하는데, 재고해 주시겠어요?" ← 유저가 이미 결정함; `user_overrode: true` 기록하고 진행
