# Output 스키마

모든 task 종료 시 단일 JSON 객체 emit. task 레벨 결과는 TASKS.md `[Result]` 블록에 살고 — evaluator 가 다시 읽는다. JSON 은 top-level outcome 과 해석된 `next` 만 전달.

**done** — 모두 DONE:

```json
{ "outcome": "done", "session_id": "2026-04-19-...", "next": "evaluator" }
```

**blocked** — task 명세(구현 아님) 가 틀린 경우. TASKS.md 레벨 검증 실패(cycle, `Depends:` 오타, 빈 Acceptance, 빈/없는 TASKS.md) **포함**. 재 dispatch 로 해결 불가 — 상류에서 task 본문을 고쳐야 한다.

```json
{ "outcome": "blocked", "session_id": "2026-04-19-...", "next": "evaluator" }
```

`harness-flow.yaml` 은 `executor → evaluator` 로 무조건 진행한다 — evaluator 스킬이 `[Result: blocked]` 블록을 감지해 escalate 한다.

**failed** — 하나 이상 task 가 3회 재시도 cap 소진:

```json
{ "outcome": "failed", "session_id": "2026-04-19-...", "next": "evaluator" }
```

**error** — 인프라·툴 레이어 실패 (Task 툴 오류, 파일시스템 거부, TDD reference 누락, TASKS.md 없음):

```json
{ "outcome": "error", "session_id": "2026-04-19-...", "reason": "TDD reference file missing at <path>", "next": "evaluator" }
```

## Error cascade

`error` 인 경우에도 `next: "evaluator"` 가 emit 된다 — `harness-flow.yaml` 의 `evaluator` 엣지에 `when:` 필터가 없어 executor 의 어떤 outcome 에서도 발화하기 때문. 이후 evaluator 가 `[Result]` 블록 누락을 자기 `error` 로 surface 하는 것이 의도된 cascade. 메인 스레드는 `error` 시 조기 halt 결정을 위해 override 할 수 있다 — emit 된 `next` 는 directive 가 아니라 hint.

JSON 외 prose 절대 금지. 부분 진행 됐으면 TASKS.md `[Result]` 블록에 현실 그대로 남긴다 — 메인 스레드가 executor 를 재 dispatch 할 수 있고, Step 1 resume 규칙에 따라 재개된다.
