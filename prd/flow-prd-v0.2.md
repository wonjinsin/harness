# Flow PRD v0.2 — Claude Code Harness

> **Scope**: 플로우 설계만. 구체적 스킬/프롬프트/훅 구현은 v0.3 이후.

---

## 1. 컨셉

Claude Code 위에서 동작하는 **자체 하네스**. 유저 요청을 받아 **요청 → 계획 → 실행 → 평가 → 문서화** 의 표준 흐름으로 흘리고, 중간에 유저 승인을 받거나 실패 시 루프백한다. 6개 reference 하네스 분석을 바탕으로, GSD(파일 기반 상태) + OMC(훅 기반 강제) + superpowers(스킬 체인)의 장점을 결합한다.

---

## 2. 확정된 설계 결정

| # | 결정 사항 | 선택 | 근거 |
|---|---|---|---|
| D1 | 실행 환경 | Claude Code 플러그인 전용 | 자체 LLM 호출 불필요, CC 에이전트 루프 재사용 |
| D2 | Router 방식 | 하이브리드 (키워드 결정론 → LLM 폴백) | OMC `keyword-detector` 90% 커버 + archon 스타일 모호성 해소 |
| D3 | 복잡도 분류 주체 | LLM 추천 + 유저 확정 | 자동화 + 통제권 양립 |
| D4 | 복잡도 기준 | 수정 파일 수, 구현 복잡도 | 유저 명시 |
| D5 | Artifact 포맷 | Markdown (필요 시 YAML frontmatter) | 유저 수정 가능 + LLM 가독성 |
| D6 | **플로우 정의** | **정적 `harness-flow.yaml` (스킬 연결 접착제)** | 스킬 연결 이탈 방지 |
| D7 | 진행 상태 | per-session `ROADMAP.md` 체크박스 | GSD 패턴, 세션 재개 자동 |
| D8 | 승인 게이트 | Phase 3→4 (계획 착수 전) + Phase 6→7 (문서 업데이트 전) | 비싼 작업 착수 전만 |
| D9 | 실패 재실행 | Stop 훅 + retry_count (≥3 에스컬레이션) | OMC ralph 패턴 |
| D10 | 롤백 | 본 버전 제외 | 유저 명시 |

---

## 3. 플로우

```
유저 요청
   ↓
[Phase 1] Router
   ├─ casual     → 일반 대화 (END)
   ├─ clarify    → Phase 2
   └─ plan       → Phase 3 (Phase 2 우회 가능)
   ↓
[Phase 2] Clarification
   ↓
[Phase 3] Complexity Classifier
   ├─ A: PRD → TRD → Tasks  (신규 기능, 복잡)
   ├─ B: PRD → Tasks        (신규 기능, 단순)
   ├─ C: TRD → Tasks        (리팩토링/기술)
   └─ D: Tasks only         (버그/trivial)
   ↓
[Gate 1] 유저 승인 — "B안으로 진행할까요?"
   ↓
[Phase 4] Artifact Creation — PRD.md / TRD.md / TASKS.md 생성
   ↓
[Phase 5] Execution — TASKS.md 를 subagent로 디스패치
   ↓
[Phase 6] Evaluation Loop — lint / test / rule 검증
   ├─ PASS → Gate 2
   └─ FAIL → Phase 5로 루프백 (retry_count++)
          └─ retry ≥ 3 → 에스컬레이션 (유저 호출)
   ↓
[Gate 2] 유저 승인 — "CHANGELOG 업데이트할까요?"
   ↓
[Phase 7] Doc Auto-update
   ↓
완료
```

---

## 4. 컴포넌트 (구현 시점 역할 정의만)

| 컴포넌트 | 종류 | 역할 |
|---|---|---|
| `router` | Skill | 입력을 `casual/clarify/plan` 중 하나로 분류. 결정론 먼저, 실패 시 LLM. |
| `clarifier` | Skill | 유저 요청 명확화. 종료 기준: 유저 확인 or 필수 필드 채워짐. |
| `complexity-classifier` | Skill | A/B/C/D 추천, 유저 확정 받음. |
| `prd-writer` / `trd-writer` / `task-writer` | Skill | 해당 산출물 `.md` 생성. |
| `subagent-dispatcher` | Skill | `TASKS.md` 읽어 Claude Code `Task` 툴로 병렬/직렬 디스패치. |
| `evaluator` | Skill | lint / test / rule check 실행, 결과 집계. |
| `doc-updater` | Skill | `CHANGELOG.md` 등 업데이트. |
| `stop-hook` | Hook (`.mjs`) | `ROADMAP.md` 검사 → 미완료 시 block + 다음 스킬 지시 주입. |
| `/status` | Slash command | `ROADMAP.md` 렌더링. |
| `/flow` | Slash command | `harness-flow.yaml` 렌더링 (다이어그램 or 목록). |

---

## 5. `harness-flow.yaml` — 플로우 정의 (정적)

**역할**: 모든 스킬이 startup 시 이 파일을 읽어 "내 다음은 누구?" 를 확인. 스킬 간 연결의 단일 소스.

**위치**: `~/.claude/harness-flow.yaml` (글로벌) 또는 `.claude/harness-flow.yaml` (프로젝트별 오버라이드).

```yaml
version: 1
name: default-flow

phases:
  - id: router
    skill: router
    role: "입력 분류"
    routes:
      casual: END
      clarify: clarifier
      plan: classifier

  - id: clarifier
    skill: clarifier
    role: "요청 명확화"
    next: classifier

  - id: classifier
    skill: complexity-classifier
    role: "A/B/C/D 중 선택 + 유저 승인 (Gate 1)"
    routes:
      A: prd-writer
      B: prd-writer
      C: trd-writer
      D: task-writer

  - id: prd-writer
    skill: prd-writer
    role: "PRD.md 생성"
    next:
      when complexity=A: trd-writer
      else: task-writer

  - id: trd-writer
    skill: trd-writer
    next: task-writer

  - id: task-writer
    skill: task-writer
    next: executor

  - id: executor
    skill: subagent-dispatcher
    next: evaluator

  - id: evaluator
    skill: evaluator
    routes:
      pass: doc-updater-gate
      fail: executor           # 루프백
    max_retries: 3
    on_max_retries: escalate   # 유저 호출

  - id: doc-updater-gate
    skill: user-approval       # Gate 2
    next: doc-updater

  - id: doc-updater
    skill: doc-updater
    next: END
```

**각 스킬 SKILL.md 상단엔** 이 한 줄만:
> `~/.claude/harness-flow.yaml` 을 읽고, 이 스킬의 `routes`/`next` 에 따라 다음 스킬을 호출하라.

---

## 6. per-session 진행상태 — `ROADMAP.md`

**위치**: `.planning/{session-id}/ROADMAP.md`

**역할**: 세션별 체크박스. Stop 훅과 `/status` 의 단일 조회 대상.

```markdown
# Session 2026-04-17-abc123
Request: "로그인 페이지에 2FA 추가"
Complexity: B (PRD → Tasks)

## Phases
- [x] router           → plan
- [ ] ~~clarifier~~    (우회됨)
- [x] classifier       → B
- [x] gate-1-approval  → approved
- [x] prd-writer       → PRD.md
- [ ] task-writer      → TASKS.md  ← 현재 여기
- [ ] executor
- [ ] evaluator        (retry_count: 0)
- [ ] gate-2-approval
- [ ] doc-updater

## Artifacts
- PRD.md: .planning/2026-04-17-abc123/PRD.md
- TASKS.md: (미생성)
```

**갱신 규칙**: 각 스킬이 자기 phase 완료 시 체크박스 `[ ]` → `[x]` 로 수정.

---

## 7. 핵심 동작

### 7.1 Stop 훅
세션 종료 시도 시 `ROADMAP.md` 를 읽어:
- 모든 phase `[x]` → 통과
- 미완료 `[ ]` 있음 → `{continue: false, decision: "block", reason: "다음 phase: <id> 를 실행하라. harness-flow.yaml 참고."}` 주입
- `retry_count ≥ 3` → 에스컬레이션 메시지 주입 후 통과
- OMC 가드 그대로 수용: context_limit / user_abort / auth_error 은 **무조건 통과**

### 7.2 `/status`
`ROADMAP.md` 를 그대로 보여주거나 프로그레스 바로 렌더링.

### 7.3 `/flow`
`harness-flow.yaml` 을 Mermaid/ASCII 다이어그램으로 렌더링.

### 7.4 승인 게이트
YAML의 `user-approval` 타입 phase 두 개(Gate 1, Gate 2). 해당 스킬은 단순히 유저에게 확인 메시지 출력하고 응답 대기. ROADMAP 에 응답 기록.

---

## 8. 파일 레이아웃

```
~/.claude/
├── harness-flow.yaml              ← 정적 플로우 정의
├── skills/                         ← 스킬들
│   ├── router/SKILL.md
│   ├── clarifier/SKILL.md
│   ├── complexity-classifier/SKILL.md
│   └── ...
├── commands/                       ← 슬래시 커맨드
│   ├── status.md
│   └── flow.md
├── hooks/
│   └── stop-roadmap-enforcer.mjs
└── settings.json

<project>/.planning/
└── {session-id}/
    ├── ROADMAP.md                 ← per-session 체크박스
    ├── PRD.md
    ├── TRD.md
    └── TASKS.md
```

---

## 9. Non-goals (본 버전 제외)

- 자동 git 롤백 / 커밋
- Runtime-driven YAML 디스패처 (B 방식) — A 방식으로 시작
- 복잡도 경로 간 전환 (B → A 승격 등)
- 외부 도구 통합 (Linear / Jira)
- 병렬 세션 동시 실행 (한 번에 하나의 session-id)
- 플로우 분기의 조건 표현 풍부화 — 지금은 `when complexity=X` 수준만 지원

---

## 10. 남은 결정 (v0.3 에서 다룰 것들)

- R1: 각 스킬의 실제 프롬프트 내용 (아직 구현 X)
- R2: complexity 분류 기준의 구체 수치 (파일 N개 이상? LOC?)
- R3: `evaluator` 의 check 구성 (lint/test 명령 프로젝트별 감지 방법)
- R4: `doc-updater` 대상 파일 리스트 (기본: `CHANGELOG.md`, 추가 대상?)
- R5: session-id 생성 규칙 (timestamp? uuid? Claude Code session_id 재사용?)
- R6: ROADMAP.md 포맷이 나중에 YAML frontmatter 필요해질지 (retry_count 등 메타 저장용)

---

## 11. 성공 기준 (이 플로우가 제대로 작동하는지)

- [ ] 유저가 임의 요청 → 첫 응답까지 Router 가 올바른 분류 (casual/clarify/plan)
- [ ] 복잡도 A 요청에서 PRD → TRD → Tasks 순서 이탈 없음 (YAML 덕분)
- [ ] 세션 중단 후 재시작 → ROADMAP 의 마지막 `[x]` 다음부터 재개
- [ ] Eval 실패 시 retry_count 증가, 3회 후 에스컬레이션
- [ ] `/status` 로 현재 phase 즉시 확인 가능
