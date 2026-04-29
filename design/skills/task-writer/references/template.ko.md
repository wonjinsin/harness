# TASKS.md 템플릿 + Self-Review

````markdown
# TASKS — {PRD/TRD 또는 request 에서 뽑은 한 줄 제목}

Session: {session_id}
Created: {ISO date}
PRD: {PRD.md 상대 경로, 또는 "(none)"}
TRD: {TRD.md 상대 경로, 또는 "(none)"}

## Goal

{간결하게 (보통 1-2 문장). PRD 있으면 Goal 을 executor 관점으로 재진술
 (구현자가 무엇을 달성해야 하는가 — 유저가 무엇을 원하는가가 아니라).
 PRD 없으면 TRD Context 나 `request` 에서 goal 추출.}

## Architecture

{간결하게 (보통 2-3 문장). TRD 있으면 Approach 를 물리적으로 무엇이 바뀌는지로 축약:
 어떤 모듈이, 어떻게 연결되고, 무엇이 새롭고 무엇이 수정되는가.
 TRD 없으면 Step 2 탐색에서 뽑은 최소 기술 그림.}

## Conventions

- Task IDs are stable (`task-1`, `task-2`, ...). Evaluator and executor reference by ID.
- A task is complete when every `Acceptance:` checkbox is satisfied with evidence.
- **Bold terms** are quoted verbatim from PRD/TRD. Do not rename them in code, tests, or commit messages.

---

### task-1 — {imperative verb + object, PRD/TRD 어휘 그대로}

**Depends:** (none)
**Files:**
- Create: `exact/path/to/new.ext`
- Modify: `exact/path/to/existing.ext:start-end`
- Test: `exact/path/to/test.ext`

**Acceptance:**
- [ ] {**bold** PRD/TRD 용어가 들어간 검증 가능한 criterion, 출처 인용으로 끝 — 예: "(PRD §Acceptance criteria)"}
- [ ] {Criterion 2}

**Notes:** {문장 1-2개, 비자명할 때만. 그 외엔 필드 자체를 생략.}

---

### task-2 — ...

**Depends:** task-1
**Files:** ...
**Acceptance:** ...

---

## Self-Review

Performed by task-writer before emitting. Evaluator re-checks these claims.

- [ ] Every PRD Acceptance criterion maps to at least one task's Acceptance bullet (or is deferred to Non-goals).
- [ ] Every TRD Risks entry is referenced in the Notes of the task that creates the risk (or explicitly accepted as out-of-scope for this session).
- [ ] No placeholder strings: "TBD", "similar to task N", "handle edge cases", "add error handling", "write tests for the above".
- [ ] PRD/TRD vocabulary consistency: terms used in one task appear in the same form across all other tasks (no `TOTP` → `2FA` drift).
- [ ] DAG is acyclic; no task depends transitively on itself.
- [ ] No orphan task: every task is reachable from the set of root tasks (`Depends: (none)`), and every task either has a dependent or is a natural leaf.
````

파일 하단의 Self-Review 를 쓰기 전에 각 체크를 실제로 수행하고, 정직하게 certify 할 수 있는 박스만 (`[x]`) 체크. 박스를 남겨두는 건 괜찮다 — 알려진 gap 이니 evaluator 가 더 자세히 보라는 신호. 거짓 체크는 task 누락보다 더 나쁘다: evaluator 의 주의를 진짜 문제에서 딴 데로 돌리기 때문.
