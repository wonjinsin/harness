# Output 스키마

모든 task 종료 시 단일 JSON 객체 emit. task 레벨 결과는 TASKS.md `[Result]` 블록에 살고 — evaluator 가 다시 읽는다. JSON 은 top-level outcome 만 전달.

**done** — 모두 DONE:

```json
{ "outcome": "done", "session_id": "2026-04-19-..." }
```

**blocked** — task 명세(구현 아님) 가 틀린 경우. TASKS.md 레벨 검증 실패(cycle, `Depends:` 오타, 빈 Acceptance, 빈/없는 TASKS.md) **포함**. 재 dispatch 로 해결 불가 — 상류에서 task 본문을 고쳐야 한다.

```json
{ "outcome": "blocked", "session_id": "2026-04-19-..." }
```

**failed** — 하나 이상 task 가 3회 재시도 cap 소진:

```json
{ "outcome": "failed", "session_id": "2026-04-19-..." }
```

**error** — 인프라·툴 레이어 실패 (Task 툴 오류, 파일시스템 거부, TDD reference 누락, TASKS.md 없음):

```json
{ "outcome": "error", "session_id": "2026-04-19-...", "reason": "TDD reference file missing at <path>" }
```

Output 은 메인 thread 가 SKILL.md 의 '필수 다음 스킬' 섹션에 따라 다음 스킬을 dispatch 하는 데 사용된다.

JSON 외 prose 절대 금지. 부분 진행 됐으면 TASKS.md `[Result]` 블록에 현실 그대로 남긴다 — 메인 스레드가 executor 를 재 dispatch 할 수 있고, Step 1 resume 규칙에 따라 재개된다.
