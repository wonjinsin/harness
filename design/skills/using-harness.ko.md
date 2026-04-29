---
name: using-harness
description: harness 스킬이 끝났을 때, 새 user 메시지가 flow 를 시작할 가능성이 있을 때, 혹은 세션 시작 시점에 사용 — `harness-flow.yaml` 을 읽고 다음 노드를 디스패치하는 방법을 설명.
---

# Using Harness

**하네스 DAG 파일**: `${CLAUDE_PLUGIN_ROOT}/docs/harness/harness-flow.yaml` (플러그인 루트, **유저 CWD 아님** — SessionStart 훅이 해석된 절대 경로를 주입하니 그대로 사용하고, 절대 상대 경로로 읽지 말 것). **너 = 인터프리터.** 런타임 엔진 없음: YAML 읽고 다음 노드 직접 dispatch. 세션 아티팩트는 `.planning/{session_id}/` 하위 (상대 경로 — 유저 프로젝트에 작성).

## Core loop

스킬 종료 시 (또는 유저 메시지 도착 시):

1. **`${CLAUDE_PLUGIN_ROOT}/docs/harness/harness-flow.yaml` 재독** (~60 줄, 저렴).
2. **현재 위치 파악** — 어느 노드가 방금 끝났나? 출력 JSON 은 뭐였나?
3. **후보 노드 찾기** — 방금 끝난 노드를 `depends_on` 에 가진 모든 노드.
4. **`when:` 치환·평가** — `$<id>.output.<field>` 를 최근 출력값으로 치환하고 boolean 평가 (`==`, `||`, `&&`).
5. **`trigger_rule` 적용** — 기본은 모든 `depends_on` 완료 필요, `one_success` 는 하나라도 매칭되면 즉시 발화.
6. **첫 매칭 노드 호출.** 플러그인 로드 시 스킬이 이름으로 등록돼 있으니 `Skill("<command>")` 우선. 등록 조회 실패 시 폴백으로 `${CLAUDE_PLUGIN_ROOT}/skills/<command>/SKILL.md` 를 `Read`.
7. **매칭 없음 → 플로우 종료.** 최종 outcome 유저에게 보고.

## Downstream self-lookup (the `next` field)

모든 하네스 스킬은 자기 outgoing edge 에 대해 Core loop 1–5 단계를 돌려 `next` 필드를 방출한다. 모든 스킬이 직접 lookup 을 수행하는 이유는 `references/design-rationale.ko.md` 참조. 각 노드가 페이로드에 어떤 필드를 관통시켜야 하는지는 `references/payload-threading.ko.md` 참조.

## 플로우 시작

세션의 첫 유저 메시지:

- **캐주얼 대화·일반 질문** (계획·빌드 의도 없음) → 일반 응답. 하네스 미개입.
- **feature / bug / 프로젝트 / "X 만들어줘" 요청** → `router` 노드 호출 (진입점 — `harness-flow.yaml` 에서 `depends_on` 없음).

플로우 시작 시점에 `session_id = "YYYY-MM-DD-{slug}"` 생성 (slug 은 요청 요약의 2-4 단어 kebab-case). 이후 모든 스킬 호출에 관통.

## Output 계약

모든 하네스 스킬은 단일 JSON 객체를 최종 메시지로 방출:

```json
{"outcome": "<value>", "session_id": "<id>", "next": "<node-id>" | null, ...}
```

에러 시: `outcome: "error"`, `reason: "<한 줄>"`, `next: null` 추가. 자기 dispatch 결정은 `outcome` 으로 재유도하고, 스킬의 `next` 는 cross-check 신호로 취급 — 어긋나면 로그.

## 규칙

- **스킬 출력에 `outcome` 필드 부재** → 플로우 종료 처리, 유저에게 보고.
- **무한 재귀 금지** — 같은 노드를 세션 내에서 두 번 invoke 했는데 진척 없으면 멈추고 유저에게 질문.
- `when:` 표현식 syntax, `context: fresh` 의미, tiebreak 규칙은 `harness-flow.yaml` 상단의 schema 헤더 참조.
