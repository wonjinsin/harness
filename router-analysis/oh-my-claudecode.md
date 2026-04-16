# Router Analysis: oh-my-claudecode (OMC)

## TL;DR

라우팅은 **Node.js 20+ .mjs 훅 스크립트**에서 순수 정규식으로 일어난다(LLM 호출 없음). 매칭 후 훅은 `additionalContext`로 markdown 스킬 본문을 주입할 뿐, 에이전트 파견은 TypeScript SDK가 빌드해둔 시스템 프롬프트를 보고 **LLM이 `Task` 도구를 부르는 방식**으로 간접 수행된다.

---

## Routing Flow (ASCII)

```
 User message
      |
      v
+--------------------------------------------------------------+
| Claude Code CLI: UserPromptSubmit event                      |
| hooks.json -> UserPromptSubmit[] (matcher "*")               |
| Two hooks fire sequentially, each via run.cjs wrapper         |
+----------------------------+---------------------------------+
                             | stdin = {prompt, cwd, session_id}
           +-----------------+-------------------+
           |                                     |
           v (1) timeout 5s                     v (2) timeout 3s
+------------------------------+  +-------------------------------+
| scripts/keyword-detector.mjs |  | scripts/skill-injector.mjs    |
| Node.js, regex-only          |  | Node.js, regex-only           |
| - sanitize(strip code/xml)   |  | - walk skills/ dirs           |
| - 14 hard-coded keyword regex|  | - parse YAML frontmatter      |
|   (ralph|autopilot|ulw|ccg   |  |   triggers: [...]             |
|   |tdd|code-review|ultrathink|  | - prompt.includes(trigger)    |
|   |deepsearch|analyze|wiki|..)|  | - score, top 5 per session   |
| - resolve conflicts by       |  | - dedupe via                  |
|   priority list              |  |   .omc/state/skill-sessions-  |
| - write .omc/state/<mode>-   |  |   fallback.json               |
|   state.json for ralph/auto  |  |                               |
|   /ultrawork/ralplan         |  |                               |
| - emit hookSpecificOutput    |  | - emit hookSpecificOutput     |
|   .additionalContext =       |  |   .additionalContext =        |
|   [MAGIC KEYWORD: X]         |  |   <mnemosyne>...</mnemosyne>  |
|   + SKILL.md body            |  |   with skill body + metadata  |
+--------------+---------------+  +----------------+--------------+
               |                                   |
               +-------------------+---------------+
                                   v
+--------------------------------------------------------------+
| Augmented prompt reaches Claude Code orchestrator            |
| System prompt was pre-built by omcSystemPrompt() (TS)        |
| + continuationEnforcement addition                           |
| + context files (AGENTS.md, CLAUDE.md) concatenated          |
| src/index.ts:283, src/agents/definitions.ts:289              |
+----------------------------+---------------------------------+
                             | LLM reads system prompt +
                             | injected skill markdown +
                             | [MAGIC KEYWORD] marker
                             v
+--------------------------------------------------------------+
| LLM decides routing itself:                                  |
|  - direct answer, OR                                         |
|  - Skill tool to load a skill, OR                            |
|  - Task tool to dispatch one of 19 agents                    |
|    (agents/*.md for plugin, src/agents/*.ts for SDK)         |
+--------------------------------------------------------------+
```

---

## Narration

사용자가 메시지를 보내는 순간 **Claude Code CLI**가 먼저 `UserPromptSubmit` 이벤트를 발화한다. `hooks/hooks.json`(라인 4~20)에는 `matcher: "*"` 하나에 두 개의 훅이 순서대로 등록돼 있다 — `scripts/keyword-detector.mjs`(타임아웃 5초)와 `scripts/skill-injector.mjs`(타임아웃 3초). 둘 다 `scripts/run.cjs` 래퍼를 통해 `node`로 실행되는 **Node.js 20+ ES 모듈** 스크립트다. 원본 프롬프트는 stdin JSON(`{prompt, cwd, session_id}`)으로 전달되고, 훅의 stdout JSON이 `hookSpecificOutput.additionalContext`로 되돌아와 LLM 컨텍스트에 system-reminder처럼 주입된다.

`keyword-detector.mjs`는 **순수 정규식 기반 결정 로직**이다. LLM을 부르지 않는다. 먼저 `sanitizeForKeywordDetection()`(line 174~195)이 HTML/마크다운 주석, XML 태그 블록, URL, 파일 경로, 코드 블록, 백틱 인라인 코드를 모두 제거해 "진짜 사용자 의도 문장"만 남긴다. 이 정제된 텍스트에 14개의 하드코딩된 키워드 패턴(`\b(ralph|autopilot|ultrawork|ulw|ccg|ralplan|deep-interview|tdd|code-review|security-review|ultrathink|deepsearch|deep-analyze|wiki)\b` + 한국어 대응어)을 차례로 매칭한다(line 677~768). 추가로 `isInformationalKeywordContext()` 휴리스틱으로 "what is ralph?" 같은 **정보성 질문은 트리거에서 제외**한다. 매칭되면 `resolveConflicts()`가 `priorityOrder = ['cancel','ralph','autopilot','ultrawork','ccg','ralplan',...]` 순으로 정렬하고, `ralph`/`autopilot`/`ultrawork`/`ralplan`은 `.omc/state/<mode>-state.json`에 활성 플래그를 기록한다(line 354~411). 마지막으로 `createSkillInvocation(skillName, prompt)`이 `skills/<name>/SKILL.md`를 디스크에서 읽어 `[MAGIC KEYWORD: RALPH]\n\n<SKILL.md 본문>` 블록을 만들어 반환한다(line 527~543). 즉 **키워드 감지는 Node 정규식이고, 주입되는 내용은 markdown**이며, 실제 스킬 실행은 그 markdown을 읽은 LLM에게 맡긴다.

`skill-injector.mjs`는 다른 축에서 돈다. 키워드 탐지가 아니라 `skills/`(+ `~/.omc/skills`, `.omc/skills` 프로젝트 스킬) 디렉터리를 재귀 스캔하고, 각 `SKILL.md`의 **YAML frontmatter**를 `parseSkillFrontmatterFallback()`(line 67~90)이 파싱하여 `triggers: [...]` 배열을 꺼낸다. 그리고는 `promptLower.includes(trigger)`라는 가장 단순한 부분 문자열 매칭으로 점수를 매기고(line 184~189), 상위 **5개**까지 선별한다(`MAX_SKILLS_PER_SESSION = 5`, line 35). 같은 세션에서 이미 주입한 스킬은 `.omc/state/skill-sessions-fallback.json`에 경로를 기록해 TTL 1시간 동안 중복 주입을 막는다(line 46~64). 결과는 `<mnemosyne>...</mnemosyne>` 블록에 각 스킬 본문 + `<skill-metadata>` JSON을 넣어 반환된다(line 248~279). 트리거 소스는 코드가 아니라 **markdown frontmatter**이므로 스킬을 추가/수정해도 재빌드가 필요 없다. 단 `dist/hooks/skill-bridge.cjs` 번들이 있으면 동일 로직의 재귀 디스커버리 버전이 우선 사용된다(line 22~27).

증강된 프롬프트가 LLM에 닿으면 이미 **createOmcSession()**(TypeScript, `src/index.ts:265~366`)이 조립해둔 시스템 프롬프트가 함께 전달된다. 여기에는 `omcSystemPrompt`(`src/agents/definitions.ts:289`에 정의된 다문단 지시문), `continuationSystemPromptAddition`, `findContextFiles()`로 찾아낸 AGENTS.md/CLAUDE.md 내용이 순차 결합된다(line 283~298). 중요한 점은 **여기서는 라우팅 결정을 하지 않는다**는 것이다 — 에이전트 정의 19종(`agents/*.md`의 frontmatter = `name`/`model`/`level` + `<Agent_Prompt>`; SDK 쪽은 `src/agents/definitions.ts`의 AgentConfig 객체)을 단지 **`agents` 옵션에 등록**해 Claude Code에 제공할 뿐이다. 실제로 "executor를 부를까, planner를 부를까"는 **LLM이 Task 도구를 호출할 때 스스로 고르는** 결정이다. 즉 코드가 하는 라우팅은 "어떤 스킬/키워드 지침을 프롬프트에 끼워 넣을까"까지이고, 그 이후 에이전트 파견은 LLM의 자율 결정이다.

두 진입점(Claude Code 플러그인 vs SDK 라이브러리)은 라우팅을 **공유하지 않는다**. 플러그인 경로는 위에서 설명한 훅 체인을 쓴다. SDK 경로(`createOmcSession()`의 `processPrompt()`, `magic-keywords.ts:392`)는 훅이 아예 붙지 않고 TypeScript 함수 `createMagicKeywordProcessor()`가 동일한 키워드를 **다시 구현**해 `<ultrawork-mode>` XML 블록을 앞뒤로 감싼다. 스킬 주입 로직(frontmatter 파싱)은 SDK 쪽에 복제돼 있지 않아, SDK 사용자는 기본적으로 `AGENTS.md` 시스템 프롬프트 + 19개 에이전트 정의 + MCP 도구만 얻는다. 정리하면 "mjs 훅은 라우팅"이고 "TypeScript SDK는 시스템 프롬프트 + 에이전트 카탈로그 조립"이다. 두 번 중복된 magic-keyword 로직이 유지되는 대가로, 플러그인을 끄고도 SDK만으로도 같은 키워드 증강을 쓸 수 있다.

---

## 언어 / 런타임 분해표

| 단계 | 런타임/언어 | 실질적 동작 |
|------|-------------|-------------|
| 훅 등록 | JSON (`hooks/hooks.json`) | `UserPromptSubmit` 매처 `*`에 키워드 감지, 스킬 주입 순서대로 바인딩 |
| run.cjs 래퍼 | Node.js 20+ (CommonJS) | `CLAUDE_PLUGIN_ROOT` 해석 후 타겟 .mjs를 `node`로 구동 |
| 키워드 감지 | Node.js 20+ (.mjs, ES Modules) | 정제 → 14개 정규식 매칭 → 우선순위 정렬 → state 파일 기록 → markdown 본문 삽입. **LLM 호출 없음** |
| 스킬 주입 | Node.js 20+ (.mjs, ES Modules) | `skills/**/SKILL.md` frontmatter 파싱 → `triggers`와 프롬프트 부분 문자열 매칭 → 상위 5개 선별. **LLM 호출 없음** |
| 스킬/키워드 본문 | Markdown (`skills/*/SKILL.md`, YAML frontmatter) | 트리거와 스킬 지침이 정의되는 **데이터 소스**. 코드가 아니라 텍스트 |
| 시스템 프롬프트 조립 | TypeScript (`src/index.ts`, `src/agents/definitions.ts`) | `omcSystemPrompt` + `continuationSystemPromptAddition` + 컨텍스트 파일 concat. SDK 진입점에서 1회 실행 |
| 에이전트 카탈로그 | Markdown 19개 (`agents/*.md`) + TypeScript 미러 (`src/agents/*.ts`) | 플러그인은 .md의 frontmatter(`name`/`model`/`level`), SDK는 `AgentConfig` 객체 |
| 에이전트 파견 결정 | **LLM (Claude)** | Task 도구로 어느 에이전트를 부를지, 병렬/백그라운드 여부를 LLM이 판단 |
| SDK 매직 키워드(플러그인 대체) | TypeScript (`src/features/magic-keywords.ts:392`) | 훅 미사용 경로에서 `processPrompt()`가 XML 블록으로 프롬프트 래핑 |

---

## 핵심 인사이트

- **라우팅은 LLM이 아니라 Node 정규식이 한다.** `UserPromptSubmit` 훅 두 개 모두 LLM 호출이 없고, 키워드 매칭은 하드코딩된 14개 `RegExp`, 스킬 매칭은 frontmatter `triggers`와 `prompt.includes()`라는 가장 단순한 부분 문자열 비교로 끝난다. 라우팅 비용이 사실상 0이라는 대가로 신규 키워드 추가는 `keyword-detector.mjs`를 수정해야 한다는 비대칭이 있다.
- **"주입"과 "파견"의 층위가 분리돼 있다.** 훅은 `[MAGIC KEYWORD: X]` + `SKILL.md` 마크다운을 `additionalContext`로 붙여줄 뿐, 19개 전문 에이전트 중 누구를 부를지는 LLM이 읽고 자발적으로 `Task` 도구를 호출해야 일어난다. 즉 프롬프트 증강은 결정적(deterministic)이고 에이전트 선택은 확률적(LLM-driven)이다.
- **하이브리드 동거 비용이 두 번 복제된 매직 키워드 로직에 그대로 드러난다.** 플러그인 진입은 `scripts/keyword-detector.mjs`에서, SDK 진입은 `src/features/magic-keywords.ts`에서 같은 키워드들을 각자 재구현한다. 두 경로가 공유하는 건 `skills/*/SKILL.md`라는 **markdown 데이터 레이어뿐**이고, 그 덕분에 한쪽(SDK)에서 훅을 끄고도 동일 키워드 UX를 재현할 수 있다.
