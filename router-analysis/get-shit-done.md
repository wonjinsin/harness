# GSD (get-shit-done) — Router Analysis

## TL;DR

GSD의 라우팅은 **두 개의 분리된 런타임**에서 돌아간다. `gsd-sdk` CLI 경로는 전부 TypeScript 코드(Node.js 20+)가 결정하고, `/gsd:*` 슬래시 커맨드 경로는 Claude Code 본체가 마크다운 파일을 읽어 LLM이 해석해 분기한다. Phase 선택(Discuss/Research/Plan/Execute/Verify)은 CLI 경로에서는 완전히 결정론적(코드 기반)이지만, 슬래시 커맨드 `/gsd:do` 같은 메타-디스패처에서는 LLM이 라우팅 룰표를 읽고 판단한다.

---

## Routing Flow — 두 경로의 ASCII 다이어그램

### 경로 A: `gsd-sdk` CLI (TypeScript 결정론)

```
┌────────────────────────────────────────────────────────────────────┐
│  유저: $ gsd-sdk run "사용자 인증 기능 만들어줘"                   │
│  쉘 프로세스 실행 (bin/gsd-sdk → node sdk/dist/cli.js)             │
└─────────────────────────────────┬──────────────────────────────────┘
                                  │
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│  main()  ·  sdk/src/cli.ts:196, :511                               │
│  parseCliArgs(argv) → { command, prompt, projectDir, ws, ... }     │
│  분기: query | init | auto | run (if/else 체인, :227~:484)         │
└─────────────────────────────────┬──────────────────────────────────┘
                                  │ command === 'run'
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│  GSD.run(prompt)  ·  sdk/src/index.ts:168                          │
│  ① tools.roadmapAnalyze() → .planning/ROADMAP.md 스캔              │
│  ② filterAndSortPhases() — roadmap_complete=false만 숫자 정렬      │
│  ③ while (currentPhases.length > 0) 루프                           │
└─────────────────────────────────┬──────────────────────────────────┘
                                  │ 각 Phase마다
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│  PhaseRunner.run(phaseNumber)  ·  sdk/src/phase-runner.ts:90       │
│  6 스텝 직렬 호출 (전부 if/else 가드):                             │
│    Step1 Discuss  (:137~:179) — has_context / skip_discuss 체크    │
│    Step2 Research (:181~:189) — config.workflow.research           │
│    Step2.5 Gate   (:191~:204) — RESEARCH.md open question 탐지     │
│    Step3 Plan     (:206~:224)                                      │
│    Step3.5 Check  (:226~:247) — plan-checker 재검토                │
│    Step4 Execute  (:249~:253)                                      │
│    Step5 Verify   (:255~:270) — gap closure 재시도                 │
│    Step6 Advance  (:272~:280) — verifyPassed 조건부                │
└─────────────────────────────────┬──────────────────────────────────┘
                                  │ runStep(PhaseStepType, ...)
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│  컨텍스트 파일 결정 (단순 테이블 룩업)                             │
│  ContextEngine.resolveContextFiles(phaseType)                      │
│    ·  sdk/src/context-engine.ts:100                                │
│  PHASE_FILE_MANIFEST[phaseType] → FileSpec[]  (:42)                │
│    Execute:  STATE.md + config.json                                │
│    Research: STATE + ROADMAP + CONTEXT + REQUIREMENTS              │
│    Plan:     STATE + ROADMAP + CONTEXT + RESEARCH + REQUIREMENTS   │
│    Verify:   STATE + ROADMAP + REQUIREMENTS + PLAN + SUMMARY       │
│    Discuss:  STATE + ROADMAP + CONTEXT                             │
└─────────────────────────────────┬──────────────────────────────────┘
                                  │
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│  에이전트 바인딩 (하드코딩 맵)                                     │
│  PHASE_AGENT_MAP[phaseType]  ·  sdk/src/tool-scoping.ts:32         │
│    Execute  → gsd-executor.md                                      │
│    Research → gsd-phase-researcher.md                              │
│    Plan     → gsd-planner.md                                       │
│    Verify   → gsd-verifier.md                                      │
│    Discuss  → null (메인 대화에서 실행)                            │
│  PromptFactory.buildPrompt()  ·  sdk/src/phase-prompt.ts:95        │
│    역할(agent.md) + 워크플로우(workflows/*.md) + 컨텍스트 파일 병합│
└────────────────────────────────────────────────────────────────────┘
```

### 경로 B: Claude Code 슬래시 커맨드 (마크다운 + LLM 해석)

```
┌────────────────────────────────────────────────────────────────────┐
│  유저: /gsd:do "사용자 인증 기능 만들어줘"  (Claude Code 세션 내)  │
└─────────────────────────────────┬──────────────────────────────────┘
                                  │
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│  Claude Code 내장 커맨드 디스패처 (GSD 외부)                       │
│  ~/.claude/commands/gsd/do.md 로드                                 │
│  → YAML frontmatter: name, allowed-tools, argument-hint            │
│  → <execution_context>의 @경로 참조 자동 인라인                    │
└─────────────────────────────────┬──────────────────────────────────┘
                                  │ 프롬프트 조립
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│  워크플로우 마크다운 주입 (GSD의 DSL)                              │
│  @~/.claude/get-shit-done/workflows/do.md 로드                     │
│  → <process> 블록 안에 <step name="route"> 라우팅 룰 테이블        │
│    (15개 행, "If the text describes X, Route to Y")                │
└─────────────────────────────────┬──────────────────────────────────┘
                                  │ LLM(Claude)이 자연어로 매칭
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│  LLM의 라우팅 판단 (비결정론 부분)                                 │
│  Claude가 $ARGUMENTS와 룰표 비교 → 하나의 `/gsd-*` 커맨드 선택    │
│  애매하면 AskUserQuestion 도구로 유저에게 확인                     │
│    (workflows/do.md:35~69)                                         │
└─────────────────────────────────┬──────────────────────────────────┘
                                  │ 예: /gsd-execute-phase N
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│  선택된 커맨드 워크플로우 실행                                     │
│  예: execute-phase.md → workflows/execute-phase.md                 │
│  내부에서 `gsd-tools init execute-phase` (Bash) 호출로 컨텍스트    │
│  파일 결정을 SDK의 네이티브 쿼리 엔진에 위임                       │
│  QueryRegistry.dispatch()  ·  sdk/src/query/registry.ts:118        │
└────────────────────────────────────────────────────────────────────┘
```

---

## Narration

### CLI 경로 — 전부 TypeScript가 결정한다

`gsd-sdk run "..."`이 실행되는 순간 라우팅의 모든 결정은 이미 컴파일된 TypeScript 코드에 박혀 있다. `main()`(`sdk/src/cli.ts:196`)가 `parseCliArgs()`로 `query | init | auto | run` 네 개의 하위 커맨드 중 하나를 식별하고, 단순 `if` 분기로 해당 경로로 내려간다(`cli.ts:227, :291, :373, :461`). `run` 커맨드는 `GSD.run(prompt)`(`sdk/src/index.ts:168`)로 들어가는데, 여기서도 LLM이 할 일은 아직 없다 — `tools.roadmapAnalyze()`를 호출해 `.planning/ROADMAP.md`를 파싱하고, `filterAndSortPhases()`(`index.ts:254`)로 `roadmap_complete=false`인 Phase를 숫자순 정렬한 배열을 만든다. **유저가 보낸 프롬프트는 이 단계에서 라우팅에 거의 쓰이지 않는다** — 실제 실행 순서는 ROADMAP 파일 상태가 결정한다. 이 덕분에 프로세스가 중간에 죽어도 다음 실행에서 남은 Phase부터 이어 달릴 수 있다.

### Phase 선택은 완전 결정론

`PhaseRunner.run()`(`sdk/src/phase-runner.ts:90`)은 Discuss → Research → Research Gate → Plan → Plan Check → Execute → Verify → Advance의 6+2 스텝을 **하드코딩된 순서**로 돈다. 각 스텝에는 단순 가드(`config.workflow.research === false`면 스킵 등)만 붙어 있을 뿐, 어떤 LLM도 "다음에 뭘 할지" 결정하지 않는다. 예를 들어 Discuss 스킵 조건은 `phaseOp.has_context || config.workflow.skip_discuss`라는 순수 boolean 체크다(`phase-runner.ts:139`). 유일하게 LLM이 개입하는 분기는 Research Gate(`phase-runner.ts:193`)가 감지한 미해결 질문과 Verify 스텝의 gap 재시도, 그리고 `invokeBlockerCallback`을 통한 휴먼 인터벤션 콜백이다.

### 컨텍스트 로딩은 테이블 룩업

어떤 `.planning/` 파일을 읽을지는 `ContextEngine.resolveContextFiles()`(`sdk/src/context-engine.ts:100`)가 `PHASE_FILE_MANIFEST` 정적 테이블(`context-engine.ts:42`)을 인덱싱해 결정한다. Execute는 2개 파일(STATE.md + config.json), Plan은 5개(STATE + ROADMAP + CONTEXT + RESEARCH + REQUIREMENTS) 같은 식으로 Phase 타입이 곧 파일 리스트의 키다. 마찬가지로 어떤 에이전트 정의를 쓸지는 `PHASE_AGENT_MAP`(`sdk/src/tool-scoping.ts:32`)에서 Execute→`gsd-executor.md`, Plan→`gsd-planner.md` 식으로 1:1 매핑된다. LLM 세션 자체는 `PromptFactory.buildPrompt()`(`sdk/src/phase-prompt.ts:95`)가 이 3가지(role / workflow / contextFiles)를 안정 프리픽스 + 가변 서픽스 구조로 합쳐 `query()`에 넘기는 단계에서만 등장한다.

### 슬래시 커맨드 경로 — 로직이 마크다운에 있다

`/gsd:do "..."` 같은 슬래시 커맨드는 완전히 다른 스택이다. 여기서 라우터는 GSD가 아니라 **Claude Code 본체**이고, 라우팅 로직은 TypeScript 어디에도 없다. `commands/gsd/do.md`는 YAML frontmatter(`allowed-tools: [Read, Bash, AskUserQuestion]`)와 `<execution_context>` 블록의 `@~/.claude/get-shit-done/workflows/do.md` 참조만 담은 얇은 포인터다(`commands/gsd/do.md:1~30`). 진짜 라우팅 룰은 `workflows/do.md`의 `<step name="route">` 안에 **15행짜리 자연어 마크다운 테이블**로 적혀 있다("If the text describes a bug → `/gsd-debug`" 식). Claude가 이 테이블을 읽고 `$ARGUMENTS`와 매칭해 분기를 고르며, 애매하면 `AskUserQuestion`으로 유저에게 확인한다. 즉 **이 경로의 라우팅은 LLM의 추론**이다.

### 두 경로의 접점

Claude Code 경로도 최종적으로는 SDK의 결정론적 엔진을 재사용한다. `workflows/execute-phase.md` 같은 파일들은 `bash`로 `gsd-tools init execute-phase`를 호출하라고 지시하고, 이건 `QueryRegistry.dispatch()`(`sdk/src/query/registry.ts:118`)로 들어가 50+ 네이티브 핸들러 중 하나를 실행한다. 그래서 상태 파일(`.planning/`)을 읽고 쓰는 것은 두 경로 모두 TypeScript 코드를 통과하지만, **무엇을 할지 결정하는 층**이 CLI 경로에선 코드, 슬래시 경로에선 LLM+마크다운이라는 차이가 있다.

---

## 런타임/언어 분해표

| 단계 | 런타임/언어 | 실질적 동작 |
|------|-------------|-------------|
| CLI argv 파싱 | Node.js / TypeScript | `parseArgs()` + positional split; `cli.ts:57` |
| 커맨드 디스패치 (CLI) | TypeScript `if` 체인 | `run|auto|init|query` 분기; `cli.ts:227~484` |
| 마일스톤 스케줄링 | TypeScript | `roadmapAnalyze()` + 숫자 정렬; `index.ts:168` |
| Phase 순서 결정 | TypeScript (하드코딩) | 6 스텝 직렬 호출; `phase-runner.ts:90~310` |
| 스텝 스킵 가드 | TypeScript boolean | `has_context`, `config.workflow.*` 체크 |
| 컨텍스트 파일 선택 | TypeScript 정적 테이블 | `PHASE_FILE_MANIFEST[phaseType]`; `context-engine.ts:42` |
| 에이전트 바인딩 | TypeScript 정적 맵 | `PHASE_AGENT_MAP`; `tool-scoping.ts:32` |
| 허용 도구 스코핑 | TypeScript 정적 맵 | `PHASE_DEFAULT_TOOLS`; `tool-scoping.ts:17` |
| 프롬프트 조립 | TypeScript + 마크다운 I/O | `PromptFactory.buildPrompt()`; `phase-prompt.ts:95` |
| 슬래시 커맨드 로드 | Claude Code 본체 | YAML frontmatter + `@경로` 인라인 |
| 슬래시 경로 라우팅 | LLM(Claude) + 마크다운 룰 | `workflows/do.md`의 룰표를 LLM이 매칭 |
| 슬래시 → 상태 액세스 | Bash → Node.js 쿼리 엔진 | `gsd-tools init/state.load/...`; `query/registry.ts:118` |
| 실제 작업 수행 | LLM 세션 | Anthropic Agent SDK `query()`; `session-runner.ts:279` |

---

## 핵심 인사이트

- **Phase 라우팅은 결정론 코드, 의미론 라우팅은 LLM+마크다운**: `gsd-sdk` CLI로 들어오면 Phase 순서·컨텍스트 파일·에이전트 선택이 전부 TypeScript 정적 테이블(`PHASE_FILE_MANIFEST`, `PHASE_AGENT_MAP`, `PHASE_DEFAULT_TOOLS`)에서 결정되므로 LLM은 "어느 Phase를 돌릴지" 고르지 않는다. 반대로 슬래시 커맨드의 `/gsd:do`는 `workflows/do.md`에 자연어 룰표만 두고 Claude가 매칭하게 한다 — 같은 제품 안에 두 철학이 공존한다.

- **상태는 ROADMAP.md가 싱글 소스**: `GSD.run()`은 프롬프트가 아니라 `.planning/ROADMAP.md`의 `roadmap_complete=false` Phase만 필터해서 실행한다(`index.ts:175, :254`). 재개 로직이 별도로 없는 이유 — 프로세스 크래시 후 다시 실행하면 ROADMAP이 자동으로 "다음 할 일"을 알려준다. 라우터가 상태를 기억할 필요가 없는 설계다.

- **`commands/*.md`는 빈 껍데기, `workflows/*.md`가 진짜 로직**: 슬래시 커맨드 파일은 YAML frontmatter(허용 도구)와 `<execution_context>` 포인터만 담고, 실제 실행 지시사항은 `get-shit-done/workflows/*.md`에 자연어로 서술된다. "코드가 아니라 문서가 로직"이라는 구조가 GSD의 가장 독특한 선택이며, 이 간접성 덕분에 Claude Code / Copilot / Codex 같은 다른 런타임에도 `text_mode` 플래그 한 줄로 이식 가능하다(`workflows/do.md:15`).
