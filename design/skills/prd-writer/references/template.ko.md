# PRD.md 템플릿

간결함 쪽으로 기울인다 — 독자가 2분 안에 읽혀야 한다. 섹션이 범위를 넘기고 싶어지면 보통 Open question 으로 분리해야 한다는 신호, PRD 를 부풀릴 게 아니다.

```markdown
# PRD — {요청으로부터 한 줄 제목}

Session: {session_id}
Created: {ISO 날짜}

## 1. Problem

{1–3 문장. 왜 이걸 하는가. 유저 관점, 구현 프레임 금지.}

## 2. Goal

{1–3 개 bullet, 각각 변경 후 검증 가능한 결과.}

- {결과 bullet 1}
- {결과 bullet 2}

## 3. Non-goals

{1–4 개 명시적 제외 — 범위에 넣을 수 있었지만 넣지 않는 것들.}

- {명시적 제외 1}
- {명시적 제외 2}

## 4. Users & scenarios

{짧은 한 문단 — 누가 어떤 순간에 영향받는가. 유저 타입이 실질적으로
 다를 때만 페르소나 추가.}

## 5. Acceptance criteria

{2–6 개 체크박스. 각 항목은 독립 검증 가능해야 한다.}

- [ ] {검증 가능한 조건 1}
- [ ] {검증 가능한 조건 2}
- [ ] ...

## 6. Constraints

{매칭된 모든 신호 나열 (`auth/` → 보안, `migrations/` → 하위호환 등) 에
 1줄 rationale. 매칭된 신호가 없을 때만 비움.}

## 7. Open questions

{스펙에 영향 주는 미해결 결정 전부. 없으면 비움.
 포맷: "- Q: … (impact: …)".}
```
