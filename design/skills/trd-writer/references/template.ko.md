# TRD.md 템플릿

간결 지향 — 독자가 3분 안에 끝낼 수 있어야 한다. 섹션이 범위 이상으로 늘어나려 하면 대개 Open question 으로 떼어내야 한다는 신호지 padding 으로 메우는 게 아니다. 섹션 4–6 (Interfaces, Data model, Dependencies) 은 변경이 없을 때 `N/A — <한 줄 이유>` 로 적어도 됨; 무관한 내용으로 채우지 말 것.

```markdown
# TRD — {PRD 또는 request 에서 뽑은 한 줄 제목}

Session: {session_id}
Created: {ISO date}
PRD: {PRD.md 상대 경로, 또는 "(none)"}

## 1. Context

{문장 1–3개. PRD 가 있으면 TRD 관점으로 goal 을 요약하고 관련 PRD 섹션을
 **헤더 이름으로** 인용 (번호 금지 — 헤더 이름은 안정적이지만 번호는 위치
 기반이라 PRD 템플릿 순서가 바뀌면 조용히 stale 해진다). PRD 없으면
 유저 request 에서 뽑은 기술적 동기를 기술.}

## 2. Approach

{bullet 2–5개. 해결의 shape 을 묘사 — 핵심 설계 결정, 구현 단계 아님.
 각 bullet 은 "왜 이 shape 인가" 에 답해야 함.}

- {결정 1 + 한 줄 이유}
- {결정 2 + 한 줄 이유}

## 3. Affected surfaces

{생성/수정될 파일·모듈. 경계를 넘나들면 서브시스템별로 그룹핑. 항목당
 무엇이 바뀌는지 한 줄.}

- `path/to/file.ext` — {무엇이 바뀌는지}
- `path/to/other.ext` — {무엇이 바뀌는지}

## 4. Interfaces & contracts

{구체적 시그니처, request/response shape, 이벤트 이름, CLI 플래그 —
 이 변경 바깥 코드와의 계약이 되는 것들. 시그니처는 code block.
 진짜 추가/변경이 없으면 "N/A — <이유>".}

## 5. Data model

{스키마, 테이블, 영속화 구조, 메시지 포맷 — 지속적 shape 은 무엇이든.
 영속화/스키마 변경 없으면 "N/A — <이유>".}

## 6. Dependencies

{외부 라이브러리, 서비스, 피처 플래그, 이 변경이 의존하는 진행 중인
 다른 작업. self-contained 면 "N/A — <이유>".}

## 7. Risks

{구체적 실패 모드 + 설계가 어떻게 완화하거나 수용하는지.
 탐색 중 auth/security/migrations 관련 우려가 드러나면 항목이 필요하다 —
 하류 (task-writer, evaluator) 는 이 요구사항들을 코드만으로 복구할 수 없어서
 생략된 risk 는 조용히 실패한다.}

- {Risk 1}: {완화책 또는 명시적 수용}
- {Risk 2}: {완화책 또는 명시적 수용}

## 8. Open questions

{구현에 영향을 미치는 미결정 설계. 없으면 비워둠.
 형식: "- Q: … (impact: …)".}
```
