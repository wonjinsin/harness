# harness-flow

Claude Code 플러그인. 유저 요청을 **router → brainstorming → PRD/TRD/TASKS → execute → evaluate → doc-update** 순으로 흘리는 Skill × Agent 하이브리드 하네스. 모든 전이는 `docs/harness/harness-flow.yaml` (DAG) 한 파일이 단일 소스 오브 트루스이고, `using-harness` 메타 스킬이 세션 시작 시 주입되어 LLM 이 직접 인터프리터로 동작한다.

> 현재 버전: **v0.2.2** (2026-04-26 — `brainstorming` + `complexity-classifier` 통합 반영)

---

## 핵심 컨셉

- **DAG 가 단일 소스**. 런타임 엔진 없음. LLM 이 매 스킬 종료 후 `harness-flow.yaml` 을 재독해 다음 노드를 직접 dispatch.
- **Skill 8개 + Agent 5개**. 경량 단계 (router, brainstorming, subagent-dispatcher) 는 메인 컨텍스트 Skill, 무거운 산출물 단계 (PRD/TRD/TASKS writer, evaluator, doc-updater) 는 격리된 Agent 가 동명의 Skill 을 호출.
- **세션 = 폴더**. 모든 산출물은 유저 프로젝트의 `.planning/{YYYY-MM-DD-slug}/` 하위 (`ROADMAP.md`, `STATE.md`, `PRD.md`, `TRD.md`, `TASKS.md`, `findings.md`).
- **두 게이트만 명시적**. Gate 1 (인테이크 → 아티팩트, brainstorming 내부 흡수) + Gate 2 (평가 → 문서 업데이트, doc-updater 첫 단계).

자세한 설계 결정은 `design/prd/flow-prd-v0.2.md` 참조.

---

## 설치

### A) Git 마켓플레이스 (권장)

이 repo 가 자기 자신을 단일 플러그인 마켓플레이스로 노출한다 (`.claude-plugin/marketplace.json`).

```
/plugin marketplace add wonjinsin/harness
/plugin install harness-flow@harness
```

이후 새 세션에서 SessionStart 훅이 자동으로 돌아 `using-harness` 스킬이 컨텍스트에 주입된다.

### B) 로컬 마켓플레이스 (개발·자기 머신)

repo 를 클론한 디렉토리를 그대로 마켓플레이스로 사용:

```
/plugin marketplace add /path/to/cloned/harness
/plugin install harness-flow@harness
```

### C) 복붙 모드 — 플러그인 안 쓰고 `.claude/` 에 직접 배치

플러그인 시스템을 거치지 않고 repo 를 통째로 `.claude/` 아래 두고 싶을 때. 이 경우 Claude Code 가 `$CLAUDE_PLUGIN_ROOT` 를 주입하지 않지만, `session-start.sh` 가 자기 위치에서 루트를 자동 유도하므로 **별도 환경 변수 설정 불필요**.

**(C-1) 글로벌 — `~/.claude/harness-flow/` 에 통째로 배치 (권장)**

```bash
git clone https://github.com/wonjinsin/harness.git ~/.claude/harness-flow
```

**(C-2) 프로젝트 로컬 — `<project>/.claude/harness-flow/`**

```bash
git clone https://github.com/wonjinsin/harness.git <project>/.claude/harness-flow
```

**필수 — settings.json 에 훅 등록**:

플러그인 모드면 `hooks/hooks.json` 을 Claude Code 가 자동으로 읽지만, 복붙 모드에선 무시된다. `~/.claude/settings.json` (글로벌) 또는 `<project>/.claude/settings.json` (프로젝트) 에 직접 등록:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$HOME/.claude/harness-flow/hooks/session-start.sh\""
          }
        ]
      }
    ]
  }
}
```

(프로젝트 로컬 모드면 경로를 `$HOME` 대신 프로젝트 절대 경로로.)

**(C-3) `.claude/` 에 납작하게 머지**

`skills/`, `agents/`, `hooks/`, `docs/` 를 분해해서 기존 `~/.claude/skills/`, `~/.claude/agents/` 등에 그대로 합치는 케이스. 이름 충돌만 없으면 동작하지만, 업그레이드·제거가 까다로워져서 추천하지 않는다. 굳이 한다면 위 settings.json 등록은 동일하게 필요.

### D) 동작 확인

```
/plugin
```

목록에 `harness-flow` 가 enabled 로 보이면 플러그인 모드 정상. 복붙 모드면 `/plugin` 에는 안 뜨지만, 새 세션 시작 시 시스템 메시지 상단에 `"You have harness."` 와 `using-harness` 본문이 보이면 부트스트랩 성공.

---

## 어떻게 트리거되나

새 세션에서 첫 유저 메시지가 도착하면 `using-harness` 가 다음을 판단:

| 입력 예시 | 분류 | 동작 |
|---|---|---|
| `"안녕"`, `"이거 뭐 할 수 있어?"` | casual | 일반 응답, 하네스 미개입 |
| `"로그인에 2FA 추가해줘"` | plan | router → brainstorming → 경로 추천 → ... |
| `"인증 코드 좀 더 깔끔하게"` | clarify | router → brainstorming Phase A (Q&A) → Phase B (분류) |
| `"어제 하던 2FA 작업 이어서"` | resume | router → 매칭된 세션 로드 → 다음 미완료 phase 부터 |

세션이 만들어지면 ROADMAP 체크박스를 따라 진행되고, 중단 후 재시작해도 마지막 `[x]` 다음부터 이어진다.

---

## 디렉토리 구조

```
harness-flow/
├── .claude-plugin/
│   ├── plugin.json          ← 플러그인 매니페스트
│   └── marketplace.json     ← 단일 플러그인 마켓플레이스 정의
├── hooks/
│   ├── hooks.json           ← SessionStart 훅 등록
│   └── session-start.sh     ← using-harness 컨텍스트 주입
├── skills/                  ← 8개 스킬 (instruction 본체)
│   ├── using-harness/       ← 메타 인터프리터
│   ├── router/              ← 입력 분류
│   ├── brainstorming/       ← 인테이크 (Phase A 명확화 + Phase B 분류·Gate 1)
│   ├── prd-writer/          ← agent 경유
│   ├── trd-writer/          ← agent 경유
│   ├── task-writer/         ← agent 경유
│   ├── parallel-task-executor/  ← subagent 디스패처
│   ├── evaluator/           ← agent 경유
│   └── doc-updater/         ← agent 경유
├── agents/                  ← 5개 agent 정의 (얇은 래퍼)
│   ├── prd-writer.md
│   ├── trd-writer.md
│   ├── task-writer.md
│   ├── evaluator.md
│   └── doc-updater.md
├── docs/
│   └── harness/
│       └── harness-flow.yaml    ← DAG (단일 소스 오브 트루스)
└── design/                  ← 설계 문서·한국어 미러
    ├── prd/flow-prd-v0.2.md
    ├── skills/*.ko.md
    ├── reference/           ← 6개 레퍼런스 하네스 분석
    └── comparison.md
```

설치 후 유저 프로젝트엔 다음만 생긴다:

```
<your-project>/
└── .planning/
    └── {YYYY-MM-DD-slug}/
        ├── ROADMAP.md
        ├── STATE.md
        ├── PRD.md           (필요 시)
        ├── TRD.md           (필요 시)
        ├── TASKS.md
        └── findings.md      (doc-updater 감사 로그)
```

---

## 경로 규칙 (중요)

하네스 자체 자산 (스킬·DAG·hook) 은 모두 **루트 절대 경로**로 접근한다. 유저 프로젝트 CWD 와 무관하게 동작하기 위함.

- 플러그인 모드: 루트 = `$CLAUDE_PLUGIN_ROOT` (Claude Code 가 자동 주입)
- 복붙 모드: 루트 = `session-start.sh` 의 자기 위치에서 자동 유도 (`HARNESS_ROOT="$(dirname "$SCRIPT_DIR")"`)

두 모드 모두에서 `session-start.sh` 가 SessionStart 시점에 절대 경로를 컨텍스트에 주입하므로, `using-harness` 스킬 본문의 `${CLAUDE_PLUGIN_ROOT}` 표기는 **문법적 placeholder** 이고 실행 시점엔 항상 해석된 절대 경로로 치환된다.

- DAG: `<root>/docs/harness/harness-flow.yaml`
- 스킬 파일: 플러그인 모드면 이름 등록 — `Skill("router")` 우선, 폴백은 `<root>/skills/<command>/SKILL.md`

세션 산출물 (`.planning/{session_id}/`) 만 유저 프로젝트 상대 경로 — 이건 의도된 동작.

---

## 다음 작업 (v0.3 후보)

- 각 스킬의 실제 프롬프트 마감 (R1)
- Stop 훅의 mechanical check + roadmap enforcer 구현
- `/status`, `/flow` 슬래시 커맨드
- 프로젝트별 `harness-flow.yaml` 오버라이드

---

## 라이선스 / 작성자

- 작성: [@wonjinsin](https://github.com/wonjinsin)
- 설계 레퍼런스: superpowers, archon, get-shit-done, oh-my-claudecode, everything-claude-code, gstack (`design/reference/` 참조)
