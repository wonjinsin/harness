# Router Analysis: `everything-claude-code` (ECC) — Part 1

## TL;DR

ECC의 라우팅은 **코드가 아닌 Markdown 파일의 description frontmatter를 LLM이 읽고 스스로 고르는 방식**이다. Node.js 훅은 라우팅을 하지 않고, 세션 시작 시 컨텍스트 주입(`session-start.js`)과 도구 실행 전후 가드레일만 담당하며, 실제 스킬/에이전트/슬래시커맨드 선택은 Claude Code의 내장 디스패처와 LLM 모델이 수행한다.

---

## 1. Routing Flow — 유저 첫 메시지 처리 경로

```
+--------------------------------------------------------------------+
| 유저가 새 세션 오픈 (터미널/IDE)                                    |
| SessionStart 이벤트가 Claude Code에서 발화                          |
+-------------------------------+------------------------------------+
                                |
                                v
+--------------------------------------------------------------------+
| Node.js 훅: session-start-bootstrap.js -> session-start.js          |
| 플러그인 루트 탐색 -> 프로파일 게이팅 -> 이전세션/인스팅트 주입       |
| hooks/hooks.json:291 (SessionStart)                                 |
| scripts/hooks/session-start.js:350 (main)                           |
+-------------------------------+------------------------------------+
                                |
                                | stdout: hookSpecificOutput.
                                | additionalContext (Markdown 텍스트)
                                v
+--------------------------------------------------------------------+
| Claude Code가 additionalContext 를 시스템 컨텍스트로 주입           |
| 동시에 SKILL.md 의 name+description frontmatter 들을                |
| "사용 가능 스킬 목록" 으로 LLM 에 노출                              |
| skills/tdd-workflow/SKILL.md:1-5 (frontmatter 예시)                 |
+-------------------------------+------------------------------------+
                                |
                                v
+--------------------------------------------------------------------+
| 유저 메시지 수신                                                    |
| Claude Code 내장 파서가 선두 토큰 검사                              |
+-------------+---------------------------------------+--------------+
              |                                       |
    "/슬래시" 로 시작                         일반 자연어 요청
              |                                       |
              v                                       v
+-----------------------------+        +------------------------------+
| Claude Code 커맨드 디스패처  |        | LLM 이 description 매칭으로  |
| commands/<name>.md 로드      |        | 스킬 자동 트리거 판단        |
| frontmatter(description,     |        | (정규식/훅 없음, 순수 LLM)   |
| argument-hint) 파싱 후       |        | Skill tool 호출 결정         |
| 본문 프롬프트로 주입         |        | SKILL.md description 이     |
| commands/plan.md:1-3         |        | 트리거 텍스트 역할           |
| commands/tdd.md:1-3          |        +---------------+--------------+
+--------------+--------------+                        |
               |                                       |
               | 커맨드 본문이 "Apply the              |
               | tdd-workflow skill" 같은              |
               | 자연어로 스킬/에이전트 위임 지시      |
               v                                       v
+--------------------------------------------------------------------+
| LLM 이 결정: (a) 현재 세션에서 스킬 Markdown 로드, 혹은              |
|              (b) Task 도구로 서브에이전트 spawn                     |
|                                                                    |
| (a) 스킬: skills/<name>/SKILL.md 본문을 컨텍스트에 추가              |
| (b) 에이전트: agents/<name>.md frontmatter(model, tools) 로         |
|              별도 서브프로세스 생성                                 |
| agents/planner.md:1-6 (model: opus, tools: [Read, Grep, Glob])      |
+-------------------------------+------------------------------------+
                                |
                                v
+--------------------------------------------------------------------+
| LLM 이 도구 호출 시작 -> PreToolUse 훅 가드레일 (라우팅 아님)        |
| block-no-verify, commit-quality 등은 "차단/통과" 만 결정            |
| hooks/hooks.json:4-289 (PreToolUse 섹션)                            |
+--------------------------------------------------------------------+
```

### Narration

**세션이 시작되면 Node.js 훅이 "재료를 올려놓는" 역할만 한다.** `hooks/hooks.json:291` 의 `SessionStart` 매처(`"*"`)가 `session-start-bootstrap.js` 를 실행하고, 이 부트스트랩이 플러그인 루트를 찾아 `scripts/hooks/session-start.js` 의 `main()`(`:350`)로 위임한다. `main()` 은 이전 세션 요약(`*-session.tmp`), 학습된 인스팅트, 패키지 매니저/프로젝트 타입 메타데이터를 모아 `hookSpecificOutput.additionalContext` 한 덩어리로 stdout 에 JSON 출력한다. Claude Code 는 이것을 받아 시스템 프롬프트에 끼워 넣는다. 이 Node.js 코드는 **라우팅 결정을 전혀 하지 않는다** — 그냥 컨텍스트를 쌓아둘 뿐이다.

**유저 메시지 라우팅은 Claude Code 의 내장 디스패처와 LLM 두 축으로 나뉜다.** 메시지가 `/` 로 시작하면 Claude Code 의 빌트인 커맨드 파서가 플러그인의 `commands/<name>.md` 를 로드해 frontmatter(`description`, `argument-hint`) 를 읽고 본문을 LLM 프롬프트에 주입한다(예: `commands/plan.md:1-3`, `commands/tdd.md:1-3`). ECC 는 이 단계에 어떤 훅도 꽂지 않는다 — 즉 `UserPromptSubmit` 훅은 **존재하지 않고** (grep 결과 테스트/문서에만 언급), 커맨드 해석은 100% Claude Code 자체가 한다. 일반 자연어 메시지면 LLM 이 plugin.json 에 등록된 스킬들의 `description` frontmatter(예: `skills/tdd-workflow/SKILL.md:3` 의 "Use this skill when writing new features...") 와 유저 의도를 대조해 Skill 도구 호출 여부를 **모델 추론으로** 결정한다. 정규식 매칭이나 훅 기반 트리거가 아니다.

**커맨드는 스킬 위임과 에이전트 위임이라는 두 갈래로 분기한다.** `commands/tdd.md:20` 의 본문은 단순히 "Apply the `tdd-workflow` skill." 이라는 자연어 명령이고, LLM 이 이 지시를 읽어 스스로 `skills/tdd-workflow/SKILL.md` 를 로드 요청한다. 반면 `commands/plan.md:7` 은 "This command invokes the **planner** agent" 라고 적혀 있고, LLM 은 이를 보고 Task 도구로 `agents/planner.md` 를 spawn 한다. 이때 `agents/planner.md:1-6` 의 frontmatter 에 있는 `model: opus`, `tools: ["Read", "Grep", "Glob"]` 을 Claude Code 가 읽어 **서브에이전트 환경**을 구성한다 — 즉 에이전트의 모델/툴 선택은 코드가 아닌 Markdown frontmatter 가 결정한다.

**Node.js 훅은 라우팅 이후 단계에서만 개입한다.** LLM 이 도구 호출을 시작한 뒤 `hooks/hooks.json:4-289` 의 `PreToolUse` 훅들이 `matcher: "Bash"`/`"Edit"` 같은 도구 단위로 발화해 차단/통과만 판정한다. 모든 훅은 공통 부트스트랩(인라인 resolver + `plugin-hook-bootstrap.js` + `run-with-flags.js`)을 거쳐 프로파일 게이팅(`minimal/standard/strict`)을 통과해야 실제 스크립트가 실행된다(`scripts/hooks/run-with-flags.js:88-176`). 이 훅들은 **"어떤 스킬을 쓸지" 를 결정하지 않는다** — 이미 결정된 도구 실행을 검열할 뿐이다.

**정리하면 라우팅은 3중 구조다: (1) SessionStart 훅이 Markdown 컨텍스트를 채운다(Node.js). (2) 유저 입력은 Claude Code 내장 디스패처가 슬래시/자연어로 분기시킨다(Claude Code 바이너리). (3) 스킬/에이전트 선택은 LLM 이 description 을 읽고 모델 추론으로 결정한다(Claude LLM).** ECC 자체의 런타임 코드는 라우팅의 어느 단계에도 들어있지 않다.

---

## 2. 런타임/언어 분해표

| 단계 | 런타임/언어 | 실질적 동작 |
|------|-------------|-------------|
| SessionStart 훅 실행 | Node.js >=18 (spawn 체인) | 이전 세션 요약 + 인스팅트 + 프로젝트 타입을 stdout JSON 으로 주입 (`session-start.js:350-452`) |
| 플러그인 루트 해석 | Node.js (인라인 `node -e`) | 7개 설치 경로 후보를 런타임 탐색, `CLAUDE_PLUGIN_ROOT` 우선 (`hooks/hooks.json:13`, `session-start-bootstrap.js:73-116`) |
| 훅 프로파일 게이팅 | Node.js (`run-with-flags.js`) | `ECC_HOOK_PROFILE` / `ECC_DISABLED_HOOKS` 비교 후 실제 훅 실행 여부 결정 (`run-with-flags.js:88-100`) |
| 유저 입력 파싱 (`/cmd` vs 자연어) | Claude Code 내장 (ECC 코드 없음) | `UserPromptSubmit` 훅을 ECC 가 등록하지 않음 — Claude Code 가 단독 처리 |
| 슬래시 커맨드 디스패치 | Claude Code 내장 + Markdown | `commands/<name>.md` 로드, frontmatter `description`/`argument-hint` 파싱 후 본문을 프롬프트에 주입 |
| 스킬 자동 트리거 | Claude LLM (Opus/Sonnet) | `SKILL.md` frontmatter `description` 을 LLM 이 읽고 의도 매칭으로 Skill 도구 호출 결정 (정규식/훅 아님) |
| 에이전트 spawn | Claude Code 내장 + Markdown | `agents/<name>.md` frontmatter `model`/`tools` 를 Claude Code 가 읽어 서브에이전트 구성 (`agents/planner.md:1-6`) |
| 스킬/에이전트 위임 지시 | Markdown 프로즈 -> LLM | 커맨드 본문에 자연어로 "Apply X skill" / "invokes Y agent" 만 적혀 있음 (`commands/tdd.md:20`, `commands/plan.md:7`) |
| 도구 실행 가드레일 | Node.js 훅 (Pre/Post/Stop) | 차단/통과만 결정, 라우팅에는 관여 안 함 (`hooks/hooks.json:4-537`) |

---

## 핵심 인사이트

- **라우팅 로직은 코드가 아니라 프롬프트다.** ECC 는 143개 스킬을 가지고 있지만 "어떤 스킬을 언제 쓸지" 를 결정하는 매칭 엔진이 소스에 없다. 대신 각 `SKILL.md` frontmatter 의 `description` 문장이 LLM 의 Skill 도구 auto-trigger 에 전적으로 의존한다. 즉 라우팅 품질은 description 문장의 품질에 비례한다 — `description` 을 잘못 쓰면 어떤 훅으로도 보정할 수 없다.

- **`UserPromptSubmit` 훅을 쓰지 않기로 한 결정.** ECC 는 문서(`the-shortform-guide.md` 등)와 스키마 검증(`schemas/hooks.schema.json`)에서 `UserPromptSubmit` 을 언급만 하고, 실제 `hooks.json` 에는 등록하지 않았다(`SessionStart`/`PreToolUse`/`PostToolUse`/`PostToolUseFailure` 만 사용). 이는 유저 입력 라우팅에 관여하지 않고 Claude Code 의 내장 동작을 신뢰한다는 설계 선언이다 — 훅이 유저 메시지를 재작성하기 시작하면 모델의 라우팅 결정이 오염되기 때문.

- **커맨드는 "얇은 껍데기", 에이전트는 "격리된 전문가", 스킬은 "세션 증강".** `commands/tdd.md` 는 거의 모든 내용이 `skills/tdd-workflow/SKILL.md` 를 가리키는 레거시 shim 이다(`commands/tdd.md:1` 의 "Legacy slash-entry shim"). 이 계층화된 설계 — 슬래시 커맨드는 진입점일 뿐, 로직은 스킬에, 별도 LLM 인스턴스가 필요한 경우만 에이전트로 — 덕분에 동일한 워크플로우가 `/tdd` 와 자연어 요청 양쪽으로 라우팅되어도 같은 `SKILL.md` 로 수렴한다.
