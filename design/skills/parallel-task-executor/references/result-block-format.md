# `[Result]` 블록 포맷

각 그룹 후 TASKS.md 의 각 task 아래 `[Result]` 블록 append 또는 replace. 이 파일은 executor 의 영속 상태 — 다음 executor 호출이 이 블록을 읽어 resume 규칙을 적용한다.

## 표준 포맷 (`done` 기준)

```markdown
[Result]
Status: done
Attempt: 1
Summary: POST /auth/totp/verify 핸들러 추가, Acceptance bullet 4개 모두 검증.
Evidence:
- rate-limit bullet → tests/auth/totp.test.ts::"three consecutive failures yield 429"
- intermediate-token 소비 → grep "jti.*consumed" src/auth/totp.ts:142
Updated: 2026-04-19T14:23:00Z
```

## Status delta

다른 상태는 같은 블록에 아래 차이만:

- **failed**: `Status: failed`, 재시도마다 `Attempt: N` 증가, `Evidence` 대신 `Reason:` 한 줄. `Summary:` 는 subagent 의 summary 또는 `"Task tool errored: <type>"`.
- **blocked**: `Status: blocked`, `Attempt` / `Summary` 제거, `Evidence` 대신 `Reason:` (한 줄 원인).
- **skipped** (Step 3 가 dispatch 없이 설정): `Status: skipped`, `Attempt` / `Summary` 제거, `Reason: depends on task-N which {blocked|failed}`.

`Updated:` (ISO-8601) 는 항상 포함. TASKS.md 의 다른 섹션(Goal, Architecture, task 본문, Self-Review) 은 **수정 금지** — task 별 `[Result]` 블록 append/replace 만.
