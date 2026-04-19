---
name: complexity-classifier
description: Router 가 `plan` 을 반환했거나 brainstorming 이 인계했을 때 반드시 사용 — 티어가 명백해 보일 때도 포함. 요청을 A/B/C/D 로 분류하고 유저 승인(Gate 1)을 받는다. 별도 승인 스킬 없이 추천·확정이 여기서 끝난다. flow.yaml 에 따라 prd-writer / trd-writer / task-writer 로 라우팅한다.
---

# Complexity Classifier

## 목적

요청이 어떤 아티팩트 체인을 타는지 결정한다:

| Tier | 경로 | 언제 |
|------|-------|------|
| **A** | PRD → TRD → Tasks | 신규 기능 (복잡) **또는** 보안·아키텍처 신호 경로 매칭 |
| **B** | PRD → Tasks | 신규 기능 (단순, < 5파일, 신호 없음) |
| **C** | TRD → Tasks | 리팩토링 / 기술 개선 |
| **D** | Tasks only | 버그 / 사소, 4항목 자기검증 통과 |

이 스킬은 **Gate 1** — 아티팩트 생성 착수 전의 유저 승인 — 도 흡수한다. 별도 승인 스킬이 없고, 티어 추천과 확정이 한 번의 대화에서 끝난다.

## 왜 이 스킬이 필요한가

티어 선택이 dispatcher 나 각 writer agent 안에 있으면 모든 writer 가 자기 자격을 다시 판단해야 한다 — 로직 중복, 임계치 불일치. 여기서 중앙화하면 downstream writer 는 "내가 호출됐으면 내가 맞는 writer" 라고 신뢰할 수 있다. 유저 승인 흡수는 대화 모양을 납작하게 유지한다 — 추천 한 번, 응답 한 번, 확정.

## 입력

이 스킬은 메인 스레드에서 실행된다. 라이브 대화 컨텍스트 접근 가능. Payload 는 router (`plan` 경로) 또는 brainstorming 에서 온다:

- `session_id`: `"YYYY-MM-DD-{slug}"`
- `request`: 유저의 원 요청, verbatim
- `resume`: router 가 기존 세션과 매칭했을 때 `true` (Step 0 참조)

Brainstorming 이 돌았으면 payload 에 추가:

- `intent`: `"add"|"fix"|"refactor"|"migrate"|"remove"|"other"`
- `target`: string
- `scope_hint`: `"single-file"|"subsystem"|"multi-system"`
- `constraints`: string[]
- `acceptance`: string | null

이 필드들은 **optional** — router 가 `plan` 을 바로 인계할 수 있고, 그 경우 classifier 가 요청의 동사에서 intent 를 추론하고 target/scope 는 생략한다.

## 출력

이 스킬은 **세 가지 터미널 payload 중 하나**로 끝난다. 스킬의 마지막 메시지는 `outcome` 으로 태깅된 JSON 하나.

**정상 분류** — downstream dispatcher 가 기대하는 인계:

```json
{
  "outcome": "classified",
  "session_id": "2026-04-19-...",
  "request": "...",
  "classification": "A|B|C|D",
  "brainstorming_output": { "intent": "...", "target": "...", "scope_hint": "...", "constraints": [...], "acceptance": "..." },
  "estimated_files": 4,
  "signals_matched": ["path:auth/", "keyword:login"],
  "user_overrode": false
}
```

`outcome: "classified"` 일 때의 라우팅 (flow.yaml 기준):

- `A` 또는 `B` → `prd-writer` (agent)
- `C` → `trd-writer` (agent)
- `D` → `task-writer` (agent)

**피벗** — 유저가 중간에 현재 요청을 떠나 다른 요청으로 전환. Dispatcher 는 다음 턴에서 router 가 재발화하도록 두고, 현재 세션은 그대로 보존:

```json
{ "outcome": "pivot", "session_id": "2026-04-19-...", "reason": "user asked about dashboard UI mid-classification" }
```

**Casual 재분류** — 알고 보니 유저가 작업 요청이 아니라 질문을 한 상황. Dispatcher 는 드롭하고 다음 턴을 router 가 처리하게 한다:

```json
{ "outcome": "exit-casual", "session_id": "2026-04-19-...", "reason": "user was asking about tier definitions, not requesting work" }
```

`signals_matched` 는 네임스페이스 엔트리 — `path:<glob>` 는 파일 경로 매칭, `keyword:<token>` 는 의미론적 키워드 매칭. Downstream 은 타입으로 필터 가능.

세션 파일은 `classified` outcome 에서만 갱신 — Step 7 참조. Pivot / exit-casual 은 ROADMAP/STATE 를 건드리지 않는다.

## 절차

### Step 0 — 재개 숏서킷

`resume: true` 이면 `.planning/{session_id}/ROADMAP.md` 를 읽는다. `Complexity: X` 줄 (X ∈ A/B/C/D) 이 있고 **동시에** `classifier` phase 가 `[x]` 면 **재분류하지 않는다**. flow.yaml 의 다음 미완료 phase 로 향하는 resume payload 를 emit 하고 종료. 근거: 지난 세션에서 이미 결정한 티어를 다시 묻는 건 턴을 낭비하고 신뢰를 깎는다.

`resume: true` 인데 분류 기록이 없으면 (예: Gate 1 중간에 끊긴 세션) Step 1 부터 정상 진행.

### Step 1 — 신호 탐지

두 종류의 신호가 있다:

**(a) 경로 신호 — 리터럴, 언어 무관.** `request`, `target`, `constraints` 에서 다음 파일 경로 패턴을 스캔:

- `auth/`, `security/` — 인증·인가
- `schema.*`, `*/schema/` — DB 또는 API 스키마
- `migrations/` — DB 마이그레이션
- `package.json`, `*/package.json` — 의존성·버전 변경
- `config.ts`, `*.config.*` — 전역 설정

경로는 파일시스템 리터럴 — 어떤 언어든 동일하게 매칭한다. 히트는 `signals_matched: ["path:auth/", ...]` 로 기록.

**(b) 키워드 신호 — 의미론적, 다국어.** 요청이 다음 개념 중 하나를 의미론적으로 가리키는지 판단: 인증(authentication), 로그인, 비밀번호, 세션, DB, 스키마, 마이그레이션, 설정(config), 의존성. 리터럴 문자열이 아니라 개념 — "로그인", "認証", "authentification" 모두 auth/login 개념으로 센다. 고정 키워드 테이블이 아니라 판단으로. 히트는 `signals_matched: ["keyword:login", "keyword:dependency", ...]` 로 기록.

**(c) `deliberately-wide-scope` 제약** (brainstorming 이 멀티서브시스템을 발견했는데 유저가 그대로 가자고 한 플래그): **암묵적 Tier-A 신호**. `signals_matched: ["constraint:deliberately-wide-scope"]` 로 기록.

`signals_matched` 가 비어 있지 않으면 Step 3 에서 Tier-A 후보.

### Step 2 — 파일 수 추정

정수 하나 N — 수정 + 신규 파일의 베스트-게스 합계.

Calibration:

- 오타 / 포맷 / 주석만 → 1
- 단일 서브시스템 버그 수정 → 1–3
- 엔드포인트 하나 또는 페이지 하나 신규 → 2–4
- 여러 레이어 걸친 기능 → 5–12
- 크로스-커팅 마이그레이션 / 프레임워크 교체 → 10–30+

과하게 생각하지 않는다. 대략의 정수 하나면 충분 — Step 6 에서 유저가 번복 가능. 추정조차 불가능할 정도로 요청이 모호하고 (brainstorming 도 안 돌아서 `target` 이 없음) N=3 중립값으로 두고 Gate 1 메시지에 low-confidence 표시.

### Step 3 — Tier 판정

순서대로 적용:

1. `signals_matched` 에 어떤 엔트리든 있으면 → **Tier-A 후보** (파일 수 무관).
2. 그 외, intent 별:
   - `add` / `create` + N ≥ 5 → **A**
   - `add` / `create` + N < 5 → **B**
   - `refactor` / `migrate` / `remove` → **C**
   - `fix` + N ≤ 2 → **D 후보** (Step 4 통과 필요)
   - `other` + `constraints` 에 `intent-freeform` → freeform 동사 파싱: refactor-ish → C, fix-ish → D 후보, create/add-ish → N ≥ 5 면 A 아니면 B. 해석 불가 → B.
   - `other` 또는 intent 없음 (freeform 단서도 없음) → **B** (보수적 — 경량 PRD 는 잘못된 티어보다 싸다).

### Step 4 — Tier-D 자기검증

Step 3 에서 D 후보가 나왔을 때만 실행. 네 개 모두 체크:

- [ ] 명백한 버그 수정 / 오타 / 포맷 / 주석 수준인가?
- [ ] 예상 파일 ≤ 2 인가?
- [ ] 보안·아키텍처 신호 매칭 없는가?
- [ ] 요청에 "설계 필요" 단서 (새 용어 / 의도 모호 / 새 개념 언급) 가 없는가?

**하나라도 실패 → Tier-B 로 승격** (경량 PRD 는 싼 보험). 전부 통과 → D 유지. 근거: "단순해 보이는" 작업이야말로 검증되지 않은 가정이 가장 많이 쌓이는 곳이다 — 이 게이트는 모델이 설계를 우회하도록 합리화하는 걸 막기 위한 것.

### Step 5 — Gate 1 — 추천 제시

유저 언어로, **독립된 턴 한 개 메시지** 로 전달:

> "Recommend **Tier-{X}** ({route}). 예상 {N}파일. {신호 요약 또는 '보안·아키텍처 신호 없음'}. 진행할까요?"

예시:

- `"Tier-B (PRD → Tasks) 추천. 예상 3파일, 보안 신호 없음. 진행할까요?"`
- `"Tier-A (PRD → TRD → Tasks) 추천. 예상 4파일, auth/ 를 건드림 (보안 민감). 진행할까요?"`
- `"Tier-D (Tasks only) 추천. 오타 수정, 1파일, 신호 없음. 설계 건너뛰고 바로 태스크로 갈까요?"`

이 메시지는 **단독** — 출력 JSON 을 같이 붙이지 않는다. MC 는 암묵적으로 제시: 수락 / 티어 변경 / 파일 수 조정. 이보다 더 묶지 않는다 — 신호·파일 수·티어가 결정 표면의 전부. 그리고 유저의 다음 턴을 기다린다.

### Step 6 — 응답 처리 (다음 유저 턴)

**다음** 유저 턴에 응답을 네 가지 액션 중 하나로 분류:

- **수락** ("네", "진행", 무응답/정정 없음) → Step 7 로, 현재 티어 유지. `user_overrode: false`.
- **티어 번복** ("A 로 해줘" / "그냥 D로") → Step 7 로, 유저 티어. `user_overrode: true`. 반박하지 않는다 — 최종 권한은 유저.
- **파일 수 번복** ("10파일쯤일 듯") → 새 N 으로 Step 3 재실행, Step 5 로 한 번만 돌아가서 새 추천 제시. 이 루프만 허용 — 두 번째 파일 수 변경은 재계산 후 재질의 없이 두 번째 값을 바로 사용.
- **피벗 또는 casual** — 아래 Pivot handling 참조.

`intent` / `target` / `scope_hint` 에 대한 명확화 질문은 **여기서 하지 않는다** — brainstorming 의 일이었다. 이 필드들이 빠져 있고 중요해 보이면 보수적 티어 (add 쪽이면 B, refactor 쪽이면 C) 로 넘기고 writer 단계에서 보강한다.

**Pivot handling.** 유저가 관련 없는 주제를 꺼내거나 현재 요청을 완전히 놓으면, 터미널 payload 로 `{"outcome": "pivot", ...}` 을 emit 하고 "새 요청으로 보입니다; 라우팅으로 돌아갑니다." 한 문장으로 종료. ROADMAP/STATE **갱신 금지**. 대신 유저 응답이 "티어에 대한 질문이었지 작업 요청이 아님" 을 드러내면, `{"outcome": "exit-casual", ...}` 을 emit 하고 한 줄 인정으로 종료.

### Step 7 — 확정 + emit (`outcome: "classified"` 경로 전용)

수락 (번복 포함) 시:

1. **`ROADMAP.md` 갱신**:
   - 상단 근처에 `Complexity: {X} ({route})` 줄 추가/갱신.
   - `- [ ] classifier` → `- [x] classifier       → {X}`.
   - `- [ ] gate-1-approval` → `- [x] gate-1-approval  → approved` (`user_overrode` 면 `→ overridden`).
2. **`STATE.md` 갱신**:
   - `Current Position: {flow.yaml 기준 다음 phase}`
   - `Last activity: {ISO 타임스탬프} — classified as {X}{, 필요 시 user-overrode}`
3. **`classified` payload 를 이 스킬의 마지막 메시지로 emit**. Downstream `subagent-dispatcher` 가 읽어서 맞는 writer agent 로 dispatch.

## 이 스킬이 하지 않는 것

- intent / target / scope 에 대한 명확화 질문 — brainstorming 의 몫. 비어 있으면 보수적 기본값으로 넘긴다.
- LOC / 테스트 커버리지 추정 — 요청 시점에는 알 수 없는 값이라 분류 신호에서 제외.
- 런타임 중간 승격 (실제 diff 보고 티어 상향) — 이 스킬의 범위 밖.
- 다음 agent 직접 dispatch — `subagent-dispatcher` 의 일. Classifier 는 payload emit + 세션 파일 갱신만.
- 파일 수 추정을 위한 코드베이스 탐색 — 추정은 요청 텍스트만으로. 코드 안 읽으면 정말 모를 요청은 N=3 기본값 + low confidence 표시.

## 대화 모양

**좋은 예 — 단순 B:**

> brainstorming 출력: `{intent: refactor, target: 세션 처리, scope_hint: subsystem}`
> Classifier: "**Tier-C** (TRD → Tasks) 추천. 예상 3파일, 보안 신호 없음. 진행할까요?"
> 유저: "네"
> Classifier: [ROADMAP 확정, payload emit]

**좋은 예 — 신호 승격:**

> 요청: "로그인에 2FA 추가"
> 신호 매칭: `auth/` → A 후보
> Classifier: "**Tier-A** (PRD → TRD → Tasks) 추천. 예상 4파일, `auth/` 를 건드림 (보안 민감). 진행할까요?"
> 유저: "좋아"
> Classifier: [확정]

**좋은 예 — D 자기검증 실패 후 B 로 강등:**

> 요청: "로그인의 세션 만료 버그 수정"
> intent: fix, N=2 — D 후보 → 신호 체크가 `auth/` 히트 → B 승격
> Classifier: "처음엔 Tier-D 수정으로 보였는데 `auth/` 를 건드립니다 — 대신 **Tier-B** (PRD → Tasks) 추천. 2파일. 진행할까요, A 로 승격할까요?"

**좋은 예 — 유저 티어 번복:**

> Classifier: "Tier-B 추천…"
> 유저: "아니 그냥 D 로, 한 줄짜리야"
> Classifier: "알겠습니다 — Tier-D, 유저 번복. 설계 건너뛰고 task-writer 로 진행."
> [`user_overrode: true` 로 확정]

**나쁜 예 — 명확화:**

> Classifier: "어떤 종류의 변경인가요 — 버그 수정인가요 기능인가요?" ← brainstorming 의 일

**나쁜 예 — 조용한 확정:**

> Classifier: [유저에게 묻지 않고 ROADMAP 에 쓰기] ← Gate 1 은 반드시 명시적

**나쁜 예 — 반박:**

> 유저: "그냥 D 로"
> Classifier: "확실한가요? auth/ 를 건드려서 A 를 권장하는데, 재고해 주시겠어요?" ← 유저가 이미 결정함; `user_overrode: true` 기록하고 진행

## 엣지 케이스

- **Router → plan 직송** (brainstorming 우회): `request` 의 첫 동사에서 `intent` 추론. 명확하지 않으면 `add` 로 기본. 유저에게 묻지 않는다 — 플로우를 간결하게 유지.
- **기존 분류 있는 재개** (Step 0): 다음 `[ ]` phase 로 향하는 resume payload emit. Gate 1 재질의 금지.
- **신호 충돌** (예: `migrations/` + "한 줄 오타"): A 쪽으로 편향. 사소한 마이그레이션을 과대 티어링하는 비용은 5분짜리 PRD, 과소 티어링하는 비용은 깨진 스키마.
- **유저가 파일 수만 주고 티어는 미정** ("8파일쯤?"): 조용히 티어 재계산, 새 추천을 한 번 더 제시.
- **유저가 없는 티어 지명** ("Tier-E 로"): 네 옵션으로 한 번 재질의. 여전히 불명확하면 추천 티어 사용.
- **`intent: "other"` + `intent-freeform` 제약** (brainstorming 에서): freeform 동사 파싱 — refactor-ish → C, fix-ish → D 후보, create-ish → A/B. 해석 불가면 B 기본.
- **알고 보니 casual** (유저가 작업 요청이 아니라 티어에 대해 질문): classifier 가 호출되지 말았어야 함. 한 문장으로 종료, router 가 다음 턴에 재발화.

## 경계

- `ROADMAP.md` (Complexity 줄 + 체크박스 두 개) 와 `STATE.md` (Current Position + Last activity) 에만 쓴다. 다른 파일 금지.
- 인계는 `flow.yaml` 라우팅만 — writer agent 직접 호출 금지.
- 스킬 내부 (티어명·신호 리스트·체크리스트·필드명) 는 영어. 유저 추천·확인은 유저 언어 미러링.
- Step 6 의 파일 수 재계산 외에 재시도 루프 없음. 유저와의 한 턴 주고받기가 예산의 전부.
