# Brainstorming — 엣지 케이스

`SKILL.md` 에서 참조하는 엣지 케이스 처리.

- **대화 중 유저 피벗** (인증 리팩토링 명확화하다가 갑자기 대시보드 UI): `{"outcome": "pivot", ...}` 터미널 emit + "새 요청으로 보입니다; 라우팅으로 돌아갑니다." 한 문장 종료. 다음 턴 router 가 새 세션 할당.
- **Phase A 답변에 새 모호성** (예: "인증도 건드리고 결제 쪽도 조금"): `scope_hint: multi-system` 으로 흡수. 모호성 자체가 정보다.
- **Phase A 답변이 무관** (범위 MC 에 코드 스니펫 등): 질문을 한 번 인용하며 재질문. 두 번째도 빗나가면 보수적 기본값 `scope_hint: multi-system` 으로 두고 진행.
- **알고 보니 casual** (한 라운드 돌고 보니 작업 요청이 아니라 질문): `{"outcome": "exit-casual", ...}` emit + 한 문장 인지 후 종료. `Last activity: brainstorming exit (reclassified-casual)` 로 기록.
- **유저 자발적 분해** (예: "응, 리드부터 하자, 딜은 다음에"): 수락하고 선택된 서브 프로젝트를 `request` 로 캡처, 후속을 `constraints` 에 `"followup-sessions: deals, reporting"` 로 기록.
- **Router → plan 직송** (Phase A 스킵): `request` 의 첫 동사에서 `intent` 추론. 명확하지 않으면 `add` 기본. 유저에게 묻지 않는다 — 플로우 간결성.
- **기존 분류 있는 재개** (Step 0): 다음 `[ ]` phase 로 향하는 경로 payload emit. Gate 1 재질의 금지.
- **신호 충돌** (예: `migrations/` + "한 줄 오타"): prd-trd 쪽 편향. 사소한 마이그레이션을 과대 스코핑하는 비용은 5분짜리 PRD, 과소 스코핑하는 비용은 깨진 스키마.
- **유저가 파일 수만 주고 경로는 미정** ("8파일쯤?"): 조용히 경로 재계산, 새 추천 한 번 더 제시.
- **유저가 없는 경로 지명** ("prd-tasks 로"): 네 옵션으로 한 번 재질의. 여전히 불명확하면 추천 경로 사용.
- **`intent: "other"` + `intent-freeform`**: freeform 동사 파싱 — refactor-ish → trd-only, fix-ish → tasks-only 후보, create-ish → prd-trd/prd-only. 해석 불가면 prd-only 기본.
